# Stephen Gray July 2026
# Synapse8087@proton.me
source("config.R")
source("R/functions.R")
check_packages()

latest_file <- file.path("data", "raw", "LATEST_SNAPSHOT.txt")
if (!file.exists(latest_file)) {
  stop("No snapshot pointer found. Run 01_download_sbdb.R first.", call. = FALSE)
}

snapshot_dir <- trimws(readLines(latest_file, warn = FALSE)[1])
if (!dir.exists(snapshot_dir)) {
  stop("Snapshot directory does not exist: ", snapshot_dir, call. = FALSE)
}

message("Reading snapshot: ", snapshot_dir)
parquet_files <- list.files(
  snapshot_dir,
  pattern = "\\.parquet$",
  full.names = TRUE
)

if (length(parquet_files) == 0L) {
  stop("No Parquet pages found in snapshot: ", snapshot_dir, call. = FALSE)
}

# Read pages independently because older downloads may contain incompatible
# schemas caused by page-by-page type inference. This salvages the completed
# snapshot without downloading it again.
raw <- read_snapshot_pages_robustly(parquet_files)
gc()

if (anyDuplicated(raw$spkid)) {
  warning(
    "Duplicate SPK-IDs were found. The live database may have changed during pagination; ",
    "inspect the snapshot manifest and consider downloading a fresh snapshot.",
    call. = FALSE
  )
}

ranked <- raw |>
  add_orbital_weirdness() |>
  rank_orbital_weirdness()

dir.create(file.path("data", "processed"), recursive = TRUE, showWarnings = FALSE)
processed_path <- file.path(
  "data", "processed",
  paste0("sbdb_orbital_weirdness_", basename(snapshot_dir), ".parquet")
)
parquet_compression <- choose_parquet_compression()
message("Processed-data Parquet compression codec: ", parquet_compression)
arrow::write_parquet(
  ranked,
  processed_path,
  compression = parquet_compression
)
writeLines(processed_path, file.path("data", "processed", "LATEST_PROCESSED.txt"))

tables_dir <- file.path("results", "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

identity_cols <- c(
  "spkid", "full_name", "pdes", "name", "class", "neo", "pha",
  "e", "i", "a", "q", "condition_code", "data_arc", "n_obs_used",
  "W_visible", "H_KL", "sigma_W_visible_linear", "sigma_H_KL_linear"
)

top_w <- ranked |>
  dplyr::arrange(rank_W_visible) |>
  dplyr::select(
    rank_W_visible,
    dplyr::any_of(identity_cols)
  ) |>
  dplyr::slice_head(n = TOP_N)

top_h_zero <- ranked |>
  dplyr::arrange(rank_H_KL_near_zero) |>
  dplyr::select(
    rank_H_KL_near_zero,
    dplyr::any_of(identity_cols)
  ) |>
  dplyr::slice_head(n = TOP_N)

top_h_signed <- ranked |>
  dplyr::arrange(rank_H_KL_signed_ascending) |>
  dplyr::select(
    rank_H_KL_signed_ascending,
    dplyr::any_of(identity_cols)
  ) |>
  dplyr::slice_head(n = TOP_N)

readr::write_csv(top_w, file.path(tables_dir, "top_W_visible.csv"))
readr::write_csv(top_h_zero, file.path(tables_dir, "top_H_KL_near_zero.csv"))
readr::write_csv(top_h_signed, file.path(tables_dir, "top_H_KL_signed_ascending.csv"))

message("Processed dataset written to: ", processed_path)
