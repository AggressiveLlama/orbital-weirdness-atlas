# Stephen Gray July 2026
# Synapse8087@proton.me
source("config.R")
source("R/functions.R")
check_packages()

processed_pointer <- file.path("data", "processed", "LATEST_PROCESSED.txt")
if (!file.exists(processed_pointer)) {
  stop("No processed dataset found. Run 02_compute_metrics.R first.", call. = FALSE)
}

processed_path <- trimws(readLines(processed_pointer, warn = FALSE)[1])
df <- arrow::read_parquet(processed_path)

fig_dir <- file.path("results", "figures")
tab_dir <- file.path("results", "tables")
processed_dir <- file.path("data", "processed")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

class_labels <- c(
  IEO = "Atira / interior-Earth",
  ATE = "Aten",
  APO = "Apollo",
  AMO = "Amor",
  MCA = "Mars-crosser",
  IMB = "Inner main belt",
  MBA = "Main belt",
  OMB = "Outer main belt",
  TJN = "Jupiter Trojan",
  CEN = "Centaur",
  TNO = "Trans-Neptunian",
  AST = "Other asteroid"
)

display_name <- function(full_name, name, pdes, spkid) {
  clean_text <- function(x) {
    dplyr::na_if(stringr::str_squish(as.character(x)), "")
  }

  dplyr::coalesce(
    clean_text(full_name),
    clean_text(name),
    clean_text(pdes),
    as.character(spkid)
  )
}

# Populations ------------------------------------------------------------------

all_valid <- df |>
  dplyr::filter(
    !is.na(class),
    is.finite(W_visible),
    is.finite(H_KL)
  )

quality_valid <- all_valid |>
  dplyr::filter(is.na(condition_code) | condition_code <= 5) |>
  add_class_relative_metrics(top_fraction = CLASS_TOP_FRACTION) |>
  dplyr::mutate(
    class_label = dplyr::recode(
      class,
      !!!as.list(class_labels),
      .default = class
    ),
    object_name = display_name(full_name, name, pdes, spkid)
  )

class_counts <- quality_valid |>
  dplyr::count(class, class_label, name = "n")

analysis_classes <- class_counts |>
  dplyr::filter(n >= MIN_CLASS_ANALYSIS_N) |>
  dplyr::pull(class)

analysis_df <- quality_valid |>
  dplyr::filter(class %in% analysis_classes)

# Save class-relative metric columns for reuse ---------------------------------

class_metric_path <- file.path(
  processed_dir,
  "sbdb_class_relative_metrics.parquet"
)
compression <- choose_parquet_compression()
arrow::write_parquet(
  quality_valid,
  class_metric_path,
  compression = compression
)

# Top objects within each class ------------------------------------------------

top_by_class <- analysis_df |>
  dplyr::group_by(class, class_label) |>
  dplyr::arrange(class_rank_W, .by_group = TRUE) |>
  dplyr::slice_head(n = TOP_PER_CLASS) |>
  dplyr::ungroup() |>
  dplyr::select(
    class,
    class_label,
    class_n,
    class_rank_W,
    class_percentile_W,
    class_robust_z_W,
    class_surprisal_W,
    object_name,
    spkid,
    pdes,
    full_name,
    e,
    i,
    a,
    q,
    W_visible,
    H_KL,
    eccentricity_share,
    inclination_share,
    condition_code,
    sigma_W_visible_linear,
    data_arc,
    n_obs_used
  )

readr::write_csv(
  top_by_class,
  file.path(tab_dir, "top_W_visible_within_each_class.csv")
)

# Most typical objects: closest to the class median ----------------------------

typical_by_class <- analysis_df |>
  dplyr::mutate(
    distance_from_class_median_W = abs(W_visible - class_median_W)
  ) |>
  dplyr::group_by(class, class_label) |>
  dplyr::slice_min(
    distance_from_class_median_W,
    n = 5,
    with_ties = FALSE
  ) |>
  dplyr::ungroup() |>
  dplyr::select(
    class,
    class_label,
    object_name,
    spkid,
    e,
    i,
    a,
    q,
    W_visible,
    H_KL,
    class_median_W,
    distance_from_class_median_W
  )

readr::write_csv(
  typical_by_class,
  file.path(tab_dir, "most_typical_W_visible_within_each_class.csv")
)

# Class-level diagnostic summary -----------------------------------------------

class_specific_summary <- analysis_df |>
  dplyr::group_by(class, class_label) |>
  dplyr::summarise(
    n = dplyr::n(),
    median_W = stats::median(W_visible),
    IQR_W = stats::IQR(W_visible),
    MAD_W = mad_or_na(W_visible),
    q90_W = stats::quantile(W_visible, 0.90),
    q99_W = stats::quantile(W_visible, 0.99),
    max_W = max(W_visible),
    median_H_KL = stats::median(H_KL),
    fraction_retrograde = mean(retrograde),
    spearman_W_e = stats::cor(W_visible, e, method = "spearman"),
    spearman_W_i = stats::cor(W_visible, i, method = "spearman"),
    spearman_W_H = stats::cor(W_visible, H_KL, method = "spearman"),
    mean_eccentricity_share = mean(eccentricity_share, na.rm = TRUE),
    mean_inclination_share = mean(inclination_share, na.rm = TRUE),
    top1_mean_eccentricity_share = mean(
      eccentricity_share[class_top_W],
      na.rm = TRUE
    ),
    top1_mean_inclination_share = mean(
      inclination_share[class_top_W],
      na.rm = TRUE
    ),
    top1_median_W = stats::median(W_visible[class_top_W]),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    small_angle_RMSE = purrr::map_dbl(
      class,
      function(class_code) {
        class_data <- analysis_df |>
          dplyr::filter(class == class_code)
        sqrt(mean(
          (
            class_data$H_KL -
              (1 - class_data$W_visible^2 / 2)
          )^2,
          na.rm = TRUE
        ))
      }
    )
  ) |>
  dplyr::arrange(dplyr::desc(q99_W))

readr::write_csv(
  class_specific_summary,
  file.path(tab_dir, "class_specific_weirdness_summary.csv")
)

# Context outside the metric definition ----------------------------------------

context_effects <- class_context_effects(analysis_df) |>
  dplyr::mutate(
    class_label = dplyr::recode(
      class,
      !!!as.list(class_labels),
      .default = class
    ),
    variable_label = dplyr::recode(
      variable,
      log10_a = "log10 semimajor axis",
      log10_q = "log10 perihelion",
      t_jup = "Tisserand parameter",
      log10_moid = "log10 Earth MOID",
      H = "absolute magnitude H",
      log10_diameter = "log10 diameter",
      albedo = "albedo",
      log10_data_arc = "log10 observation arc",
      log10_n_obs = "log10 observations",
      .default = variable
    )
  )

readr::write_csv(
  context_effects,
  file.path(tab_dir, "class_top1_context_effects.csv")
)

# Rank stability by class ------------------------------------------------------

stability <- class_rank_stability(
  all_df = all_valid,
  screened_df = quality_valid,
  fraction = CLASS_TOP_FRACTION,
  min_class_n = MIN_CLASS_ANALYSIS_N
) |>
  dplyr::mutate(
    class_label = dplyr::recode(
      class,
      !!!as.list(class_labels),
      .default = class
    )
  ) |>
  dplyr::arrange(top_jaccard)

readr::write_csv(
  stability,
  file.path(tab_dir, "class_rank_stability_quality_screen.csv")
)

# Plotting sample ---------------------------------------------------------------

plot_df <- stratified_sample(
  analysis_df,
  group_col = "class",
  n_per_group = CLASS_PLOT_N_PER_CLASS,
  seed = RANDOM_SEED
)

# Figure 7: top objects within each class --------------------------------------

top_plot <- top_by_class |>
  dplyr::filter(is.finite(class_robust_z_W)) |>
  dplyr::group_by(class) |>
  dplyr::slice_head(n = 5L) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    object_name = stringr::str_trunc(object_name, width = 28),
    object_name = stats::reorder(object_name, class_robust_z_W)
  )

p7 <- ggplot2::ggplot(
  top_plot,
  ggplot2::aes(
    x = class_robust_z_W,
    y = object_name
  )
) +
  ggplot2::geom_segment(
    ggplot2::aes(
      x = 0,
      xend = class_robust_z_W,
      y = object_name,
      yend = object_name
    ),
    linewidth = 0.4
  ) +
  ggplot2::geom_point(size = 2) +
  ggplot2::facet_wrap(
    ~ class_label,
    scales = "free_y",
    ncol = 3
  ) +
  ggplot2::labs(
    title = "The most unusual objects relative to their own orbital class",
    subtitle = "Robust z-score uses each class median and MAD; five leaders shown per class",
    x = "Within-class robust z-score of W_visible",
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  file.path(fig_dir, "07_top_objects_within_class.png"),
  p7,
  width = 13,
  height = 12,
  dpi = 220
)

# Figure 8: eccentricity/inclination contribution ------------------------------

component_summary <- dplyr::bind_rows(
  analysis_df |>
    dplyr::group_by(class, class_label) |>
    dplyr::summarise(
      eccentricity = mean(eccentricity_share, na.rm = TRUE),
      inclination = mean(inclination_share, na.rm = TRUE),
      population = "All bodies",
      .groups = "drop"
    ),
  analysis_df |>
    dplyr::filter(class_top_W) |>
    dplyr::group_by(class, class_label) |>
    dplyr::summarise(
      eccentricity = mean(eccentricity_share, na.rm = TRUE),
      inclination = mean(inclination_share, na.rm = TRUE),
      population = "Top 1% within class",
      .groups = "drop"
    )
) |>
  tidyr::pivot_longer(
    cols = c(eccentricity, inclination),
    names_to = "component",
    values_to = "share"
  ) |>
  dplyr::mutate(
    component = dplyr::recode(
      component,
      eccentricity = "Eccentricity contribution",
      inclination = "Inclination contribution"
    ),
    population = factor(
      population,
      levels = c("All bodies", "Top 1% within class")
    )
  )

p8 <- ggplot2::ggplot(
  component_summary,
  ggplot2::aes(
    x = class_label,
    y = share,
    fill = component
  )
) +
  ggplot2::geom_col() +
  ggplot2::facet_wrap(~ population, ncol = 1) +
  ggplot2::scale_y_continuous(
    labels = scales::percent_format(accuracy = 1)
  ) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "What drives W_visible within each orbital class?",
    subtitle = "Mean shares of W_visible²; the two components sum to one for each object",
    x = NULL,
    y = "Mean contribution to W_visible²",
    fill = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(
  file.path(fig_dir, "08_W_visible_component_decomposition_by_class.png"),
  p8,
  width = 10,
  height = 10,
  dpi = 220
)

# Figure 9: class-relative phase maps ------------------------------------------

p9 <- ggplot2::ggplot(
  plot_df,
  ggplot2::aes(
    x = i,
    y = e,
    color = class_percentile_W
  )
) +
  ggplot2::geom_point(alpha = 0.38, size = 0.55) +
  ggplot2::facet_wrap(
    ~ class_label,
    scales = "free",
    ncol = 3
  ) +
  ggplot2::scale_color_viridis_c(
    labels = scales::percent_format(accuracy = 1),
    name = "Within-class\nW percentile"
  ) +
  ggplot2::labs(
    title = "Orbital weirdness relative to each object's peers",
    subtitle = "Color is class-relative; axis ranges are allowed to vary by class",
    x = "Inclination i (degrees)",
    y = "Eccentricity e"
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  file.path(fig_dir, "09_class_relative_eccentricity_inclination.png"),
  p9,
  width = 14,
  height = 12,
  dpi = 220
)

# Figure 10: non-definitional context shifts -----------------------------------

heatmap_df <- context_effects |>
  dplyr::filter(
    n_top >= 10,
    n_rest >= 50,
    is.finite(standardized_median_shift)
  )

p10 <- ggplot2::ggplot(
  heatmap_df,
  ggplot2::aes(
    x = variable_label,
    y = class_label,
    fill = standardized_median_shift
  )
) +
  ggplot2::geom_tile() +
  ggplot2::scale_fill_gradient2(
    midpoint = 0,
    limits = c(-3, 3),
    oob = scales::squish,
    name = "Median shift\n(in class IQRs)"
  ) +
  ggplot2::labs(
    title = "How the weirdest 1% differ from the rest of their class",
    subtitle = "Variables outside the e–i definition of W_visible; blank cells lack adequate data",
    x = NULL,
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(
      angle = 45,
      hjust = 1
    )
  )

ggplot2::ggsave(
  file.path(fig_dir, "10_class_top1_context_heatmap.png"),
  p10,
  width = 12,
  height = 8,
  dpi = 220
)

# Figure 11: rank stability by class -------------------------------------------

p11 <- stability |>
  dplyr::mutate(
    class_label = stats::reorder(class_label, top_jaccard)
  ) |>
  ggplot2::ggplot(
    ggplot2::aes(
      x = class_label,
      y = top_jaccard
    )
  ) +
  ggplot2::geom_col() +
  ggplot2::coord_flip() +
  ggplot2::scale_y_continuous(
    limits = c(0, 1),
    labels = scales::percent_format(accuracy = 1)
  ) +
  ggplot2::labs(
    title = "Within-class top-1% stability after orbit-quality screening",
    subtitle = "Jaccard overlap between the unrestricted and condition_code <= 5 leader sets",
    x = NULL,
    y = "Top-set Jaccard overlap"
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  file.path(fig_dir, "11_class_rank_stability.png"),
  p11,
  width = 9,
  height = 7,
  dpi = 220
)

# Figure 12: where H_KL departs from the small-angle approximation -------------

p12 <- class_specific_summary |>
  dplyr::mutate(
    class_label = stats::reorder(class_label, small_angle_RMSE)
  ) |>
  ggplot2::ggplot(
    ggplot2::aes(
      x = class_label,
      y = small_angle_RMSE
    )
  ) +
  ggplot2::geom_col() +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Where H_KL stops being merely a small-angle rewrite of W_visible",
    subtitle = "RMSE from H_KL ≈ 1 - W_visible²/2 within each class",
    x = NULL,
    y = "Approximation RMSE"
  ) +
  ggplot2::theme_minimal(base_size = 11)

ggplot2::ggsave(
  file.path(fig_dir, "12_H_KL_small_angle_departure_by_class.png"),
  p12,
  width = 9,
  height = 7,
  dpi = 220
)

message("Class-relative dataset: ", class_metric_path)
message("Class-specific figures written to: ", fig_dir)
message("Class-specific tables written to: ", tab_dir)
