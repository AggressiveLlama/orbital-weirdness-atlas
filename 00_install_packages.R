# Stephen Gray July 2026
# Synapse8087@proton.me
packages <- c(
  "arrow", "dplyr", "ggplot2", "hexbin", "httr2", "jsonlite",
  "purrr", "readr", "rlang", "scales", "stringr", "tibble", "tidyr"
)

missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) == 0L) {
  message("All required packages are already installed.")
} else {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}
