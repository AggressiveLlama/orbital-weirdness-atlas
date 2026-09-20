# Stephen Gray July 2026
# Synapse8087@proton.me
source("config.R")
source("R/functions.R")
check_packages()

snapshot_id <- Sys.getenv("SBDB_SNAPSHOT_ID", unset = timestamp_utc())
if (!grepl("^[A-Za-z0-9_.-]+$", snapshot_id)) {
  stop(
    "SBDB_SNAPSHOT_ID may contain only letters, numbers, periods, underscores, and hyphens.",
    call. = FALSE
  )
}
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
  max_retries = MAX_RETRIES,
  user_agent = SBDB_USER_AGENT,
  expected_api_version = SBDB_EXPECTED_API_VERSION
)

writeLines(snapshot_dir, file.path("data", "raw", "LATEST_SNAPSHOT.txt"))
message("Snapshot complete: ", snapshot_dir)
