args <- commandArgs(trailingOnly = TRUE)
input_dir <- if (length(args) >= 1) args[1] else NULL
output_dir <- if (length(args) >= 2) args[2] else NULL

if (!requireNamespace("Magnemite", quietly = TRUE)) {
  stop("Package 'Magnemite' must be installed to run this script.")
}

paths <- Magnemite::magnemite_functional_paths()
if (is.null(input_dir) || !nzchar(input_dir)) {
  input_dir <- paths$timing_ticks_dir
}
if (is.null(output_dir) || !nzchar(output_dir)) {
  output_dir <- paths$attempts_dir
}

Magnemite::magnemite_assign_actual_times_batch(
  input_dir = input_dir,
  output_dir = output_dir
)
