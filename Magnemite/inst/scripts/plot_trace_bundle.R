args <- commandArgs(trailingOnly = TRUE)
base_name <- if (length(args) >= 1) args[1] else NULL

if (is.null(base_name) || !nzchar(base_name)) {
  stop("Usage: Rscript plot_trace_bundle.R <base_name>")
}

if (!requireNamespace("Magnemite", quietly = TRUE)) {
  stop("Package 'Magnemite' must be installed to run this script.")
}

bundle <- Magnemite::magnemite_load_trace_bundle(base_name = base_name)
Magnemite::magnemite_plot_traces_with_ticks(bundle)
