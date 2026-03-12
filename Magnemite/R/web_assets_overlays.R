# Website overlay and trace-export functions.

magnemite_write_rds_overlays <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  fullsize_dir <- file.path(paths$magnetograms_dir, "fullsize")
  overlay_base_dir <- file.path(paths$magnetograms_dir, "rds_overlays")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  year_dirs <- magnemite_year_dirs(root_dir)
  created <- character()

  for (year_dir in year_dirs) {
    year <- basename(year_dir)
    rds_files <- list.files(year_dir, pattern = "\\.RDS$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
    rds_files <- rds_files[!grepl("FailToProcess", rds_files, ignore.case = TRUE)]

    for (rds_path in rds_files) {
      obj <- readRDS(rds_path)
      rds_basename <- basename(rds_path)
      png_name <- sub("\\.tif-Digitized\\.RDS$", ".tif.png", rds_basename, ignore.case = TRUE)
      image_path <- file.path(fullsize_dir, year, png_name)

      if (!file.exists(image_path)) {
        warning("Image not found for: ", rds_path)
        next
      }

      img <- magick::image_read(image_path)
      img_info <- magick::image_info(img)
      img_width <- img_info$width
      img_height <- img_info$height

      output_name <- sub("\\.RDS$", "-lines.png", rds_basename, ignore.case = TRUE)
      output_dir_year <- file.path(overlay_base_dir, year)
      dir.create(output_dir_year, recursive = TRUE, showWarnings = FALSE)
      output_path <- file.path(output_dir_year, output_name)

      grDevices::png(output_path, width = img_width, height = img_height, bg = "transparent")
      graphics::par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")
      graphics::plot(1, type = "n", xlim = c(0, img_width), ylim = c(0, img_height), xlab = "", ylab = "", axes = FALSE)

      if (!is.null(obj$TopTraceMatrix) && !is.null(obj$TopTraceStartEnds)) {
        x_top <- seq_len(length(obj$TopTraceMatrix)) + obj$TopTraceStartEnds$Start + 125 - 1
        graphics::lines(x_top, y = obj$TopTraceMatrix + 96, col = "red", lwd = 10)
      }

      if (!is.null(obj$BottomTraceMatrix) && !is.null(obj$BottomTraceStartEnds)) {
        x_bot <- seq_len(length(obj$BottomTraceMatrix)) + obj$BottomTraceStartEnds$Start + 125 - 1
        graphics::lines(x_bot, y = obj$BottomTraceMatrix + 96, col = "green", lwd = 10)
      }

      grDevices::dev.off()
      created <- c(created, output_path)

      if (isTRUE(verbose)) {
        message("Overlay created: ", output_path)
      }
    }
  }

  invisible(created)
}

magnemite_copy_rds_assets <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  rds_target_base_dir <- file.path(paths$magnetograms_dir, "rds")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  year_dirs <- magnemite_year_dirs(root_dir)
  copied <- character()
  dir.create(rds_target_base_dir, recursive = TRUE, showWarnings = FALSE)

  for (year_dir in year_dirs) {
    year <- basename(year_dir)
    rds_files <- list.files(year_dir, pattern = "\\.RDS$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
    rds_files <- rds_files[!grepl("FailToProcess", rds_files, ignore.case = TRUE)]

    for (rds_path in rds_files) {
      target_year_dir <- file.path(rds_target_base_dir, year)
      dir.create(target_year_dir, recursive = TRUE, showWarnings = FALSE)
      target_path <- file.path(target_year_dir, basename(rds_path))
      file.copy(rds_path, target_path, overwrite = TRUE)
      copied <- c(copied, target_path)

      if (isTRUE(verbose)) {
        message("Copied RDS file: ", target_path)
      }
    }
  }

  invisible(copied)
}

magnemite_write_trace_csv_assets <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  paths <- magnemite_paths(output_dir = output_dir, server_dir = server_dir)
  root_dir <- paths$server_dir
  csv_base_dir <- file.path(paths$magnetograms_dir, "csv")

  if (!dir.exists(root_dir)) {
    stop("Server directory not found: ", root_dir)
  }

  year_dirs <- magnemite_year_dirs(root_dir)
  created <- character()
  dir.create(csv_base_dir, recursive = TRUE, showWarnings = FALSE)

  for (year_dir in year_dirs) {
    year <- basename(year_dir)
    rds_files <- list.files(year_dir, pattern = "\\.RDS$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
    rds_files <- rds_files[!grepl("FailToProcess", rds_files, ignore.case = TRUE)]

    for (rds_path in rds_files) {
      rds <- tryCatch(readRDS(rds_path), error = function(e) NULL)
      if (is.null(rds)) {
        next
      }

      if (!is.null(rds$TopTraceMatrix) && !is.null(rds$TopTraceStartEnds)) {
        x_top <- seq(
          from = rds$TopTraceStartEnds$Start + 125,
          to = rds$TopTraceStartEnds$End + 125,
          length.out = length(rds$TopTraceMatrix)
        )
        y_top <- rds$TopTraceMatrix + 96
      } else {
        x_top <- y_top <- NULL
      }

      if (!is.null(rds$BottomTraceMatrix) && !is.null(rds$BottomTraceStartEnds)) {
        x_bot <- seq(
          from = rds$BottomTraceStartEnds$Start + 125,
          to = rds$BottomTraceStartEnds$End + 125,
          length.out = length(rds$BottomTraceMatrix)
        )
        y_bot <- rds$BottomTraceMatrix + 96
      } else {
        x_bot <- y_bot <- NULL
      }

      n_max <- max(length(x_top), length(x_bot), 0)
      out_df <- data.frame(
        TopX = c(x_top, rep(NA, n_max - length(x_top))),
        TopY = c(y_top, rep(NA, n_max - length(y_top))),
        BottomX = c(x_bot, rep(NA, n_max - length(x_bot))),
        BottomY = c(y_bot, rep(NA, n_max - length(y_bot)))
      )

      if (nrow(out_df) > 0) {
        csv_year_dir <- file.path(csv_base_dir, year)
        dir.create(csv_year_dir, recursive = TRUE, showWarnings = FALSE)

        csv_name <- paste0(tools::file_path_sans_ext(basename(rds_path)), ".csv")
        csv_path <- file.path(csv_year_dir, csv_name)
        utils::write.csv(out_df, csv_path, row.names = FALSE)
        created <- c(created, csv_path)

        if (isTRUE(verbose)) {
          message("Created CSV: ", csv_path)
        }
      }
    }
  }

  invisible(created)
}

magnemite_build_web_trace_assets <- function(output_dir = NULL, server_dir = NULL, verbose = TRUE) {
  overlays <- magnemite_write_rds_overlays(output_dir = output_dir, server_dir = server_dir, verbose = verbose)
  copied <- magnemite_copy_rds_assets(output_dir = output_dir, server_dir = server_dir, verbose = verbose)
  csvs <- magnemite_write_trace_csv_assets(output_dir = output_dir, server_dir = server_dir, verbose = verbose)

  invisible(list(overlays = overlays, copied_rds = copied, csvs = csvs))
}
