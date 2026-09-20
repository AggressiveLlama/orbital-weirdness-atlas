# Stephen Gray July 2026
# Synapse8087@proton.me
# Shared functions -------------------------------------------------------------

required_packages <- c(
  "arrow", "dplyr", "ggplot2", "hexbin", "httr2", "jsonlite",
  "purrr", "readr", "rlang", "scales", "stringr", "tibble", "tidyr"
)

check_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop(
      "Missing packages: ", paste(missing, collapse = ", "),
      "\nRestore the locked environment with: Rscript 00_install_packages.R",
      call. = FALSE
    )
  }
}

timestamp_utc <- function() {
  format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

choose_parquet_compression <- function(
    preferred = c("zstd", "snappy", "gzip", "brotli", "lz4")
) {
  # Some Arrow installations are compiled without optional compression codecs.
  # Test each codec at runtime and always fall back to uncompressed Parquet.
  for (codec in preferred) {
    available <- tryCatch(
      isTRUE(arrow::codec_is_available(codec)),
      error = function(e) FALSE
    )
    if (available) {
      return(codec)
    }
  }

  "uncompressed"
}

median_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) == 0L) NA_real_ else stats::median(x)
}


iqr_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2L) NA_real_ else stats::IQR(x)
}

mad_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (length(x) < 2L) {
    return(NA_real_)
  }

  value <- stats::mad(x, constant = 1.4826)
  if (!is.finite(value) || value == 0) NA_real_ else value
}

sbdb_request <- function(
    endpoint,
    query,
    max_retries = 6L,
    timeout_seconds = 180,
    user_agent = "orbital-weirdness-atlas/1.0 (contact: Synapse8087@proton.me)",
    expected_api_version = "1.0"
) {
  req <- httr2::request(endpoint)
  req <- do.call(httr2::req_url_query, c(list(req), query))
  req <- req |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_timeout(timeout_seconds) |>
    httr2::req_retry(
      max_tries = max_retries,
      backoff = function(attempt) min(60, 2 ^ attempt)
    )

  resp <- httr2::req_perform(req)
  httr2::resp_check_status(resp)
  payload <- httr2::resp_body_json(resp, simplifyVector = FALSE)

  api_version <- payload$signature$version
  if (is.null(api_version) || length(api_version) != 1L) {
    stop(
      "SBDB response did not contain `signature.version`; refusing to parse an unversioned response.",
      call. = FALSE
    )
  }

  api_version <- as.character(api_version[[1]])
  if (!identical(api_version, expected_api_version)) {
    stop(
      "SBDB API version changed from ", expected_api_version,
      " to ", api_version,
      ". Review the API documentation before continuing.",
      call. = FALSE
    )
  }

  payload
}

sbdb_count <- function(
    endpoint,
    sb_kind,
    constraints,
    max_retries = 6L,
    user_agent = "orbital-weirdness-atlas/1.0 (contact: Synapse8087@proton.me)",
    expected_api_version = "1.0"
) {
  payload <- sbdb_request(
    endpoint = endpoint,
    query = list(
      "sb-kind" = sb_kind,
      "sb-cdata" = jsonlite::toJSON(
        constraints,
        auto_unbox = TRUE,
        null = "null"
      )
    ),
    max_retries = max_retries,
    user_agent = user_agent,
    expected_api_version = expected_api_version
  )

  if (is.null(payload$count)) {
    stop("SBDB count response did not contain a `count` field.", call. = FALSE)
  }

  as.integer(payload$count)
}

parse_sbdb_page <- function(payload) {
  if (is.null(payload$data) || length(payload$data) == 0L) {
    return(tibble::tibble())
  }

  fields <- unlist(payload$fields, use.names = FALSE)
  rows <- lapply(payload$data, function(row) {
    values <- vapply(
      row,
      function(value) {
        if (is.null(value) || length(value) == 0L) {
          NA_character_
        } else {
          as.character(value[[1]])
        }
      },
      character(1)
    )

    if (length(values) != length(fields)) {
      stop(
        "SBDB row length (", length(values),
        ") does not match field count (", length(fields), ").",
        call. = FALSE
      )
    }

    values
  })

  mat <- do.call(rbind, rows)
  out <- tibble::as_tibble(mat, .name_repair = "minimal")
  names(out) <- fields

  # Do not infer all column types page by page. Identifier fields such as
  # pdes may look numeric on one page and later contain values like
  # "2005 TQ11", which creates incompatible Parquet schemas.
  out <- out |>
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ dplyr::na_if(trimws(as.character(.x)), "")
      )
    )

  numeric_fields <- intersect(
    c(
      "t_jup", "moid", "moid_jup",
      "epoch", "e", "a", "q", "i", "om", "w", "ma", "per", "ad",
      "sigma_e", "sigma_a", "sigma_q", "sigma_i", "sigma_om", "sigma_w",
      "condition_code", "data_arc", "n_obs_used",
      "H", "diameter", "albedo", "rot_per"
    ),
    names(out)
  )

  out |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(numeric_fields), safe_numeric)
    )
}

download_sbdb_pages <- function(
    endpoint,
    fields,
    sb_kind,
    constraints,
    output_dir,
    page_size = 50000L,
    pause_seconds = 0.20,
    max_retries = 6L,
    user_agent = "orbital-weirdness-atlas/1.0 (contact: Synapse8087@proton.me)",
    expected_api_version = "1.0"
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  parquet_compression <- choose_parquet_compression()
  message("Parquet compression codec: ", parquet_compression)

  total <- sbdb_count(
    endpoint = endpoint,
    sb_kind = sb_kind,
    constraints = constraints,
    max_retries = max_retries,
    user_agent = user_agent,
    expected_api_version = expected_api_version
  )

  message("Matching SBDB objects at start of download: ", format(total, big.mark = ","))
  offsets <- if (total > 0L) {
    seq.int(0L, total - 1L, by = page_size)
  } else {
    integer()
  }
  constraints_json <- jsonlite::toJSON(
    constraints,
    auto_unbox = TRUE,
    null = "null"
  )

  for (offset in offsets) {
    part_path <- file.path(
      output_dir,
      sprintf("part-%09d.parquet", offset)
    )

    if (file.exists(part_path)) {
      message("Already present; skipping: ", basename(part_path))
      next
    }

    message(
      "Downloading records ",
      format(offset + 1L, big.mark = ","),
      "–",
      format(min(offset + page_size, total), big.mark = ","),
      " of ",
      format(total, big.mark = ",")
    )

    payload <- sbdb_request(
      endpoint = endpoint,
      query = list(
        fields = paste(fields, collapse = ","),
        sort = "spkid",
        limit = page_size,
        "limit-from" = offset,
        "full-prec" = "true",
        "sb-kind" = sb_kind,
        "sb-cdata" = constraints_json
      ),
      max_retries = max_retries,
      user_agent = user_agent,
      expected_api_version = expected_api_version
    )

    page <- parse_sbdb_page(payload)
    if (nrow(page) == 0L) {
      warning("Empty page returned at offset ", offset, call. = FALSE)
      next
    }

    temp_path <- paste0(part_path, ".tmp")
    arrow::write_parquet(page, temp_path, compression = parquet_compression)
    if (!file.rename(temp_path, part_path)) {
      stop("Could not atomically move temporary file into place: ", part_path)
    }

    Sys.sleep(pause_seconds)
  }

  count_at_end <- sbdb_count(
    endpoint = endpoint,
    sb_kind = sb_kind,
    constraints = constraints,
    max_retries = max_retries,
    user_agent = user_agent,
    expected_api_version = expected_api_version
  )

  manifest <- list(
    endpoint = endpoint,
    api_version = expected_api_version,
    user_agent = user_agent,
    retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    count_at_start = total,
    count_at_end = count_at_end,
    count_changed_during_download = !identical(total, count_at_end),
    page_size = page_size,
    fields = fields,
    sb_kind = sb_kind,
    constraints = constraints
  )

  jsonlite::write_json(
    manifest,
    file.path(output_dir, "manifest.json"),
    pretty = TRUE,
    auto_unbox = TRUE
  )

  invisible(manifest)
}

add_orbital_weirdness <- function(df) {
  numeric_fields <- intersect(
    c(
      "e", "a", "q", "i", "om", "w", "ma", "per", "ad",
      "sigma_e", "sigma_a", "sigma_q", "sigma_i",
      "condition_code", "data_arc", "n_obs_used",
      "t_jup", "moid", "moid_jup", "H", "diameter", "albedo", "rot_per"
    ),
    names(df)
  )

  df <- df |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(numeric_fields), safe_numeric)
    )

  df |>
    dplyr::mutate(
      i_rad = i * pi / 180,

      # Original agreed definition:
      # W_visible = sqrt(e^2 + [2 sin(i/2)]^2)
      W_visible = sqrt(
        e^2 + (2 * sin(i_rad / 2))^2
      ),

      # Signed Kozai-Lidov vertical angular-momentum-like quantity.
      # It is deliberately preserved as H_KL, not replaced by a new score.
      H_KL = dplyr::if_else(
        e >= 0 & e < 1,
        sqrt(pmax(0, 1 - e^2)) * cos(i_rad),
        NA_real_
      ),

      retrograde = i > 90,
      orbit_quality = dplyr::case_when(
        is.na(condition_code) ~ "unknown",
        condition_code <= 2 ~ "high",
        condition_code <= 5 ~ "moderate",
        TRUE ~ "low"
      ),
      orbit_quality = factor(
        orbit_quality,
        levels = c("high", "moderate", "low", "unknown")
      )
    ) |>
    add_linearized_metric_uncertainty()
}

add_linearized_metric_uncertainty <- function(df) {
  # First-order propagation using sigma_e and sigma_i only.
  # JPL supplies marginal 1-sigma uncertainties here, not the full covariance,
  # so these values are diagnostics rather than complete uncertainty estimates.
  df |>
    dplyr::mutate(
      sigma_i_rad = sigma_i * pi / 180,

      dW_de = dplyr::if_else(W_visible > 0, e / W_visible, 0),
      dW_di = dplyr::if_else(
        W_visible > 0,
        sin(i_rad) / W_visible,
        0
      ),
      sigma_W_visible_linear = sqrt(
        (dW_de * sigma_e)^2 +
          (dW_di * sigma_i_rad)^2
      ),

      h_sqrt = sqrt(pmax(1e-15, 1 - e^2)),
      dH_de = -e * cos(i_rad) / h_sqrt,
      dH_di = -h_sqrt * sin(i_rad),
      sigma_H_KL_linear = sqrt(
        (dH_de * sigma_e)^2 +
          (dH_di * sigma_i_rad)^2
      )
    ) |>
    dplyr::select(-dW_de, -dW_di, -h_sqrt, -dH_de, -dH_di)
}

read_snapshot_pages_robustly <- function(parquet_files) {
  # Older snapshots may contain conflicting schemas across page files.
  # Read each page independently and normalize all columns to character.
  # add_orbital_weirdness() later converts the documented numeric fields.
  parquet_files <- sort(parquet_files)

  pages <- purrr::map(parquet_files, function(path) {
    message("Reading page: ", basename(path))
    page <- arrow::read_parquet(path, as_data_frame = TRUE)

    page |>
      dplyr::mutate(
        dplyr::across(
          dplyr::everything(),
          ~ as.character(.x)
        )
      )
  })

  dplyr::bind_rows(pages)
}

rank_orbital_weirdness <- function(df) {
  df |>
    dplyr::filter(
      is.finite(W_visible),
      is.finite(H_KL)
    ) |>
    dplyr::mutate(
      # Larger W_visible means farther from a circular, coplanar prograde orbit.
      rank_W_visible = dplyr::min_rank(dplyr::desc(W_visible)),
      percentile_W_visible = dplyr::percent_rank(W_visible),

      # H_KL is signed. These are ordering rules, not replacement metrics:
      #   signed ascending: most negative/retrograde first
      #   near zero: closest to H_KL = 0 first (KL-susceptibility interpretation)
      rank_H_KL_signed_ascending = dplyr::min_rank(H_KL),
      rank_H_KL_near_zero = dplyr::min_rank(abs(H_KL)),
      percentile_H_KL_signed = dplyr::percent_rank(H_KL),
      percentile_H_KL_near_zero = 1 - dplyr::percent_rank(abs(H_KL))
    )
}


add_class_relative_metrics <- function(df, top_fraction = 0.01) {
  df |>
    dplyr::filter(!is.na(class)) |>
    dplyr::mutate(
      inclination_term = 2 * sin(i_rad / 2),
      W2 = W_visible^2,
      eccentricity_share = dplyr::if_else(
        W2 > 0,
        e^2 / W2,
        NA_real_
      ),
      inclination_share = dplyr::if_else(
        W2 > 0,
        inclination_term^2 / W2,
        NA_real_
      ),
      abs_H_KL = abs(H_KL)
    ) |>
    dplyr::group_by(class) |>
    dplyr::mutate(
      class_n = dplyr::n(),

      class_median_W = stats::median(W_visible, na.rm = TRUE),
      class_MAD_W = mad_or_na(W_visible),
      class_robust_z_W = dplyr::if_else(
        is.finite(class_MAD_W) & class_MAD_W > 0,
        (W_visible - class_median_W) / class_MAD_W,
        NA_real_
      ),

      class_rank_W = dplyr::min_rank(dplyr::desc(W_visible)),
      class_percentile_W = dplyr::if_else(
        class_n > 1,
        dplyr::percent_rank(W_visible),
        1
      ),
      class_tail_probability_W = class_rank_W / (class_n + 1),
      class_surprisal_W = -log10(class_tail_probability_W),
      class_top_n = pmax(1L, ceiling(top_fraction * class_n)),
      class_top_W = class_rank_W <= class_top_n,

      class_rank_H_near_zero = dplyr::min_rank(abs_H_KL),
      class_percentile_H_near_zero = dplyr::if_else(
        class_n > 1,
        1 - dplyr::percent_rank(abs_H_KL),
        1
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-W2)
}

class_rank_stability <- function(
    all_df,
    screened_df,
    fraction = 0.01,
    min_class_n = 100L
) {
  rank_top <- function(df) {
    df |>
      dplyr::filter(!is.na(class), is.finite(W_visible)) |>
      dplyr::group_by(class) |>
      dplyr::mutate(
        class_n = dplyr::n(),
        rank = dplyr::min_rank(dplyr::desc(W_visible)),
        cutoff = pmax(1L, ceiling(fraction * class_n))
      ) |>
      dplyr::filter(rank <= cutoff) |>
      dplyr::ungroup()
  }

  all_top <- rank_top(all_df)
  screened_top <- rank_top(screened_df)

  classes <- intersect(unique(all_df$class), unique(screened_df$class))

  purrr::map_dfr(classes, function(class_code) {
    all_class <- all_df |>
      dplyr::filter(class == class_code)
    screened_class <- screened_df |>
      dplyr::filter(class == class_code)

    if (nrow(all_class) < min_class_n || nrow(screened_class) < min_class_n) {
      return(tibble::tibble())
    }

    ids_all <- all_top |>
      dplyr::filter(class == class_code) |>
      dplyr::pull(spkid) |>
      unique()

    ids_screened <- screened_top |>
      dplyr::filter(class == class_code) |>
      dplyr::pull(spkid) |>
      unique()

    intersection_n <- length(intersect(ids_all, ids_screened))
    union_n <- length(union(ids_all, ids_screened))

    tibble::tibble(
      class = class_code,
      n_all = nrow(all_class),
      n_screened = nrow(screened_class),
      excluded_fraction = 1 - nrow(screened_class) / nrow(all_class),
      top_n_all = length(ids_all),
      top_n_screened = length(ids_screened),
      top_intersection_n = intersection_n,
      top_jaccard = if (union_n > 0) intersection_n / union_n else NA_real_,
      all_top_retained_as_screened_top = if (length(ids_all) > 0) {
        intersection_n / length(ids_all)
      } else {
        NA_real_
      }
    )
  })
}

class_context_effects <- function(df) {
  context <- df |>
    dplyr::mutate(
      log10_a = dplyr::if_else(a > 0, log10(a), NA_real_),
      log10_q = dplyr::if_else(q > 0, log10(q), NA_real_),
      log10_moid = dplyr::if_else(moid > 0, log10(moid), NA_real_),
      log10_diameter = dplyr::if_else(diameter > 0, log10(diameter), NA_real_),
      log10_data_arc = dplyr::if_else(data_arc > 0, log10(data_arc), NA_real_),
      log10_n_obs = dplyr::if_else(n_obs_used > 0, log10(n_obs_used), NA_real_)
    ) |>
    dplyr::select(
      class,
      class_top_W,
      log10_a,
      log10_q,
      t_jup,
      log10_moid,
      H,
      log10_diameter,
      albedo,
      log10_data_arc,
      log10_n_obs
    ) |>
    tidyr::pivot_longer(
      cols = -c(class, class_top_W),
      names_to = "variable",
      values_to = "value"
    )

  context |>
    dplyr::group_by(class, variable) |>
    dplyr::summarise(
      n_top = sum(class_top_W & is.finite(value)),
      n_rest = sum(!class_top_W & is.finite(value)),
      median_top = median_or_na(value[class_top_W]),
      median_rest = median_or_na(value[!class_top_W]),
      IQR_all = iqr_or_na(value),
      standardized_median_shift = dplyr::if_else(
        is.finite(IQR_all) & IQR_all > 0,
        (median_top - median_rest) / IQR_all,
        NA_real_
      ),
      .groups = "drop"
    )
}

stratified_sample <- function(df, group_col = "class", n_per_group = 15000L, seed = 1L) {
  set.seed(seed)
  group_sym <- rlang::sym(group_col)

  df |>
    dplyr::filter(!is.na(!!group_sym)) |>
    dplyr::group_by(!!group_sym) |>
    dplyr::group_modify(
      ~ dplyr::slice_sample(.x, n = min(nrow(.x), n_per_group))
    ) |>
    dplyr::ungroup()
}

eta_squared_oneway <- function(x, group) {
  ok <- is.finite(x) & !is.na(group)
  x <- x[ok]
  group <- as.factor(group[ok])

  if (length(x) < 2L || nlevels(group) < 2L) {
    return(NA_real_)
  }

  grand_mean <- mean(x)
  group_n <- table(group)
  group_mean <- tapply(x, group, mean)
  ss_between <- sum(as.numeric(group_n) * (group_mean - grand_mean)^2)
  ss_total <- sum((x - grand_mean)^2)

  if (ss_total == 0) NA_real_ else ss_between / ss_total
}

entropy_from_counts <- function(counts) {
  p <- counts / sum(counts)
  p <- p[p > 0]
  -sum(p * log(p))
}

normalized_mutual_information <- function(x, group, n_bins = 20L) {
  ok <- is.finite(x) & !is.na(group)
  x <- x[ok]
  group <- as.factor(group[ok])

  if (length(x) < 2L || nlevels(group) < 2L) {
    return(NA_real_)
  }

  breaks <- unique(stats::quantile(
    x,
    probs = seq(0, 1, length.out = n_bins + 1L),
    na.rm = TRUE,
    names = FALSE
  ))

  if (length(breaks) < 3L) {
    return(NA_real_)
  }

  bins <- cut(x, breaks = breaks, include.lowest = TRUE)
  tab <- table(bins, group)
  pxy <- tab / sum(tab)
  px <- rowSums(pxy)
  py <- colSums(pxy)

  mi <- 0
  for (r in seq_len(nrow(pxy))) {
    for (c in seq_len(ncol(pxy))) {
      if (pxy[r, c] > 0) {
        mi <- mi + pxy[r, c] * log(pxy[r, c] / (px[r] * py[c]))
      }
    }
  }

  hx <- entropy_from_counts(rowSums(tab))
  hy <- entropy_from_counts(colSums(tab))
  denom <- sqrt(hx * hy)

  if (denom == 0) NA_real_ else mi / denom
}

top_fraction_class_enrichment <- function(df, metric, fraction = 0.01) {
  metric_sym <- rlang::ensym(metric)
  threshold <- stats::quantile(
    dplyr::pull(df, !!metric_sym),
    probs = 1 - fraction,
    na.rm = TRUE
  )

  baseline <- df |>
    dplyr::filter(!is.na(class)) |>
    dplyr::count(class, name = "n_all") |>
    dplyr::mutate(p_all = n_all / sum(n_all))

  selected <- df |>
    dplyr::filter(!is.na(class), !!metric_sym >= threshold) |>
    dplyr::count(class, name = "n_selected") |>
    dplyr::mutate(p_selected = n_selected / sum(n_selected))

  dplyr::full_join(baseline, selected, by = "class") |>
    dplyr::mutate(
      dplyr::across(c(n_all, n_selected), ~ tidyr::replace_na(.x, 0L)),
      dplyr::across(c(p_all, p_selected), ~ tidyr::replace_na(.x, 0)),
      enrichment = dplyr::if_else(p_all > 0, p_selected / p_all, NA_real_)
    ) |>
    dplyr::arrange(dplyr::desc(enrichment))
}
