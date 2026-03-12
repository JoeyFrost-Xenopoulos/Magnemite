# Website asset index generation functions.

#' Write Master Image Indexes
#'
#' Writes per-year image indexes in source directories and a combined
#' `master-index.json` in the output index directory.
#'
#' @param output_dir Optional output root override.
#' @param server_dir Optional server source directory override.
#' @param verbose Logical; print progress messages.
#'
#' @return Path to the written master index file (invisibly).
#' @export
magnemite_write_master_index <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  master_index_path <- file.path(paths$indexes_dir, "master-index.json")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  dir.create(paths$indexes_dir, recursive = TRUE, showWarnings = FALSE)
  year_dirs <- magnemite_year_dirs(root_dir)
  master_index <- list()

  for (dir in year_dirs) {
    year <- basename(dir)
    png_files <- list.files(dir, pattern = "\\.png$", full.names = FALSE, ignore.case = TRUE)
    png_files <- png_files[!grepl("-FailToProcess|-Plot", png_files, ignore.case = TRUE)]

    index_path <- file.path(dir, "index.json")
    write(jsonlite::toJSON(png_files, pretty = TRUE, auto_unbox = TRUE), index_path)

    if (isTRUE(verbose)) {
      message("Wrote ", index_path, " with ", length(png_files), " images")
    }

    master_index[[year]] <- png_files
  }

  write(jsonlite::toJSON(master_index, pretty = TRUE, auto_unbox = TRUE), master_index_path)

  if (isTRUE(verbose)) {
    message("Master index saved to ", master_index_path, " with ", length(master_index), " years")
  }

  invisible(master_index_path)
}

#' Write RDS-to-Image Index
#'
#' Builds an index linking trace RDS files to corresponding image filenames,
#' then writes the JSON index to the output directory.
#'
#' @param output_dir Optional output root override.
#' @param server_dir Optional server source directory override.
#' @param verbose Logical; print progress messages.
#'
#' @return Path to the written RDS index file (invisibly).
#' @export
magnemite_write_rds_index <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  rds_index_path <- file.path(paths$indexes_dir, "rds-index.json")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  dir.create(paths$indexes_dir, recursive = TRUE, showWarnings = FALSE)
  year_dirs <- magnemite_year_dirs(root_dir)
  rds_index <- list()

  for (year_dir in year_dirs) {
    year <- basename(year_dir)
    rds_files <- list.files(year_dir, pattern = "\\.RDS$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
    rds_files <- rds_files[!grepl("FailToProcess", rds_files, ignore.case = TRUE)]

    for (file in rds_files) {
      rds_filename <- basename(file)
      image_base <- gsub("(-Digitized|-FailToProcess-Data)?\\.RDS$", "", rds_filename, ignore.case = TRUE)
      image_filename <- sub("\\.tif$", ".tif.png", image_base, ignore.case = TRUE)

      rds_index <- append(rds_index, list(list(
        rds_file = rds_filename,
        image_file = image_filename,
        year = year
      )))
    }
  }

  jsonlite::write_json(rds_index, rds_index_path, pretty = TRUE, auto_unbox = TRUE)

  if (isTRUE(verbose)) {
    message("Saved ", length(rds_index), " entries to ", rds_index_path)
  }

  invisible(rds_index_path)
}
