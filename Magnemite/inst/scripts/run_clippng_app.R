args <- commandArgs(trailingOnly = TRUE)
project_dir <- if (length(args) >= 1) args[1] else NULL
db_path <- if (length(args) >= 2) args[2] else NULL
output_dir <- if (length(args) >= 3) args[3] else NULL

if (!requireNamespace("Magnemite", quietly = TRUE)) {
  stop("Package 'Magnemite' must be installed to run this script.")
}

Magnemite::run_magnemite_clippng_app(
  project_dir = project_dir,
  db_path = db_path,
  output_dir = output_dir
)
