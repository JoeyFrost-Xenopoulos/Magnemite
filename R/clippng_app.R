# Clippng Shiny app package integration.

#' Resolve Default Output Root
#'
#' Returns the normalized package-wide output root directory using environment
#' fallback rules.
#'
#' @return Normalized output root path.
#' @noRd
magnemite_default_output_root <- function() {
  normalizePath(
    Sys.getenv("MAGNEMITE_OUTPUT_DIR", unset = Sys.getenv("NOSEPASS_OUTPUT_DIR", unset = "D:/Magnemite_Out")),
    mustWork = FALSE
  )
}

#' Find a Bundled Package File
#'
#' Searches installed and development package locations for a relative file path.
#'
#' @param ... Path components relative to package root.
#'
#' @return Normalized file path, or `NA_character_` when not found.
#' @noRd
magnemite_find_package_file <- function(...) {
  relative_path <- file.path(...)
  candidate_paths <- character()

  installed_root <- system.file(package = "Magnemite")
  if (nzchar(installed_root)) {
    candidate_paths <- c(candidate_paths, file.path(installed_root, relative_path))
  }

  working_dir <- normalizePath(getwd(), mustWork = FALSE)
  candidate_paths <- c(
    candidate_paths,
    file.path(working_dir, relative_path),
    file.path(working_dir, "Magnemite", relative_path),
    file.path(dirname(working_dir), "Magnemite", relative_path)
  )

  existing_path <- candidate_paths[file.exists(candidate_paths)][1]
  if (is.na(existing_path) || !nzchar(existing_path)) {
    return(NA_character_)
  }

  normalizePath(existing_path, mustWork = FALSE)
}

#' Resolve Default Clippng Project Directory
#'
#' Uses bundled database location when available, otherwise returns a fallback
#' project directory.
#'
#' @return Normalized project directory path.
#' @noRd
magnemite_default_clippng_project_dir <- function() {
  bundled_db <- magnemite_find_package_file("data", "magnet.db")
  if (!is.na(bundled_db)) {
    return(dirname(dirname(bundled_db)))
  }

  normalizePath("D:/Nosepass/clippng", mustWork = FALSE)
}

#' Resolve Default Clippng Database Path
#'
#' Uses bundled package database when available, otherwise derives path from the
#' project directory.
#'
#' @param project_dir Optional project directory used to build DB path.
#'
#' @return Normalized database file path.
#' @noRd
magnemite_default_clippng_db <- function(project_dir = NULL) {
  bundled_db <- magnemite_find_package_file("data", "magnet.db")
  if (!is.na(bundled_db)) {
    return(bundled_db)
  }

  if (is.null(project_dir) || !nzchar(project_dir)) {
    project_dir <- magnemite_default_clippng_project_dir()
  }

  normalizePath(file.path(project_dir, "data", "magnet.db"), mustWork = FALSE)
}

#' Resolve Clippng App Paths
#'
#' Resolves clipping app project, database, and output paths with explicit,
#' environment, and package-default fallbacks.
#'
#' @param project_dir Optional project directory override.
#' @param db_path Optional database path override.
#' @param output_dir Optional output directory override.
#'
#' @return A list with normalized clipping app path settings.
#' @noRd
magnemite_clippng_paths <- function(project_dir = NULL, db_path = NULL, output_dir = NULL) {
  resolved_project_dir <- if (!is.null(project_dir) && nzchar(project_dir)) {
    project_dir
  } else {
    Sys.getenv(
      "MAGNEMITE_CLIPPNG_PROJECT_DIR",
      unset = Sys.getenv("NOSEPASS_CLIPPNG_PROJECT_DIR", unset = magnemite_default_clippng_project_dir())
    )
  }

  resolved_project_dir <- normalizePath(resolved_project_dir, mustWork = FALSE)

  resolved_db_path <- if (!is.null(db_path) && nzchar(db_path)) {
    db_path
  } else {
    Sys.getenv(
      "MAGNEMITE_CLIPPNG_DB",
      unset = Sys.getenv("NOSEPASS_CLIPPNG_DB", unset = magnemite_default_clippng_db(resolved_project_dir))
    )
  }

  resolved_output_dir <- if (!is.null(output_dir) && nzchar(output_dir)) {
    output_dir
  } else {
    Sys.getenv(
      "MAGNEMITE_CLIPPNG_OUTPUT_DIR",
      unset = Sys.getenv(
        "NOSEPASS_CLIPPNG_OUTPUT_DIR",
        unset = file.path(magnemite_default_output_root(), "data", "clipped_traces")
      )
    )
  }

  list(
    project_dir = resolved_project_dir,
    db_path = normalizePath(resolved_db_path, mustWork = FALSE),
    output_dir = normalizePath(resolved_output_dir, mustWork = FALSE)
  )
}

#' Build Clippng Shiny App
#'
#' Constructs the clipping Shiny app used to clip top and bottom trace segments
#' and export clipped CSV files.
#'
#' @param project_dir Optional project directory override.
#' @param db_path Optional database path override.
#' @param output_dir Optional output directory override.
#'
#' @return A Shiny app object.
#' @noRd
magnemite_clippng_app <- function(project_dir = NULL, db_path = NULL, output_dir = NULL) {
  app_paths <- magnemite_clippng_paths(project_dir = project_dir, db_path = db_path, output_dir = output_dir)

  dir.create(app_paths$output_dir, recursive = TRUE, showWarnings = FALSE)

  if (!file.exists(app_paths$db_path)) {
    stop("Database not found at: ", app_paths$db_path)
  }

  ui <- shiny::fluidPage(
    shiny::conditionalPanel(
      condition = "!input.clippng",
      shiny::column(12, shiny::selectInput("select_year_view", "Year", choices = NULL)),
      shiny::column(12, shiny::selectInput("tiff_file", "Select your TIFF file", choices = NULL)),
      shiny::column(12, shiny::textInput("custom_output_dir", "Output directory (optional)", placeholder = "Leave blank to use default")),
      shiny::column(12, shiny::checkboxInput("clippng", "Start Clipping"))
    ),
    shiny::conditionalPanel(
      condition = "input.clippng == true",
      shiny::column(12, shiny::h4(shiny::textOutput("clipping_instructions"))),
      shiny::column(12, shiny::actionButton("confirm", "Go Back to Home")),
      shiny::column(12, shiny::actionButton("retry", "Retry Tracing")),
      shiny::column(12, shiny::actionButton("next_image", "Next Image"))
    ),
    shiny::conditionalPanel(
      condition = "output.showSaveButton == true",
      shiny::actionButton("save_csv", "Save Clipped Traces as CSV")
    ),
    shiny::mainPanel(
      shiny::plotOutput("image", click = "plot_click", width = 1800, height = 1000)
    )
  )

  server <- function(input, output, session) {
    conn <- DBI::dbConnect(RSQLite::SQLite(), app_paths$db_path)

    clipping_step <- shiny::reactiveVal(0)
    clipped_top_trace <- shiny::reactiveVal(NULL)
    trace_coords <- shiny::reactiveValues(top_start = NULL, top_end = NULL, bottom_start = NULL, bottom_end = NULL)
    current_state <- shiny::reactiveValues(RDS = NULL, top_trace_x = NULL, bottom_trace_x = NULL)

    resolved_output_dir <- shiny::reactive({
      if (nzchar(input$custom_output_dir)) {
        custom_dir <- normalizePath(input$custom_output_dir, mustWork = FALSE)
        dir.create(custom_dir, recursive = TRUE, showWarnings = FALSE)
        custom_dir
      } else {
        app_paths$output_dir
      }
    })

    reset_clipping_state <- function(reset_toggle = FALSE) {
      clipping_step(0)
      trace_coords$top_start <- NULL
      trace_coords$top_end <- NULL
      trace_coords$bottom_start <- NULL
      trace_coords$bottom_end <- NULL
      clipped_top_trace(NULL)

      if (isTRUE(reset_toggle)) {
        shiny::updateCheckboxInput(session, "clippng", value = FALSE)
      }
    }

    get_photos_for_year <- function(year) {
      if (is.null(year) || !nzchar(year)) {
        return(character(0))
      }
      photos <- DBI::dbGetQuery(conn, "SELECT FileName FROM file_list WHERE year = ?", params = list(year))$FileName
      paste0(photos, ".png")
    }

    shiny::observe({
      years <- DBI::dbGetQuery(conn, "SELECT DISTINCT year FROM file_list ORDER BY year")$year
      shiny::updateSelectInput(session, "select_year_view", choices = years, selected = if (length(years) > 0) years[1] else character(0))
    })

    shiny::observeEvent(input$select_year_view, {
      photos <- get_photos_for_year(input$select_year_view)
      shiny::updateSelectInput(session, "tiff_file", choices = photos, selected = if (length(photos) > 0) photos[1] else character(0))
    })

    output$clipping_instructions <- shiny::renderText({
      if (clipping_step() == 0) {
        "Click to mark the Top Trace Start position"
      } else if (clipping_step() == 1) {
        "Click to mark the Top Trace End position"
      } else if (clipping_step() == 2) {
        "Click to mark the Bottom Trace Start position"
      } else if (clipping_step() == 3) {
        "Click to mark the Bottom Trace End position"
      } else {
        "Clipping complete. Save CSV or move to next image."
      }
    })

    output$image <- shiny::renderPlot({
      shiny::req(input$tiff_file, input$select_year_view)

      base_name <- sub("\\.png$", "", input$tiff_file)
      photo_row <- DBI::dbGetQuery(
        conn,
        "SELECT Path FROM file_list WHERE FileName = ? AND year = ?",
        params = list(base_name, input$select_year_view)
      )

      if (nrow(photo_row) == 0) {
        return(NULL)
      }

      photo_path <- paste0(photo_row$Path[1], ".png")
      if (!file.exists(photo_path)) {
        return(NULL)
      }

      mag_image <- magick::image_read(photo_path)
      if (magick::image_info(mag_image)$width < magick::image_info(mag_image)$height) {
        mag_image <- magick::image_rotate(mag_image, 90)
      }

      rds_path_digitized <- file.path(dirname(photo_path), paste0(base_name, "-Digitized.RDS"))
      rds_path_failed <- file.path(dirname(photo_path), paste0(base_name, "-FailToProcess-Data.RDS"))

      if (file.exists(rds_path_digitized)) {
        current_state$RDS <- readRDS(rds_path_digitized)
      } else if (file.exists(rds_path_failed)) {
        current_state$RDS <- readRDS(rds_path_failed)
      } else {
        return(NULL)
      }

      graphics::plot(mag_image, asp = 1425 / 1204)

      current_state$top_trace_x <- seq(from = current_state$RDS$TopTraceStartEnds$Start + 125, to = current_state$RDS$TopTraceStartEnds$End + 125)
      current_state$bottom_trace_x <- seq(from = current_state$RDS$BottomTraceStartEnds$Start + 125, to = current_state$RDS$BottomTraceStartEnds$End + 125)

      top_trace_x <- current_state$top_trace_x
      bottom_trace_x <- current_state$bottom_trace_x

      if (clipping_step() == 0) {
        graphics::lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
        graphics::lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
      } else if (clipping_step() == 1 && !is.null(trace_coords$top_start)) {
        graphics::lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
        graphics::abline(v = trace_coords$top_start, col = "red", lwd = 2)
        graphics::lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
      } else if (clipping_step() == 2 && !is.null(trace_coords$top_start) && !is.null(trace_coords$top_end)) {
        filtered_x <- top_trace_x[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end]
        filtered_y <- current_state$RDS$TopTraceMatrix[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end] + 96
        clipped_top_trace(list(x = filtered_x, y = filtered_y))
        graphics::lines(filtered_x, filtered_y, col = "red", lwd = 2)
        graphics::lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
      }

      if (clipping_step() == 3) {
        if (!is.null(clipped_top_trace())) {
          graphics::lines(clipped_top_trace()$x, clipped_top_trace()$y, col = "red", lwd = 2)
        } else {
          graphics::lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
        }
        graphics::lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
        graphics::abline(v = trace_coords$bottom_start, col = "red", lwd = 2)
      } else if (clipping_step() == 4 && !is.null(trace_coords$bottom_start)) {
        filtered_bottom_x <- bottom_trace_x[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end]
        filtered_bottom_y <- current_state$RDS$BottomTraceMatrix[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end] + 96
        if (!is.null(clipped_top_trace())) {
          graphics::lines(clipped_top_trace()$x, clipped_top_trace()$y, col = "red", lwd = 2)
        }
        graphics::lines(filtered_bottom_x, filtered_bottom_y, col = "green", lwd = 1.5)
      }
    })

    shiny::observeEvent(input$plot_click, {
      if (clipping_step() == 0) {
        trace_coords$top_start <- input$plot_click$x
        clipping_step(1)
      } else if (clipping_step() == 1) {
        trace_coords$top_end <- input$plot_click$x
        clipping_step(2)
      } else if (clipping_step() == 2) {
        trace_coords$bottom_start <- input$plot_click$x
        clipping_step(3)
      } else if (clipping_step() == 3) {
        trace_coords$bottom_end <- input$plot_click$x
        clipping_step(4)
      }
    })

    shiny::observeEvent(input$confirm, {
      reset_clipping_state(reset_toggle = TRUE)
    })

    shiny::observeEvent(input$retry, {
      reset_clipping_state(reset_toggle = FALSE)
    })

    output$showSaveButton <- shiny::reactive({
      clipping_step() == 4
    })
    shiny::outputOptions(output, "showSaveButton", suspendWhenHidden = FALSE)

    move_to_next <- function() {
      photos <- get_photos_for_year(input$select_year_view)
      current_index <- match(input$tiff_file, photos)

      if (!is.na(current_index) && current_index < length(photos)) {
        shiny::updateSelectInput(session, "tiff_file", selected = photos[current_index + 1])
        reset_clipping_state(reset_toggle = FALSE)
        return(TRUE)
      }

      FALSE
    }

    shiny::observeEvent(input$save_csv, {
      shiny::req(current_state$RDS, current_state$top_trace_x, current_state$bottom_trace_x)

      if (is.null(clipped_top_trace()) || is.null(trace_coords$bottom_start) || is.null(trace_coords$bottom_end)) {
        shiny::showNotification("Unable to save. Make sure both traces are clipped.", type = "error")
        return()
      }

      top_trace_x <- current_state$top_trace_x
      bottom_trace_x <- current_state$bottom_trace_x

      clipped_top_x <- top_trace_x[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end]
      clipped_top_y <- current_state$RDS$TopTraceMatrix[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end] + 96

      clipped_bottom_x <- bottom_trace_x[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end]
      clipped_bottom_y <- current_state$RDS$BottomTraceMatrix[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end] + 96

      max_length <- max(length(clipped_top_x), length(clipped_bottom_x), length(clipped_top_y), length(clipped_bottom_y))

      clipped_top_x <- c(clipped_top_x, rep(NA, max_length - length(clipped_top_x)))
      clipped_top_y <- c(clipped_top_y, rep(NA, max_length - length(clipped_top_y)))
      clipped_bottom_x <- c(clipped_bottom_x, rep(NA, max_length - length(clipped_bottom_x)))
      clipped_bottom_y <- c(clipped_bottom_y, rep(NA, max_length - length(clipped_bottom_y)))

      combined_data <- data.frame(
        top_x = clipped_top_x,
        top_y = clipped_top_y,
        bottom_x = clipped_bottom_x,
        bottom_y = clipped_bottom_y
      )

      photo_name <- sub("\\.png$", "", input$tiff_file)
      csv_file_name <- paste0(photo_name, "_clipped_traces.csv")
      csv_file_path <- file.path(resolved_output_dir(), csv_file_name)
      utils::write.csv(combined_data, file = csv_file_path, row.names = FALSE)

      shiny::showNotification(paste0("Clipped traces saved as ", csv_file_path), type = "message")

      if (!move_to_next()) {
        shiny::showNotification("All images processed.", type = "message")
      }
    })

    shiny::observeEvent(input$next_image, {
      if (move_to_next()) {
        shiny::showNotification("Moved to next image.", type = "message")
      } else {
        shiny::showNotification("No more images available for this year.", type = "warning")
      }
    })

    session$onSessionEnded(function() {
      DBI::dbDisconnect(conn)
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}

#' Apply Clipped CSV to Digitized RDS
#'
#' Reads a clipped traces CSV produced by the clippng app and writes the
#' corrected trace vectors and start/end coordinates back into the corresponding
#' digitized RDS file.
#'
#' The clippng app stores coordinates with a +96 y-offset and +125 x-offset.
#' This function reverses those offsets before writing back to the RDS and
#' removes padded `NA` pairs from each trace.
#'
#' @param csv_path Path to the `_clipped_traces.csv` file from the clippng app.
#' @param rds_path Path to the digitized `.rds` file to update.
#'
#' @return The updated RDS object (invisibly). The file at `rds_path` is
#'   overwritten in place.
#' @export
apply_clipped_csv <- function(csv_path, rds_path) {
  if (!file.exists(csv_path)) {
    stop("CSV file not found: ", csv_path)
  }
  if (!file.exists(rds_path)) {
    stop("RDS file not found: ", rds_path)
  }

  clips <- utils::read.csv(csv_path)
  required_cols <- c("top_x", "top_y", "bottom_x", "bottom_y")
  missing_cols <- setdiff(required_cols, names(clips))
  if (length(missing_cols) > 0) {
    stop("CSV is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  rds <- readRDS(rds_path)

  extract_trace <- function(x, y) {
    keep <- !is.na(x) & !is.na(y)
    list(
      x = as.numeric(x[keep]) - 125,
      y = as.numeric(y[keep]) - 96
    )
  }

  top <- extract_trace(clips$top_x, clips$top_y)
  bot <- extract_trace(clips$bottom_x, clips$bottom_y)

  if (length(top$x) == 0 || length(bot$x) == 0) {
    stop("CSV must contain at least one non-NA point for both top and bottom traces.")
  }

  rds$TopTraceMatrix <- top$y
  rds$TopTraceStartEnds <- list(
    Start = unname(top$x[1]),
    End = unname(top$x[length(top$x)])
  )
  rds$BottomTraceMatrix <- bot$y
  rds$BottomTraceStartEnds <- list(
    Start = unname(bot$x[1]),
    End = unname(bot$x[length(bot$x)])
  )

  saveRDS(rds, rds_path)
  invisible(rds)
}

#' Batch Apply Clipped CSVs to Digitized RDS Files
#'
#' Scans a directory of `_clipped_traces.csv` files and applies each one to its
#' matching digitized RDS file using `apply_clipped_csv()`. The lookup is
#' recursive under `server_dir` and supports both `*.tif-Digitized.rds` and
#' `*.tif-FailToProcess.rds` / `*.tif-FailToProcess-Data.rds` naming patterns.
#'
#' @param clipped_csv_dir Directory containing `_clipped_traces.csv` files.
#'   Defaults to `D:/Magnemite_Out/data/clipped_traces`.
#' @param server_dir Server root directory containing digitized RDS files.
#'   Defaults to `MAGNEMITE_SERVER_DIR` env var or `D:/SERVER`.
#'
#' @return Character vector of updated RDS paths (invisibly).
#' @export
apply_clipped_csv_batch <- function(clipped_csv_dir = NULL, server_dir = NULL) {
  if (is.null(clipped_csv_dir) || !nzchar(clipped_csv_dir)) {
    clipped_csv_dir <- file.path(magnemite_default_output_root(), "data", "clipped_traces")
  }
  if (is.null(server_dir) || !nzchar(server_dir)) {
    server_dir <- Sys.getenv("MAGNEMITE_SERVER_DIR", unset = Sys.getenv("NOSEPASS_SERVER_DIR", unset = "D:/SERVER"))
  }

  csv_files <- list.files(clipped_csv_dir, pattern = "_clipped_traces\\.csv$", full.names = TRUE, recursive = TRUE)
  rds_files <- list.files(
    server_dir,
    pattern = "\\.tif-(Digitized|FailToProcess(-Data)?)\\.rds$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  if (length(csv_files) == 0) {
    message("No clipped trace CSV files found in: ", clipped_csv_dir)
    return(invisible(character()))
  }
  if (length(rds_files) == 0) {
    warning("No candidate digitized/fail RDS files found under: ", server_dir)
    return(invisible(character()))
  }

  updated <- character()

  rds_key <- function(path) {
    sub(
      "\\.tif-(Digitized|FailToProcess(-Data)?)\\.rds$",
      "",
      basename(path),
      ignore.case = TRUE
    )
  }

  choose_best_match <- function(paths) {
    digitized <- paths[grepl("-Digitized\\.rds$", paths, ignore.case = TRUE)]
    if (length(digitized) > 0) {
      return(digitized[1])
    }
    paths[1]
  }

  rds_keys <- vapply(rds_files, rds_key, FUN.VALUE = character(1))

  for (csv_path in csv_files) {
    base <- sub("_clipped_traces\\.csv$", "", basename(csv_path))
    matches <- rds_files[rds_keys == base]

    if (length(matches) == 0) {
      warning("No matching RDS for: ", basename(csv_path), " under ", server_dir)
      next
    }

    rds_path <- choose_best_match(matches)

    tryCatch({
      apply_clipped_csv(csv_path, rds_path)
      updated <- c(updated, rds_path)
      message("Updated: ", basename(rds_path), " from ", basename(csv_path))
    }, error = function(e) {
      warning("Failed to apply ", basename(csv_path), ": ", e$message)
    })
  }

  invisible(updated)
}

#' Run Clippng Shiny App
#'
#' Launches the clipping app.
#'
#' @param project_dir Optional project directory override.
#' @param db_path Optional database path override.
#' @param output_dir Optional output directory override.
#'
#' @return The result of `shiny::runApp()`.
#' @export
clippng_app <- function(project_dir = NULL, db_path = NULL, output_dir = NULL) {
  app <- magnemite_clippng_app(project_dir = project_dir, db_path = db_path, output_dir = output_dir)
  shiny::runApp(app)
}
