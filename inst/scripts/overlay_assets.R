args <- commandArgs(trailingOnly = TRUE)
custom_output_dir <- if (length(args) > 0) args[1] else NULL

if (!requireNamespace("Magnemite", quietly = TRUE)) {
  stop("Package 'Magnemite' must be installed to run this script.")
}

Magnemite::magnemite_build_web_trace_assets(output_dir = custom_output_dir)
