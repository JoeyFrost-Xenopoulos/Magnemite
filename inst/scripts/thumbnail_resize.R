args <- commandArgs(trailingOnly = TRUE)
custom_output_dir <- if (length(args) > 0) args[1] else NULL

if (!requireNamespace("Magnemite", quietly = TRUE)) {
	stop("Package 'Magnemite' must be installed to run this script.")
}

Magnemite::magnemite_process_thumbnail_images(output_dir = custom_output_dir)
