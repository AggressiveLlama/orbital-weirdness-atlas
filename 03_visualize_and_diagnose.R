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
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

# Analysis populations ---------------------------------------------------------

all_valid <- df |>
  dplyr::filter(is.finite(W_visible), is.finite(H_KL))

quality_valid <- all_valid |>
  dplyr::filter(is.na(condition_code) | condition_code <= 5)

plot_df <- stratified_sample(
  quality_valid,
  group_col = "class",
  n_per_group = PLOT_N_PER_CLASS,
  seed = RANDOM_SEED
)

common_classes <- quality_valid |>
  dplyr::filter(!is.na(class)) |>
  dplyr::count(class, sort = TRUE) |>
  dplyr::filter(n >= MIN_CLASS_N) |>
  dplyr::slice_head(n = 12) |>
  dplyr::pull(class)

# Figure 1: e-i phase map ------------------------------------------------------

p1 <- ggplot2::ggplot(
  quality_valid,
  ggplot2::aes(x = i, y = e)
) +
  ggplot2::geom_hex(bins = 120) +
  ggplot2::scale_fill_viridis_c(
    trans = "log10",
    name = "Bodies/bin"
  ) +
  ggplot2::labs(
    title = "Bound asteroids in eccentricity–inclination space",
    subtitle = "Complete quality-screened dataset; logarithmic hex-bin counts",
    x = "Inclination i (degrees)",
    y = "Eccentricity e",
    caption = "Quality screen: condition_code <= 5 or unavailable"
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(
  file.path(fig_dir, "01_eccentricity_inclination_density.png"),
  p1, width = 10, height = 7, dpi = 220
)

# Figure 2: metric map ---------------------------------------------------------

p2 <- ggplot2::ggplot(
  plot_df,
  ggplot2::aes(
    x = W_visible,
    y = H_KL,
    color = class
  )
) +
  ggplot2::geom_point(alpha = 0.32, size = 0.75) +
  ggplot2::geom_hline(yintercept = 0, linetype = 2) +
  ggplot2::labs(
    title = expression(paste(W[visible], " versus signed ", H[KL])),
    subtitle = "Class-stratified plotting sample; all statistics use the complete dataset",
    x = expression(W[visible] == sqrt(e^2 + (2 * sin(i / 2))^2)),
    y = expression(H[KL] == sqrt(1 - e^2) * cos(i)),
    color = "SBDB class"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(
  file.path(fig_dir, "02_W_visible_vs_H_KL.png"),
  p2, width = 11, height = 8, dpi = 220
)

# Figure 3: distributions by common orbit class -------------------------------

class_plot_df <- plot_df |>
  dplyr::filter(class %in% common_classes) |>
  tidyr::pivot_longer(
    cols = c(W_visible, H_KL),
    names_to = "metric",
    values_to = "value"
  ) |>
  dplyr::mutate(
    metric = factor(
      metric,
      levels = c("W_visible", "H_KL"),
      labels = c("W_visible", "H_KL")
    )
  )

p3 <- ggplot2::ggplot(
  class_plot_df,
  ggplot2::aes(x = class, y = value)
) +
  ggplot2::geom_violin(
    scale = "width",
    trim = TRUE,
    alpha = 0.75
  ) +
  ggplot2::geom_boxplot(
    width = 0.12,
    outlier.shape = NA,
    alpha = 0.5
  ) +
  ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 1) +
  ggplot2::labs(
    title = "Metric distributions across common SBDB orbit classes",
    subtitle = "A useful metric should show interpretable structure without merely duplicating class definitions",
    x = "SBDB orbit class",
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(
  file.path(fig_dir, "03_metric_distributions_by_class.png"),
  p3, width = 11, height = 10, dpi = 220
)

# Figure 4: semimajor axis context ---------------------------------------------

p4 <- ggplot2::ggplot(
  plot_df |>
    dplyr::filter(is.finite(a), a > 0),
  ggplot2::aes(
    x = a,
    y = e,
    color = W_visible
  )
) +
  ggplot2::geom_point(alpha = 0.34, size = 0.65) +
  ggplot2::scale_x_log10() +
  ggplot2::scale_color_viridis_c(name = "W_visible") +
  ggplot2::labs(
    title = "Where visible orbital weirdness occurs",
    subtitle = "Semimajor axis supplies dynamical context absent from W_visible itself",
    x = "Semimajor axis a (au, logarithmic)",
    y = "Eccentricity e"
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(
  file.path(fig_dir, "04_semimajor_axis_eccentricity_W_visible.png"),
  p4, width = 11, height = 7, dpi = 220
)

# Figure 5: uncertainty diagnostic ---------------------------------------------

uncertainty_df <- plot_df |>
  dplyr::filter(
    is.finite(sigma_W_visible_linear),
    sigma_W_visible_linear > 0
  )

p5 <- ggplot2::ggplot(
  uncertainty_df,
  ggplot2::aes(
    x = W_visible,
    y = sigma_W_visible_linear,
    color = orbit_quality
  )
) +
  ggplot2::geom_point(alpha = 0.30, size = 0.7) +
  ggplot2::scale_y_log10() +
  ggplot2::labs(
    title = "Is apparent weirdness dominated by orbital uncertainty?",
    subtitle = "First-order propagation from JPL sigma_e and sigma_i; full covariance is not included",
    x = "W_visible",
    y = "Approximate 1-sigma uncertainty in W_visible (log scale)",
    color = "Orbit quality"
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(
  file.path(fig_dir, "05_W_visible_uncertainty.png"),
  p5, width = 10, height = 7, dpi = 220
)

# Numerical diagnostics --------------------------------------------------------

class_summary <- quality_valid |>
  dplyr::filter(!is.na(class)) |>
  dplyr::group_by(class) |>
  dplyr::summarise(
    n = dplyr::n(),
    median_W_visible = stats::median(W_visible, na.rm = TRUE),
    IQR_W_visible = stats::IQR(W_visible, na.rm = TRUE),
    median_H_KL = stats::median(H_KL, na.rm = TRUE),
    IQR_H_KL = stats::IQR(H_KL, na.rm = TRUE),
    fraction_retrograde = mean(retrograde, na.rm = TRUE),
    median_condition_code = median_or_na(condition_code),
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(median_W_visible))

readr::write_csv(
  class_summary,
  file.path(tab_dir, "class_metric_summary.csv")
)

enrichment_w <- top_fraction_class_enrichment(
  quality_valid,
  W_visible,
  fraction = 0.01
)
readr::write_csv(
  enrichment_w,
  file.path(tab_dir, "top_1pct_W_visible_class_enrichment.csv")
)

p6 <- enrichment_w |>
  dplyr::filter(n_all >= MIN_CLASS_N, is.finite(enrichment)) |>
  dplyr::slice_max(enrichment, n = 15, with_ties = FALSE) |>
  dplyr::mutate(class = stats::reorder(class, enrichment)) |>
  ggplot2::ggplot(ggplot2::aes(x = class, y = enrichment)) +
  ggplot2::geom_col() +
  ggplot2::geom_hline(yintercept = 1, linetype = 2) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Orbit classes enriched among the top 1% of W_visible",
    subtitle = "Enrichment = selected share / baseline share; 1 means no enrichment",
    x = "SBDB orbit class",
    y = "Enrichment factor"
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(
  file.path(fig_dir, "06_top_W_visible_class_enrichment.png"),
  p6, width = 9, height = 7, dpi = 220
)

diagnostics <- tibble::tibble(
  population = c("all valid", "condition_code <= 5 or missing"),
  n = c(nrow(all_valid), nrow(quality_valid)),
  spearman_W_H = c(
    stats::cor(all_valid$W_visible, all_valid$H_KL, method = "spearman"),
    stats::cor(quality_valid$W_visible, quality_valid$H_KL, method = "spearman")
  ),
  eta2_W_by_class = c(
    eta_squared_oneway(all_valid$W_visible, all_valid$class),
    eta_squared_oneway(quality_valid$W_visible, quality_valid$class)
  ),
  eta2_H_by_class = c(
    eta_squared_oneway(all_valid$H_KL, all_valid$class),
    eta_squared_oneway(quality_valid$H_KL, quality_valid$class)
  ),
  NMI_W_class = c(
    normalized_mutual_information(all_valid$W_visible, all_valid$class),
    normalized_mutual_information(quality_valid$W_visible, quality_valid$class)
  ),
  NMI_H_class = c(
    normalized_mutual_information(all_valid$H_KL, all_valid$class),
    normalized_mutual_information(quality_valid$H_KL, quality_valid$class)
  )
)

readr::write_csv(
  diagnostics,
  file.path(tab_dir, "metric_diagnostics.csv")
)

# Rank-list sensitivity to orbit-quality screening -----------------------------

rank_overlap <- function(df_all, df_screened, rank_col, top_n) {
  rank_sym <- rlang::sym(rank_col)
  a <- df_all |>
    dplyr::arrange(!!rank_sym) |>
    dplyr::slice_head(n = top_n) |>
    dplyr::pull(spkid)
  b <- df_screened |>
    dplyr::arrange(!!rank_sym) |>
    dplyr::slice_head(n = top_n) |>
    dplyr::pull(spkid)

  length(intersect(a, b)) / length(union(a, b))
}

quality_ranked <- quality_valid |>
  rank_orbital_weirdness()

rank_stability <- tibble::tibble(
  ranking = c("W_visible descending", "H_KL nearest zero", "H_KL signed ascending"),
  top_100_jaccard = c(
    rank_overlap(all_valid, quality_ranked, "rank_W_visible", 100L),
    rank_overlap(all_valid, quality_ranked, "rank_H_KL_near_zero", 100L),
    rank_overlap(all_valid, quality_ranked, "rank_H_KL_signed_ascending", 100L)
  ),
  top_1000_jaccard = c(
    rank_overlap(all_valid, quality_ranked, "rank_W_visible", 1000L),
    rank_overlap(all_valid, quality_ranked, "rank_H_KL_near_zero", 1000L),
    rank_overlap(all_valid, quality_ranked, "rank_H_KL_signed_ascending", 1000L)
  )
)

readr::write_csv(
  rank_stability,
  file.path(tab_dir, "rank_stability_quality_screen.csv")
)

message("Figures written to: ", fig_dir)
message("Tables written to: ", tab_dir)
