# One-shot installer for Restless Earth
#
# Run this once from R before launching the app:
#   source("install.R")

packages <- c(
  "shiny",
  "bslib",
  "leaflet",
  "dplyr",
  "tidyr",
  "purrr",
  "tibble",
  "lubridate",
  "ggplot2",
  "scales",
  "jsonlite",
  "htmltools"
)

missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) == 0) {
  message("All packages already installed.")
} else {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}
