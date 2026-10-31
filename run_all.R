# Stephen Gray July 2026
# Run the complete analysis in isolated R sessions.

args <- commandArgs(trailingOnly = TRUE)
allowed_args <- "--skip-download"
unknown_args <- setdiff(args, allowed_args)

if (length(unknown_args) > 0L) {
  stop(
    "Unknown argument(s): ", paste(unknown_args, collapse = ", "),
    "\nAllowed argument: --skip-download",
    call. = FALSE
  )
}

steps <- c(
  "01_download_sbdb.R",
  "02_compute_metrics.R",
  "03_visualize_and_diagnose.R",
  "04_class_specific_analysis.R"
)

if ("--skip-download" %in% args) {
  steps <- steps[-1L]
}

rscript <- file.path(R.home("bin"), "Rscript")

for (step in steps) {
  message("\n==> Running ", step)
  status <- system2(rscript, step)
  if (!identical(status, 0L)) {
    stop(step, " failed with exit status ", status, ".", call. = FALSE)
  }
}

message("\nPipeline completed successfully.")
