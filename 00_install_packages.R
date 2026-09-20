# Stephen Gray July 2026
# Synapse8087@proton.me
# Restore the exact package versions recorded in renv.lock.

repos <- getOption("repos")
if (
  is.null(repos) ||
    is.null(repos[["CRAN"]]) ||
    identical(unname(repos[["CRAN"]]), "@CRAN@")
) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

renv::restore(prompt = FALSE)
message("The locked R environment is ready.")
