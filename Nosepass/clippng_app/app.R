library(shiny)
library(magick)
library(RSQLite)
library(DBI)

get_project_dir <- function() {
  from_env <- Sys.getenv("NOSEPASS_CLIPPNG_PROJECT_DIR", unset = "")
  if (nzchar(from_env)) {
    return(normalizePath(from_env, mustWork = FALSE))
  }
  "D:/Nosepass/clippng"
}

get_default_output_dir <- function() {
  from_env <- Sys.getenv("NOSEPASS_CLIPPNG_OUTPUT_DIR", unset = "")
  if (nzchar(from_env)) {
    return(normalizePath(from_env, mustWork = FALSE))
  }
  project_dir <- get_project_dir()
  file.path(project_dir, "clipped_traces")
}

project_dir <- get_project_dir()
db_path <- Sys.getenv("NOSEPASS_CLIPPNG_DB", unset = file.path(project_dir, "data", "magnet.db"))
default_output_dir <- get_default_output_dir()

dir.create(default_output_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(db_path)) {
  stop("Database not found at: ", db_path)
}

ui <- fluidPage(
  conditionalPanel(
    condition = "!input.clippng",
    column(12, selectInput("select_year_view", "Year", choices = NULL)),
    column(12, selectInput("tiff_file", "Select your TIFF file", choices = NULL)),
    column(12, textInput("custom_output_dir", "Output directory (optional)", placeholder = "Leave blank to use default")),
    column(12, checkboxInput("clippng", "Start Clipping"))
  ),
  conditionalPanel(
    condition = "input.clippng == true",
    column(12, h4(textOutput("clipping_instructions"))),
    column(12, actionButton("confirm", "Go Back to Home")),
    column(12, actionButton("retry", "Retry Tracing")),
    column(12, actionButton("next_image", "Next Image"))
  ),
  conditionalPanel(
    condition = "output.showSaveButton == true",
    actionButton("save_csv", "Save Clipped Traces as CSV")
  ),
  mainPanel(
    plotOutput("image", click = "plot_click", width = 1800, height = 1000)
  )
)

server <- function(input, output, session) {
  conn <- dbConnect(RSQLite::SQLite(), db_path)

  clipping_step <- reactiveVal(0)
  clipped_top_trace <- reactiveVal(NULL)
  trace_coords <- reactiveValues(top_start = NULL, top_end = NULL, bottom_start = NULL, bottom_end = NULL)
  current_state <- reactiveValues(RDS = NULL, top_trace_x = NULL, bottom_trace_x = NULL)

  output_dir <- reactive({
    if (nzchar(input$custom_output_dir)) {
      custom_dir <- normalizePath(input$custom_output_dir, mustWork = FALSE)
      dir.create(custom_dir, recursive = TRUE, showWarnings = FALSE)
      custom_dir
    } else {
      default_output_dir
    }
  })

  get_photos_for_year <- function(year) {
    if (is.null(year) || !nzchar(year)) {
      return(character(0))
    }
    photos <- dbGetQuery(conn, "SELECT FileName FROM file_list WHERE year = ?", params = list(year))$FileName
    paste0(photos, ".png")
  }

  observe({
    years <- dbGetQuery(conn, "SELECT DISTINCT year FROM file_list ORDER BY year")$year
    updateSelectInput(session, "select_year_view", choices = years, selected = if (length(years) > 0) years[1] else character(0))
  })

  observeEvent(input$select_year_view, {
    photos <- get_photos_for_year(input$select_year_view)
    updateSelectInput(session, "tiff_file", choices = photos, selected = if (length(photos) > 0) photos[1] else character(0))
  })

  output$clipping_instructions <- renderText({
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

  output$image <- renderPlot({
    req(input$tiff_file, input$select_year_view)

    base_name <- sub("\\.png$", "", input$tiff_file)
    photo_row <- dbGetQuery(
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

    magImage <- image_read(photo_path)
    if (image_info(magImage)$width < image_info(magImage)$height) {
      magImage <- image_rotate(magImage, 90)
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

    plot(magImage, asp = 1425 / 1204)

    current_state$top_trace_x <- seq(from = current_state$RDS$TopTraceStartEnds$Start + 125, to = current_state$RDS$TopTraceStartEnds$End + 125)
    current_state$bottom_trace_x <- seq(from = current_state$RDS$BottomTraceStartEnds$Start + 125, to = current_state$RDS$BottomTraceStartEnds$End + 125)

    top_trace_x <- current_state$top_trace_x
    bottom_trace_x <- current_state$bottom_trace_x

    if (clipping_step() == 0) {
      lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
      lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
    } else if (clipping_step() == 1 && !is.null(trace_coords$top_start)) {
      lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
      abline(v = trace_coords$top_start, col = "red", lwd = 2)
      lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
    } else if (clipping_step() == 2 && !is.null(trace_coords$top_start) && !is.null(trace_coords$top_end)) {
      filtered_x <- top_trace_x[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end]
      filtered_y <- current_state$RDS$TopTraceMatrix[top_trace_x >= trace_coords$top_start & top_trace_x <= trace_coords$top_end] + 96
      clipped_top_trace(list(x = filtered_x, y = filtered_y))
      lines(filtered_x, filtered_y, col = "red", lwd = 2)
      lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
    }

    if (clipping_step() == 3) {
      if (!is.null(clipped_top_trace())) {
        lines(clipped_top_trace()$x, clipped_top_trace()$y, col = "red", lwd = 2)
      } else {
        lines(top_trace_x, current_state$RDS$TopTraceMatrix + 96, col = "blue", lwd = 2)
      }
      lines(bottom_trace_x, current_state$RDS$BottomTraceMatrix + 96, col = "green", lwd = 1.5)
      abline(v = trace_coords$bottom_start, col = "red", lwd = 2)
    } else if (clipping_step() == 4 && !is.null(trace_coords$bottom_start)) {
      filtered_bottom_x <- bottom_trace_x[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end]
      filtered_bottom_y <- current_state$RDS$BottomTraceMatrix[bottom_trace_x >= trace_coords$bottom_start & bottom_trace_x <= trace_coords$bottom_end] + 96
      if (!is.null(clipped_top_trace())) {
        lines(clipped_top_trace()$x, clipped_top_trace()$y, col = "red", lwd = 2)
      }
      lines(filtered_bottom_x, filtered_bottom_y, col = "green", lwd = 1.5)
    }
  })

  observeEvent(input$plot_click, {
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

  observeEvent(input$retry, {
    clipping_step(0)
    trace_coords$top_start <- NULL
    trace_coords$top_end <- NULL
    trace_coords$bottom_start <- NULL
    trace_coords$bottom_end <- NULL
    clipped_top_trace(NULL)
  })

  output$showSaveButton <- reactive({
    clipping_step() == 4
  })
  outputOptions(output, "showSaveButton", suspendWhenHidden = FALSE)

  move_to_next <- function() {
    photos <- get_photos_for_year(input$select_year_view)
    current_index <- match(input$tiff_file, photos)

    if (!is.na(current_index) && current_index < length(photos)) {
      updateSelectInput(session, "tiff_file", selected = photos[current_index + 1])
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

  observeEvent(input$save_csv, {
    req(current_state$RDS, current_state$top_trace_x, current_state$bottom_trace_x)

    if (is.null(clipped_top_trace()) || is.null(trace_coords$bottom_start) || is.null(trace_coords$bottom_end)) {
      showNotification("Unable to save. Make sure both traces are clipped.", type = "error")
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
    csv_file_path <- file.path(output_dir(), csv_file_name)
    write.csv(combined_data, file = csv_file_path, row.names = FALSE)

    showNotification(paste0("Clipped traces saved as ", csv_file_path), type = "message")

    if (!move_to_next()) {
      showNotification("All images processed.", type = "message")
    }
  })

  observeEvent(input$next_image, {
    if (move_to_next()) {
      showNotification("Moved to next image.", type = "message")
    } else {
      showNotification("No more images available for this year.", type = "warning")
    }
  })

  session$onSessionEnded(function() {
    dbDisconnect(conn)
  })
}

shinyApp(ui = ui, server = server)
