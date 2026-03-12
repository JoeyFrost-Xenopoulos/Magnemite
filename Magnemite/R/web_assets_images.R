# Website asset image processing functions.

#' Process Full-Size Magnetogram Images
#'
#' Reads source PNG files from year folders, rotates portrait images when needed,
#' and writes normalized full-size outputs.
#'
#' @param output_dir Optional output root override.
#' @param server_dir Optional server source directory override.
#' @param verbose Logical; print progress messages.
#'
#' @return Character vector of processed output file paths (invisibly).
#' @export
magnemite_process_fullsize_images <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  out_dir <- file.path(paths$magnetograms_dir, "fullsize")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  year_dirs <- magnemite_year_dirs(root_dir)
  processed <- character()

  for (dir in year_dirs) {
    year <- basename(dir)
    png_files <- list.files(dir, pattern = "\\.png$", full.names = FALSE, ignore.case = TRUE)
    png_files <- png_files[!grepl("-FailToProcess|-Plot", png_files, ignore.case = TRUE)]

    if (length(png_files) == 0) {
      if (isTRUE(verbose)) {
        message("No valid images found for year ", year)
      }
      next
    }

    year_output_dir <- file.path(out_dir, year)
    dir.create(year_output_dir, showWarnings = FALSE, recursive = TRUE)

    for (file in png_files) {
      input_path <- file.path(dir, file)
      img <- magick::image_read(input_path)

      info <- magick::image_info(img)
      if (info$height > info$width) {
        img <- magick::image_rotate(img, 90)
      }

      output_path <- file.path(year_output_dir, file)
      magick::image_write(img, output_path, format = "png")
      processed <- c(processed, output_path)

      if (isTRUE(verbose)) {
        message("Processed: ", output_path)
      }
    }
  }

  invisible(processed)
}

#' Process Thumbnail Magnetogram Images
#'
#' Creates one representative thumbnail image per year by resizing the first
#' valid PNG discovered in each year directory.
#'
#' @param output_dir Optional output root override.
#' @param server_dir Optional server source directory override.
#' @param verbose Logical; print progress messages.
#'
#' @return Character vector of processed thumbnail file paths (invisibly).
#' @export
magnemite_process_thumbnail_images <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  out_dir <- file.path(paths$magnetograms_dir, "thumbnails")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  year_dirs <- magnemite_year_dirs(root_dir)
  processed <- character()

  for (dir in year_dirs) {
    year <- basename(dir)
    png_files <- list.files(dir, pattern = "\\.png$", full.names = FALSE, ignore.case = TRUE)
    png_files <- png_files[!grepl("-FailToProcess|-Plot", png_files, ignore.case = TRUE)]

    if (length(png_files) == 0) {
      if (isTRUE(verbose)) {
        message("No valid images found for year ", year)
      }
      next
    }

    file <- png_files[1]
    input_path <- file.path(dir, file)

    year_output_dir <- file.path(out_dir, year)
    dir.create(year_output_dir, showWarnings = FALSE, recursive = TRUE)

    img <- magick::image_read(input_path)
    info <- magick::image_info(img)

    if (info$height > info$width) {
      img <- magick::image_rotate(img, 90)
    }

    resized <- magick::image_resize(img, "750x250!")

    output_path <- file.path(year_output_dir, file)
    magick::image_write(resized, output_path, format = "png")
    processed <- c(processed, output_path)

    if (isTRUE(verbose)) {
      message("Processed: ", output_path)
    }
  }

  invisible(processed)
}
