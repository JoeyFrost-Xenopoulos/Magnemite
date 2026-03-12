# Timing tick Shiny apps migrated from Nosepass.

magnemite_brushclust_app <- function(server_dir = NULL, timing_ticks_dir = NULL, output_dir = NULL) {
  app_paths <- magnemite_timing_ticks_paths(server_dir = server_dir, timing_ticks_dir = timing_ticks_dir, output_dir = output_dir)

  if (!dir.exists(app_paths$output_dir)) {
    dir.create(app_paths$output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  ui <- shiny::fluidPage(
    shiny::titlePanel("Cluster Processing App"),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::selectInput("tif_file", "Select .tif File", choices = NULL),
        shiny::actionButton("process", "Process Files"),
        shiny::actionButton("next_image", "Next Image"),
        shiny::actionButton("save_rds", "Save .rds"),
        shiny::actionButton("reset", "Reset Brushed Data")
      ),
      shiny::mainPanel(
        shiny::fluidRow(
          shiny::column(12, shiny::plotOutput("plot_cluster_3_bot", height = "800px", brush = shiny::brushOpts(id = "brush_plot_bot"))),
          shiny::column(6, shiny::actionButton("done_bot", "Done Bot", width = "400px"))
        ),
        shiny::fluidRow(
          shiny::column(12, shiny::plotOutput("plot_cluster_3_top", height = "800px", brush = shiny::brushOpts(id = "brush_plot_top"))),
          shiny::column(6, shiny::actionButton("done_top", "Done Top", width = "400px"))
        ),
        shiny::plotOutput("brushed_plot_bot", height = "400px"),
        shiny::plotOutput("brushed_plot_top", height = "400px")
      )
    )
  )

  server <- function(input, output, session) {
    results_bot <- shiny::reactiveVal(NULL)
    results_top <- shiny::reactiveVal(NULL)
    min_values_bot <- shiny::reactiveVal(NULL)
    min_values_top <- shiny::reactiveVal(NULL)
    current_index <- shiny::reactiveVal(1)
    tif_files <- shiny::reactive({
      magnemite_list_tif_files(app_paths$server_dir)
    })

    done_pressed_bot <- shiny::reactiveVal(FALSE)
    done_pressed_top <- shiny::reactiveVal(FALSE)
    combined_brushed_data_bot <- shiny::reactiveVal(data.frame(X = numeric(), Y = numeric()))
    combined_brushed_data_top <- shiny::reactiveVal(data.frame(X = numeric(), Y = numeric()))

    shiny::observe({
      files <- tif_files()
      shiny::updateSelectInput(session, "tif_file", choices = files, selected = if (length(files) > 0) files[1] else character(0))
    })

    shiny::observeEvent(input$next_image, {
      files <- tif_files()
      if (length(files) == 0) {
        return()
      }

      new_index <- current_index() + 1
      if (new_index > length(files)) {
        new_index <- 1
      }

      current_index(new_index)
      min_values_bot(NULL)
      min_values_top(NULL)
      shiny::updateSelectInput(session, "tif_file", selected = files[new_index])
    })

    shiny::observeEvent(input$tif_file, {
      files <- tif_files()
      new_index <- match(input$tif_file, files)
      if (!is.na(new_index)) {
        current_index(new_index)
      }
      if (length(files) > 0) {
        shiny::updateActionButton(session, "process", label = "Process Files")
        shiny::updateActionButton(session, "reset", label = "Reset Brushed Data")
      }
    })

    shiny::observeEvent(input$process, {
      shiny::req(input$tif_file)
      tif_path <- input$tif_file
      rds_path <- magnemite_find_digitized_rds(tif_path, app_paths$server_dir)

      if (is.na(rds_path)) {
        shiny::showNotification("Corresponding .rds file not found!", type = "error")
        return()
      }

      tryCatch({
        results_bot(magnemite_process_bottom_trace_cluster(tif_path, rds_path))
        results_top(magnemite_process_top_trace_cluster(tif_path, rds_path))
      }, error = function(e) {
        shiny::showNotification(paste("Error processing files:", e$message), type = "error")
      })
    })

    shiny::observeEvent(input$reset, {
      combined_brushed_data_bot(data.frame(X = numeric(), Y = numeric()))
      combined_brushed_data_top(data.frame(X = numeric(), Y = numeric()))
    })

    shiny::observeEvent(input$done_bot, {
      done_pressed_bot(TRUE)
    })

    shiny::observeEvent(input$done_top, {
      done_pressed_top(TRUE)
    })

    output$plot_cluster_3_bot <- shiny::renderPlot({
      shiny::req(results_bot())
      cluster_3 <- results_bot()$cluster_3
      graphics::plot(cluster_3$X, cluster_3$Y, main = "Cluster 3", xlab = "X", ylab = "Y")
      graphics::abline(h = mean(cluster_3$Y), col = "red")
    })

    output$plot_cluster_3_top <- shiny::renderPlot({
      shiny::req(results_top())
      cluster_3 <- results_top()$cluster_3
      graphics::plot(cluster_3$X, cluster_3$Y, main = "Cluster 3", xlab = "X", ylab = "Y")
      graphics::abline(h = mean(cluster_3$Y), col = "red")
    })

    shiny::observeEvent(input$brush_plot_bot, {
      shiny::req(results_bot())
      new_brushed_data <- shiny::brushedPoints(results_bot()$cluster_3, input$brush_plot_bot, xvar = "X", yvar = "Y")
      combined_brushed_data_bot(rbind(combined_brushed_data_bot(), new_brushed_data))
    })

    shiny::observeEvent(input$brush_plot_top, {
      shiny::req(results_top())
      new_brushed_data <- shiny::brushedPoints(results_top()$cluster_3, input$brush_plot_top, xvar = "X", yvar = "Y")
      combined_brushed_data_top(rbind(combined_brushed_data_top(), new_brushed_data))
    })

    shiny::observeEvent(done_pressed_bot(), {
      shiny::req(done_pressed_bot())
      brushed_data <- combined_brushed_data_bot()

      if (nrow(brushed_data) > 0) {
        dist_matrix <- stats::dist(brushed_data[, c("X", "Y")])
        hc <- stats::hclust(dist_matrix)
        clusters <- stats::cutree(hc, h = 24)
        brushed_data$Cluster <- as.factor(clusters)

        output$brushed_plot_bot <- shiny::renderPlot({
          grDevices::png(file.path(app_paths$output_dir, "Brushed_Points.png"), width = 20, height = 7, units = "in", res = 300)
          graphics::plot(brushed_data$X, brushed_data$Y, main = "Combined Brushed Points with Hierarchical Clusters", xlab = "X", ylab = "Y", xlim = c(0, 6000), col = brushed_data$Cluster, pch = 16)

          cluster_centroids <- brushed_data |>
            dplyr::group_by(Cluster) |>
            dplyr::summarise(mean_X = mean(X), mean_Y = mean(Y), .groups = "drop")
          graphics::points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)

          min_values_x <- brushed_data |>
            dplyr::group_by(Cluster) |>
            dplyr::summarise(min_X = min(X), .groups = "drop")

          if (nrow(min_values_x) > 30) {
            shiny::showNotification("Too many clusters detected (>30). Adjust brushing region.", type = "error", duration = 5)
            grDevices::dev.off()
            return(NULL)
          }

          region_medians <- magnemite_cluster_region_medians(min_values_x, brushed_data)
          min_values_bot(region_medians)

          for (i in seq_len(nrow(region_medians))) {
            graphics::abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
          }

          grDevices::dev.off()

          graphics::plot(brushed_data$X, brushed_data$Y, main = "Combined Brushed Points with Hierarchical Clusters", xlab = "X", ylab = "Y", xlim = c(0, 6000), col = brushed_data$Cluster, pch = 16)
          graphics::points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)
          for (i in seq_len(nrow(region_medians))) {
            graphics::abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
          }
        })
      } else {
        output$brushed_plot_bot <- shiny::renderPlot({
          graphics::plot(0, 0, type = "n", xlab = "X", ylab = "Y", main = "No Points Selected")
        })
      }

      done_pressed_bot(FALSE)
      combined_brushed_data_bot(data.frame(X = numeric(), Y = numeric()))
    })

    shiny::observeEvent(done_pressed_top(), {
      shiny::req(done_pressed_top())
      brushed_data <- combined_brushed_data_top()

      if (nrow(brushed_data) > 0) {
        dist_matrix <- stats::dist(brushed_data[, c("X", "Y")])
        hc <- stats::hclust(dist_matrix)
        clusters <- stats::cutree(hc, h = 24)
        brushed_data$Cluster <- as.factor(clusters)

        output$brushed_plot_top <- shiny::renderPlot({
          graphics::plot(brushed_data$X, brushed_data$Y, main = "Combined Brushed Points with Hierarchical Clusters", xlab = "X", ylab = "Y", xlim = c(0, 6000), col = brushed_data$Cluster, pch = 16)

          cluster_centroids <- brushed_data |>
            dplyr::group_by(Cluster) |>
            dplyr::summarise(mean_X = mean(X), mean_Y = mean(Y), .groups = "drop")
          graphics::points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)

          min_values_x <- brushed_data |>
            dplyr::group_by(Cluster) |>
            dplyr::summarise(min_X = min(X), .groups = "drop")

          if (nrow(min_values_x) > 30) {
            shiny::showNotification("Too many clusters detected (>30). Adjust brushing region.", type = "error", duration = 5)
            return(NULL)
          }

          region_medians <- magnemite_cluster_region_medians(min_values_x, brushed_data)
          min_values_top(region_medians)

          for (i in seq_len(nrow(region_medians))) {
            graphics::abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
          }

          graphics::abline(h = mean(brushed_data$Y), col = "red", lwd = 2)
        })
      } else {
        output$brushed_plot_top <- shiny::renderPlot({
          graphics::plot(0, 0, type = "n", xlab = "X", ylab = "Y", main = "No Points Selected")
        })
      }

      done_pressed_top(FALSE)
      combined_brushed_data_top(data.frame(X = numeric(), Y = numeric()))
    })

    shiny::observeEvent(input$save_rds, {
      shiny::req(input$tif_file)
      save_path <- magnemite_timing_tick_rds_path(input$tif_file, app_paths$timing_ticks_dir)
      dir.create(dirname(save_path), recursive = TRUE, showWarnings = FALSE)
      saved_obj <- list(min_values_bot(), min_values_top())
      saveRDS(saved_obj, save_path)
      shiny::showNotification(paste("RDS file saved to:", save_path), type = "message", duration = 5)
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}

run_magnemite_brushclust_app <- function(server_dir = NULL, timing_ticks_dir = NULL, output_dir = NULL) {
  shiny::runApp(magnemite_brushclust_app(server_dir = server_dir, timing_ticks_dir = timing_ticks_dir, output_dir = output_dir))
}

magnemite_timing_tick_click_app <- function(server_dir = NULL, timing_ticks_dir = NULL) {
  app_paths <- magnemite_timing_ticks_paths(server_dir = server_dir, timing_ticks_dir = timing_ticks_dir)

  ui <- shiny::fluidPage(
    shiny::titlePanel("Manual Check of BrushClust"),
    shiny::fluidRow(
      shiny::column(3,
        shiny::selectInput("tif_file", "Select .tif File", choices = NULL),
        shiny::actionButton("next_image", "Next Image"),
        shiny::actionButton("save_rds", "Save .rds")
      ),
      shiny::column(12,
        shiny::plotOutput("plot_output", click = "plot_click", height = "800px")
      )
    )
  )

  server <- function(input, output, session) {
    current_index <- shiny::reactiveVal(1)
    tif_files <- shiny::reactive({
      magnemite_list_tif_files(app_paths$server_dir)
    })
    clicked_values <- shiny::reactiveVal(data.frame(x = numeric(), y = numeric()))
    trigger_plot <- shiny::reactiveVal(0)

    shiny::observe({
      files <- tif_files()
      shiny::updateSelectInput(session, "tif_file", choices = files, selected = if (length(files) > 0) files[1] else character(0))
    })

    shiny::observeEvent(input$next_image, {
      files <- tif_files()
      if (length(files) == 0) {
        return()
      }

      new_index <- current_index() + 1
      if (new_index > length(files)) {
        new_index <- 1
      }
      current_index(new_index)
      shiny::updateSelectInput(session, "tif_file", selected = files[new_index])
    })

    shiny::observeEvent(input$tif_file, {
      files <- tif_files()
      new_index <- match(input$tif_file, files)
      if (!is.na(new_index)) {
        current_index(new_index)
      }
    })

    output$plot_output <- shiny::renderPlot({
      trigger_plot()
      files <- tif_files()
      shiny::req(length(files) > 0)

      img_path <- files[current_index()]
      img_path_png <- paste0(img_path, ".png")
      img <- magick::image_read(img_path_png)

      rds_path <- magnemite_timing_tick_rds_path(img_path, app_paths$timing_ticks_dir)
      tt <- readRDS(rds_path)

      graphics::plot(img)
      if (!is.null(tt[[2]]) && !is.null(tt[[2]][["median_X"]])) {
        for (i in seq_along(tt[[2]][["median_X"]])) {
          graphics::segments(x0 = tt[[2]][["median_X"]][i], x1 = tt[[2]][["median_X"]][i], y0 = 300, y1 = 400, col = "red", lwd = 2.3)
        }
      }
      if (!is.null(tt[[1]]) && !is.null(tt[[1]][["median_X"]])) {
        for (i in seq_along(tt[[1]][["median_X"]])) {
          graphics::segments(x0 = tt[[1]][["median_X"]][i], x1 = tt[[1]][["median_X"]][i], y0 = 100, y1 = 200, col = "red", lwd = 2.3)
        }
      }
    })

    shiny::observeEvent(input$plot_click, {
      new_click <- data.frame(x = round(input$plot_click$x, 0), y = round(input$plot_click$y, 0))
      clicked_values(rbind(clicked_values(), new_click))
    })

    shiny::observeEvent(input$save_rds, {
      files <- tif_files()
      shiny::req(length(files) > 0)
      img_path <- files[current_index()]
      rds_path <- magnemite_timing_tick_rds_path(img_path, app_paths$timing_ticks_dir)
      tt <- readRDS(rds_path)

      if (is.null(tt[[2]]) && is.null(tt[[1]])) {
        tt[[2]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
        tt[[1]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
      } else if (is.null(tt[[2]])) {
        tt[[2]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
      } else if (is.null(tt[[1]])) {
        tt[[1]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
      }

      clicks <- clicked_values()
      if (nrow(clicks) == 0) {
        shiny::showNotification("No clicks to save!", type = "warning")
        return(NULL)
      }

      for (i in seq_len(nrow(clicks))) {
        clicked_x_value <- clicks$x[i]
        clicked_value_y <- clicks$y[i]

        if (clicked_value_y > 250) {
          max_cluster <- if (nrow(tt[[2]]) > 0) max(as.numeric(as.character(tt[[2]]$Cluster)), na.rm = TRUE) else 0
          new_cluster <- max_cluster + 1
          tt[[2]] <- rbind(tt[[2]], data.frame(median_X = clicked_x_value, Cluster = as.factor(new_cluster)))
        } else {
          max_cluster <- if (nrow(tt[[1]]) > 0) max(as.numeric(as.character(tt[[1]]$Cluster)), na.rm = TRUE) else 0
          new_cluster <- max_cluster + 1
          tt[[1]] <- rbind(tt[[1]], data.frame(median_X = clicked_x_value, Cluster = as.factor(new_cluster)))
        }
      }

      dir.create(dirname(rds_path), recursive = TRUE, showWarnings = FALSE)
      saveRDS(tt, rds_path)
      clicked_values(data.frame(x = numeric(), y = numeric()))
      shiny::showNotification("RDS file saved successfully!", type = "message")
      trigger_plot(trigger_plot() + 1)
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}

run_magnemite_timing_tick_click_app <- function(server_dir = NULL, timing_ticks_dir = NULL) {
  shiny::runApp(magnemite_timing_tick_click_app(server_dir = server_dir, timing_ticks_dir = timing_ticks_dir))
}
