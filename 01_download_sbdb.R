# Stephen Gray July 2026
# Synapse8087@proton.me
source("config.R")
source("R/functions.R")
check_packages()

snapshot_id <- timestamp_utc()
snapshot_dir <- file.path("data", "raw", paste0("sbdb_asteroids_", snapshot_id))
dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)

download_sbdb_pages(
  endpoint = SBDB_ENDPOINT,
  fields = SBDB_FIELDS,
  sb_kind = SB_KIND,
  constraints = SB_CONSTRAINTS,
  output_dir = snapshot_dir,
  page_size = PAGE_SIZE,
  pause_seconds = REQUEST_PAUSE_SECONDS,
  max_retries = MAX_RETRIES
)

writeLines(snapshot_dir, file.path("data", "raw", "LATEST_SNAPSHOT.txt"))
message("Snapshot complete: ", snapshot_dir)
