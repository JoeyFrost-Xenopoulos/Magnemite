args <- commandArgs(trailingOnly = TRUE)
server_dir <- if (length(args) >= 1) args[1] else NULL
timing_ticks_dir <- if (length(args) >= 2) args[2] else NULL
output_dir <- if (length(args) >= 3) args[3] else NULL

if (!requireNamespace("Magnemite", quietly = TRUE)) {
  stop("Package 'Magnemite' must be installed to run this script.")
}

Magnemite::run_magnemite_brushclust_app(
  server_dir = server_dir,
  timing_ticks_dir = timing_ticks_dir,
  output_dir = output_dir
)
