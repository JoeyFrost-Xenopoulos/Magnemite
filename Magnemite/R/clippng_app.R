# Clippng Shiny app package integration.

magnemite_default_output_root <- function() {
  normalizePath(
    Sys.getenv("MAGNEMITE_OUTPUT_DIR", unset = Sys.getenv("NOSEPASS_OUTPUT_DIR", unset = "D:/Magnemite_Out")),
    mustWork = FALSE
  )
}

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

magnemite_default_clippng_project_dir <- function() {
  bundled_db <- magnemite_find_package_file("data", "magnet.db")
  if (!is.na(bundled_db)) {
    return(dirname(dirname(bundled_db)))
  }

  normalizePath("D:/Nosepass/clippng", mustWork = FALSE)
}

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

    shiny::observeEvent(input$retry, {
      clipping_step(0)
      trace_coords$top_start <- NULL
      trace_coords$top_end <- NULL
      trace_coords$bottom_start <- NULL
      trace_coords$bottom_end <- NULL
      clipped_top_trace(NULL)
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
        clipping_step(0)
        trace_coords$top_start <- NULL
        trace_coords$top_end <- NULL
        trace_coords$bottom_start <- NULL
        trace_coords$bottom_end <- NULL
        clipped_top_trace(NULL)
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

run_magnemite_clippng_app <- function(project_dir = NULL, db_path = NULL, output_dir = NULL) {
  app <- magnemite_clippng_app(project_dir = project_dir, db_path = db_path, output_dir = output_dir)
  shiny::runApp(app)
}
