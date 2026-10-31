# Deterministic, network-free checks for the core analysis helpers.

scripts <- c(
  "config.R",
  "R/functions.R",
  "00_install_packages.R",
  "01_download_sbdb.R",
  "02_compute_metrics.R",
  "03_visualize_and_diagnose.R",
  "04_class_specific_analysis.R",
  "run_all.R"
)
invisible(lapply(scripts, parse))

source("config.R")
source("R/functions.R")
check_packages()

payload <- list(
  signature = list(version = "1.0"),
  fields = c("spkid", "pdes", "e", "i"),
  data = list(
    list("1", "2005 TQ11", "0.2", "15"),
    list("2", "12345", "0.0", "180")
  )
)

parsed <- parse_sbdb_page(payload)
stopifnot(
  identical(parsed$pdes, c("2005 TQ11", "12345")),
  is.numeric(parsed$e),
  is.numeric(parsed$i)
)

example <- tibble::tibble(
  spkid = c("circular", "retrograde", "eccentric"),
  class = c("A", "A", "B"),
  e = c(0, 0, 0.6),
  i = c(0, 180, 0),
  sigma_e = c(0.001, 0.001, 0.001),
  sigma_i = c(0.01, 0.01, 0.01),
  condition_code = c(0, 0, 0)
)

scored <- example |>
  add_orbital_weirdness() |>
  rank_orbital_weirdness()

stopifnot(
  isTRUE(all.equal(scored$W_visible, c(0, 2, 0.6), tolerance = 1e-12)),
  isTRUE(all.equal(scored$H_KL, c(1, -1, 0.8), tolerance = 1e-12)),
  identical(scored$rank_W_visible, c(3L, 1L, 2L)),
  identical(scored$retrograde, c(FALSE, TRUE, FALSE))
)

relative <- add_class_relative_metrics(scored)
nonzero <- relative$W_visible > 0
stopifnot(isTRUE(all.equal(
  relative$eccentricity_share[nonzero] + relative$inclination_share[nonzero],
  rep(1, sum(nonzero)),
  tolerance = 1e-12
)))

codec <- choose_parquet_compression()
parquet_path <- tempfile(fileext = ".parquet")
on.exit(unlink(parquet_path), add = TRUE)
arrow::write_parquet(scored, parquet_path, compression = codec)
round_trip <- arrow::read_parquet(parquet_path)
stopifnot(
  identical(nrow(round_trip), nrow(scored)),
  identical(as.character(round_trip$spkid), scored$spkid)
)

message("Smoke tests passed with Parquet compression: ", codec)
