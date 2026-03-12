# Shared path helpers for timing tick workflows.

#' Resolve Timing Tick Paths
#'
#' Resolves source, timing tick, and output directories used by timing tick
#' workflows, with environment-variable and default fallbacks.
#'
#' @param server_dir Optional server source directory override.
#' @param timing_ticks_dir Optional timing tick RDS directory override.
#' @param output_dir Optional output directory override.
#'
#' @return A list containing normalized timing tick path settings.
#' @export
magnemite_timing_ticks_paths <- function(server_dir = NULL, timing_ticks_dir = NULL, output_dir = NULL) {
  resolved_server_dir <- if (!is.null(server_dir) && nzchar(server_dir)) {
    server_dir
  } else {
    Sys.getenv("MAGNEMITE_SERVER_DIR", unset = Sys.getenv("NOSEPASS_SERVER_DIR", unset = "D:/SERVER/1902"))
  }

  resolved_server_dir <- normalizePath(resolved_server_dir, winslash = "/", mustWork = FALSE)

  resolved_timing_ticks_dir <- if (!is.null(timing_ticks_dir) && nzchar(timing_ticks_dir)) {
    timing_ticks_dir
  } else {
    Sys.getenv("MAGNEMITE_TIMING_TICKS_DIR", unset = file.path(resolved_server_dir, "TimingTicks"))
  }

  resolved_output_dir <- if (!is.null(output_dir) && nzchar(output_dir)) {
    output_dir
  } else {
    file.path(magnemite_default_output_root(), "data", "timing_ticks")
  }

  list(
    server_dir = resolved_server_dir,
    timing_ticks_dir = normalizePath(resolved_timing_ticks_dir, winslash = "/", mustWork = FALSE),
    output_dir = normalizePath(resolved_output_dir, winslash = "/", mustWork = FALSE)
  )
}

#' List TIF Files
#'
#' Lists `.tif` files from a server directory.
#'
#' @param server_dir Directory containing source image files.
#'
#' @return Character vector of `.tif` file paths.
#' @export
magnemite_list_tif_files <- function(server_dir) {
  list.files(server_dir, pattern = "\\.tif$", full.names = TRUE)
}

#' Find Matching Digitized RDS
#'
#' Finds a digitized or fail-to-process RDS file that corresponds to a given
#' `.tif` image path.
#'
#' @param tif_path Path to a `.tif` source image.
#' @param server_dir Server directory to search.
#'
#' @return Normalized RDS path, or `NA_character_` when not found.
#' @export
magnemite_find_digitized_rds <- function(tif_path, server_dir) {
  base_name <- tools::file_path_sans_ext(basename(tif_path))
  candidate_paths <- c(
    file.path(server_dir, paste0(base_name, ".tif-Digitized.rds")),
    file.path(server_dir, paste0(base_name, ".tif-FailToProcess.rds")),
    file.path(dirname(tif_path), paste0(base_name, ".tif-Digitized.rds")),
    file.path(dirname(tif_path), paste0(base_name, ".tif-FailToProcess.rds"))
  )

  existing_path <- candidate_paths[file.exists(candidate_paths)][1]
  if (is.na(existing_path) || !nzchar(existing_path)) {
    return(NA_character_)
  }

  normalizePath(existing_path, winslash = "/", mustWork = FALSE)
}

#' Build Timing Tick RDS Path
#'
#' Builds the expected timing tick `.rds` output path for a source image.
#'
#' @param tif_path Path to a `.tif` source image.
#' @param timing_ticks_dir Directory where timing tick RDS files are stored.
#'
#' @return Normalized timing tick RDS path.
#' @export
magnemite_timing_tick_rds_path <- function(tif_path, timing_ticks_dir) {
  base_name <- tools::file_path_sans_ext(basename(tif_path))
  normalizePath(file.path(timing_ticks_dir, paste0(base_name, ".rds")), winslash = "/", mustWork = FALSE)
}
