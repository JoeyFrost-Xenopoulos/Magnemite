#' magnemite: Magnetogram Curation and Clustering Workflows
#'
#' The `magnemite` package collects the package-facing utilities used in the
#' historical magnetogram workflow: interactive clipping and timing-tick
#' correction apps, helpers for assigning and adjusting clock labels, and data
#' preparation utilities used in downstream clustering analyses.
#'
#' @section Function index:
#' - [clippng_app()] launches the interactive clipping app for top and bottom
#'   traces.
#' - [apply_clipped_csv()] writes a clipped CSV export back into a digitized RDS
#'   record.
#' - [apply_clipped_csv_batch()] applies many clipped CSV exports to matching
#'   digitized RDS files.
#' - [brushclust_app()] launches the timing-tick clustering app.
#' - [tick_click_app()] launches the timing-tick click-correction app.
#' - [list_tick_rds()] lists timing-trace RDS files while supporting base-name
#'   exclusions.
#' - [assign_times()] adds hourly labels to timing-tick tables.
#' - [assign_times_batch()] applies [assign_times()] across a directory of RDS
#'   files.
#' - [adjust_times()] shifts assigned hourly labels for the top trace, bottom
#'   trace, or both.
#' - [apply_adjustments()] applies a named set of manual date-based time
#'   corrections.
#' - [midnight_curves()] builds midnight-segmented curve objects from trace RDS
#'   files.
#'
#' @docType package
#' @name magnemite
#' @aliases magnemite-package
#' @keywords package
"_PACKAGE"