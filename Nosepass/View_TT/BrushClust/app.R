library(shiny)
library(magick)
library(raster)
library(ggplot2)
library(reshape2)
library(dplyr)
library(shinyjs)

server_dir <- normalizePath(
  Sys.getenv("MAGNETO_SERVER_DIR", unset = "D:/SERVER/1902"),
  winslash = "/",
  mustWork = FALSE
)
timing_ticks_dir <- file.path(server_dir, "TimingTicks")
output_dir <- normalizePath(
  Sys.getenv("MAGNETO_OUTPUT_DIR", unset = file.path(getwd(), "output")),
  winslash = "/",
  mustWork = FALSE
)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Define the function for processing the files
process_files_bot <- function(tif_path, rds_path) {
  # Load and process the image
  img <- image_read(tif_path)
  if (image_info(img)$width < image_info(img)$height) {
    img <- image_rotate(img, -90)
  }
  
  # Convert the .tif file to a matrix
  suppressWarnings(mymat <- as(raster(tif_path), "matrix"))
  
  # Load the .rds file
  img_rds <- readRDS(rds_path)
  
  # Check if the .rds file has the expected structure
  if (!is.list(img_rds) || is.null(img_rds$BottomTraceStartEnds)) {
    stop("The .rds file does not have the expected structure. It must be a list with 'BottomTraceStartEnds'.")
  }
  
  # Subset the matrix for processing
  subset_mymat <- mymat[, 1:250]
  
  # Reshape the matrix for clustering
  mymat_long <- melt(subset_mymat)
  colnames(mymat_long) <- c("X", "Y", "Value")
  
  # Perform clustering
  kmeans_result <- kmeans(mymat_long$Value, centers = 3)
  mymat_long$Cluster <- as.factor(kmeans_result$cluster)
  
  # Calculate the number of data points in each cluster
  cluster_counts <- mymat_long %>%
    group_by(Cluster) %>%
    summarize(count = n()) %>%
    arrange(desc(count))
  
  # Remove the largest cluster
  viable_clusters <- cluster_counts[-1, ]
  filtered_data <- mymat_long %>%
    filter(Cluster %in% viable_clusters$Cluster)
  
  # Split the data into two clusters
  clusters <- unique(filtered_data$Cluster)
  filtered_data_1 <- filtered_data %>%
    filter(Cluster == clusters[1])
  filtered_data_2 <- filtered_data %>%
    filter(Cluster == clusters[2])
  
  # Calculate mean rows for each cluster
  mean_Y_1 <- round(mean(filtered_data_1$Y), 0)
  exact_mean_rows_1 <- filtered_data_1 %>%
    filter(Y == mean_Y_1)
  mean_Y_2 <- round(mean(filtered_data_2$Y), 0)
  exact_mean_rows_2 <- filtered_data_2 %>%
    filter(Y == mean_Y_2)
  
  # Define bounds and adjust if necessary
  start_x <- img_rds$BottomTraceStartEnds$Start + 125
  end_x <- img_rds$BottomTraceStartEnds$End + 125
  
  exact_mean_rows_1 <- exact_mean_rows_1[exact_mean_rows_1$X >= start_x & exact_mean_rows_1$X <= end_x, ]
  exact_mean_rows_2 <- exact_mean_rows_2[exact_mean_rows_2$X >= start_x & exact_mean_rows_2$X <= end_x, ]
  
  # Assign clusters
  if (length(exact_mean_rows_1$Y) > length(exact_mean_rows_2$Y)) {
    cluster_2 <- filtered_data_1
    cluster_3 <- filtered_data_2
  } else {
    cluster_2 <- filtered_data_2
    cluster_3 <- filtered_data_1
  }
  
  list(cluster_2 = cluster_2, cluster_3 = cluster_3)
}

# Define the function for processing the files
process_files_top <- function(tif_path, rds_path) {
  # Load and process the image
  img <- image_read(tif_path)
  if (image_info(img)$width < image_info(img)$height) {
    img <- image_rotate(img, -90)
  }
  
  # Convert the .tif file to a matrix
  suppressWarnings(mymat <- as(raster(tif_path), "matrix"))
  
  # Load the .rds file
  img_rds <- readRDS(rds_path)
  
  # Check if the .rds file has the expected structure
  if (!is.list(img_rds) || is.null(img_rds$BottomTraceStartEnds)) {
    stop("The .rds file does not have the expected structure. It must be a list with 'BottomTraceStartEnds'.")
  }
  
  # Subset the matrix for processing
  subset_mymat <- mymat[, 250:500]
  
  # Reshape the matrix for clustering
  mymat_long <- melt(subset_mymat)
  colnames(mymat_long) <- c("X", "Y", "Value")
  
  # Perform clustering
  kmeans_result <- kmeans(mymat_long$Value, centers = 3)
  mymat_long$Cluster <- as.factor(kmeans_result$cluster)
  
  # Calculate the number of data points in each cluster
  cluster_counts <- mymat_long %>%
    group_by(Cluster) %>%
    summarize(count = n()) %>%
    arrange(desc(count))
  
  # Remove the largest cluster
  viable_clusters <- cluster_counts[-1, ]
  filtered_data <- mymat_long %>%
    filter(Cluster %in% viable_clusters$Cluster)
  
  # Split the data into two clusters
  clusters <- unique(filtered_data$Cluster)
  filtered_data_1 <- filtered_data %>%
    filter(Cluster == clusters[1])
  filtered_data_2 <- filtered_data %>%
    filter(Cluster == clusters[2])
  
  # Calculate mean rows for each cluster
  mean_Y_1 <- round(mean(filtered_data_1$Y), 0)
  exact_mean_rows_1 <- filtered_data_1 %>%
    filter(Y == mean_Y_1)
  mean_Y_2 <- round(mean(filtered_data_2$Y), 0)
  exact_mean_rows_2 <- filtered_data_2 %>%
    filter(Y == mean_Y_2)
  
  # Define bounds and adjust if necessary
  start_x <- img_rds$BottomTraceStartEnds$Start + 125
  end_x <- img_rds$BottomTraceStartEnds$End + 125
  
  exact_mean_rows_1 <- exact_mean_rows_1[exact_mean_rows_1$X >= start_x & exact_mean_rows_1$X <= end_x, ]
  exact_mean_rows_2 <- exact_mean_rows_2[exact_mean_rows_2$X >= start_x & exact_mean_rows_2$X <= end_x, ]
  
  # Assign clusters
  if (length(exact_mean_rows_1$Y) > length(exact_mean_rows_2$Y)) {
    cluster_2 <- filtered_data_1
    cluster_3 <- filtered_data_2
  } else {
    cluster_2 <- filtered_data_2
    cluster_3 <- filtered_data_1
  }
  
  list(cluster_2 = cluster_2, cluster_3 = cluster_3)
}

# Define adjusting region for top
# Function to calculate median X for a region around min_X
get_medians <- function(min_values_X, data, region_width = 40) {
  medians <- sapply(min_values_X$min_X, function(x) {
    subset_region <- data[data$X >= (x - region_width / 2) & data$X <= (x + region_width / 2), ]
    median(subset_region$X, na.rm = TRUE)  # Calculate median, removing NAs if any
  })
  return(data.frame(Cluster = min_values_X$Cluster, median_X = medians))
}

# Define UI
ui <- fluidPage(
  useShinyjs(),  # Enable JavaScript interactions
  titlePanel("Cluster Processing App"),
  sidebarLayout(
    sidebarPanel(
      selectInput("tif_file", "Select .tif File", choices = NULL),
      actionButton("process", "Process Files"), # Processes Files
      actionButton("next_image", "Next Image"),  # Add "Next Image" button
      actionButton("save_rds", "Save .rds"), # Save .rds file
      actionButton("reset", "Reset Brushed Data")
    ),
    mainPanel(
      # Row for bottom plot and done button
      fluidRow(
        column(12, 
               plotOutput("plot_cluster_3_bot", height = "800px", brush = brushOpts(id = "brush_plot_bot"))
        ),
        column(6, 
               actionButton("done_bot", "Done Bot", width = "400px") # Done button for bottom plot
        )
      ),
      # Row for top plot and done button
      fluidRow(
        column(12, 
               plotOutput("plot_cluster_3_top", height = "800px", brush = brushOpts(id = "brush_plot_top"))
        ),
        column(6, 
               actionButton("done_top", "Done Top", width = "400px") # Done button for top plot
        )
      ),
      plotOutput("brushed_plot_bot", height = "400px"),
      plotOutput("brushed_plot_top", height = "400px")
    )
  )
)

# Define Server
server <- function(input, output, session) {
  
  # Global variables
  results_bot <- reactiveVal(NULL)
  results_top <- reactiveVal(NULL)
  min_values_bot <- reactiveVal(NULL)
  min_values_top <- reactiveVal(NULL)
  # Reactive value to store the current index of the selected .tif file
  current_index <- reactiveVal(1)
  # Get the list of .tif files
  tif_files <- reactive({
    list.files(server_dir, pattern = "\\.tif$", full.names = TRUE)
  })
  
  # Done truth variable
  done_pressed_bot <- reactiveVal(FALSE)
  done_pressed_top <- reactiveVal(FALSE)
  
  # Binding brushed_data together top and bot
  combined_brushed_data_bot <- reactiveVal(data.frame(X = numeric(), Y = numeric()))
  combined_brushed_data_top <- reactiveVal(data.frame(X = numeric(), Y = numeric()))
  
  # Populate the .tif file dropdown
  observe({
    updateSelectInput(session, "tif_file", choices = tif_files(), selected = tif_files()[1])
  })
  
  # Observe the "Next Image" button
  observeEvent(input$next_image, {
    # Increment the index
    new_index <- current_index() + 1
    
    # If the index exceeds the number of files, wrap around to the first file
    if (new_index > length(tif_files())) {
      new_index <- 1
    }
    
    # Update the current index
    current_index(new_index)
    
    # Reset bot and top storage
    min_values_bot(NULL)
    min_values_top(NULL)
    
    # Update the selected .tif file in the dropdown
    updateSelectInput(session, "tif_file", selected = tif_files()[new_index])
  })
  
  # Trigger "Process" button when a new image is selected
  observeEvent(input$tif_file, {
    # Find the index of the selected file in tif_files()
    new_index <- match(input$tif_file, tif_files())
    
    # Update the current index
    if (!is.na(new_index)) {
      current_index(new_index)
    }
    
    # Trigger "Process" button when a new image is selected
    shinyjs::click("process")
    # Trigger "Reset" button when a new image is selected
    shinyjs::click("reset")
  })
  
  # Process Input Event
  observeEvent(input$process, {
    req(input$tif_file)
    
    tif_path <- input$tif_file
    
    # Construct the base name of the .tif file
    base_name <- tools::file_path_sans_ext(basename(tif_path))
    
    # Define possible .rds file paths
    rds_path_1 <- file.path(server_dir, paste0(base_name, ".tif-Digitized.rds"))
    rds_path_2 <- file.path(server_dir, paste0(base_name, ".tif-FailToProcess.rds"))
    
    # Check which .rds file exists
    if (file.exists(rds_path_1)) {
      rds_path <- rds_path_1
    } else if (file.exists(rds_path_2)) {
      rds_path <- rds_path_2
    } else {
      showNotification("Corresponding .rds file not found!", type = "error")
      return()
    }
    
    # Try to process the files
    tryCatch({
      results_bot(process_files_bot(tif_path, rds_path))
      results_top(process_files_top(tif_path, rds_path))
      
    }, error = function(e) {
      showNotification(paste("Error processing files:", e$message), type = "error")
    })
  })
  
  # Reset Button Event
  observeEvent(input$reset, {
    combined_brushed_data_bot(data.frame(X = numeric(), Y = numeric()))
    combined_brushed_data_top(data.frame(X = numeric(), Y = numeric()))
  })
  
  # Done Button event
  observeEvent(input$done_bot, {
    done_pressed_bot(TRUE)  # Set the condition to TRUE
  })
  observeEvent(input$done_top, {
    done_pressed_top(TRUE)  # Set the condition to TRUE
  })
  
  # Output of clusters BOT AND TOP
  output$plot_cluster_3_bot <- renderPlot({
    req(results_bot())
    cluster_3 <- results_bot()$cluster_3
    plot(cluster_3$X, cluster_3$Y, main = "Cluster 3", xlab = "X", ylab = "Y")
    abline(h = mean(cluster_3$Y), col = "red")
  })
  output$plot_cluster_3_top <- renderPlot({
    req(results_top())
    cluster_3 <- results_top()$cluster_3
    plot(cluster_3$X, cluster_3$Y, main = "Cluster 3", xlab = "X", ylab = "Y")
    abline(h = mean(cluster_3$Y), col = "red")
  })
  
  # Observe brush events and update combined_brushed_data for BOT AND TOP
  observeEvent(input$brush_plot_bot, {
    req(results_bot())
    
    # Get the newly brushed data
    new_brushed_data <- brushedPoints(results_bot()$cluster_3, input$brush_plot_bot, xvar = "X", yvar = "Y")
    
    # Combine with existing brushed data
    combined_brushed_data_bot(rbind(combined_brushed_data_bot(), new_brushed_data))
  })
  observeEvent(input$brush_plot_top, {
    req(results_top())
    
    # Get the newly brushed data
    new_brushed_data <- brushedPoints(results_top()$cluster_3, input$brush_plot_top, xvar = "X", yvar = "Y")
    
    # Combine with existing brushed data
    combined_brushed_data_top(rbind(combined_brushed_data_top(), new_brushed_data))
  })
  
  # Observe the condition and perform final clustering and plotting for BOT AND TOP
  observeEvent(done_pressed_bot(), {
    req(done_pressed_bot())  # Proceed only if the condition is TRUE
    
    # Get the combined brushed data
    brushed_data <- combined_brushed_data_bot()
    
    # If there are brushed points
    if (nrow(brushed_data) > 0) {
      # Perform hierarchical clustering on the brushed data
      dist_matrix <- dist(brushed_data[, c("X", "Y")])  # Calculate distance matrix
      hc <- hclust(dist_matrix)  # Perform hierarchical clustering
      
      # Cut the dendrogram at height 24 to create clusters
      clusters <- cutree(hc, h = 24)
      
      # Add the cluster information to the brushed data
      brushed_data$Cluster <- as.factor(clusters)
      
      output$brushed_plot_bot <- renderPlot({
    png(file.path(output_dir, "Brushed_Points.png"), 
        width = 20, height = 7, units = "in", res = 300)
    
    plot(brushed_data$X, brushed_data$Y,
         main = "Combined Brushed Points with Hierarchical Clusters",
         xlab = "X", ylab = "Y",
         xlim = c(0, 6000),
         col = brushed_data$Cluster, pch = 16)
    
    cluster_centroids <- brushed_data %>%
      group_by(Cluster) %>%
      summarize(mean_X = mean(X), mean_Y = mean(Y))
    
    points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)
    
    min_values_X <- brushed_data %>%
      group_by(Cluster) %>%
      summarize(min_X = min(X))
    
    if (nrow(min_values_X) > 30) {
      showNotification("Too many clusters detected (>30). Adjust brushing region.", 
                        type = "error", duration = 5)
      dev.off()  # Close the PNG device
      return(NULL)
    }
    
    region_medians <- get_medians(min_values_X, brushed_data)
    min_values_bot(region_medians)
    
    for (i in 1:nrow(region_medians)) {
      abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
    }

    # Finalize the saved plot
    dev.off()
    
    # Display the same plot in the Shiny app
    plot(brushed_data$X, brushed_data$Y,
         main = "Combined Brushed Points with Hierarchical Clusters",
         xlab = "X", ylab = "Y",
         xlim = c(0, 6000),
         col = brushed_data$Cluster, pch = 16)
    
    points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)
    
    for (i in 1:nrow(region_medians)) {
      abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
    }
})
    } else {
      # No points selected, plot a blank plot
      output$brushed_plot_bot <- renderPlot({
        plot(0, 0, type = "n", xlab = "X", ylab = "Y", main = "No Points Selected")
      })
    }
    
    # Reset the condition and combined data for future use
    done_pressed_bot(FALSE)
    combined_brushed_data_bot(data.frame(X = numeric(), Y = numeric()))
  })
  observeEvent(done_pressed_top(), {
    req(done_pressed_top())  # Proceed only if the condition is TRUE
    
    # Get the combined brushed data
    brushed_data <- combined_brushed_data_top()
    
    # If there are brushed points
    if (nrow(brushed_data) > 0) {
      # Perform hierarchical clustering on the brushed data
      dist_matrix <- dist(brushed_data[, c("X", "Y")])  # Calculate distance matrix
      hc <- hclust(dist_matrix)  # Perform hierarchical clustering
      
      # Cut the dendrogram at height 24 to create clusters
      clusters <- cutree(hc, h = 24)
      
      # Add the cluster information to the brushed data
      brushed_data$Cluster <- as.factor(clusters)
      
      # Plot the brushed points with colors based on the clusters
      output$brushed_plot_top <- renderPlot({
        plot(brushed_data$X, brushed_data$Y,
             main = "Combined Brushed Points with Hierarchical Clusters",
             xlab = "X", ylab = "Y",
             xlim = c(0, 6000),
             col = brushed_data$Cluster, pch = 16)  # Color points by cluster
        
        # Add the cluster centroids (optional)
        cluster_centroids <- brushed_data %>%
          group_by(Cluster) %>%
          summarize(mean_X = mean(X), mean_Y = mean(Y))
        
        # Plot the centroids on top of the scatter plot
        points(cluster_centroids$mean_X, cluster_centroids$mean_Y, col = "black", pch = 4, cex = 2)
        
        # Calculate the minimum X value for each cluster
        min_values_X <- brushed_data %>%
          group_by(Cluster) %>%
          summarize(min_X = min(X))
        
        # Check if the number of clusters exceeds 30
        if (nrow(min_values_X) > 30) {
          showNotification("Too many clusters detected (>30). Adjust brushing region.", type = "error", duration = 5)
          return(NULL)  # Exit the function without plotting
        }
        
        # Calculate the region medians
        region_medians <- get_medians(min_values_X, brushed_data)
        
        min_values_top(region_medians)  # Saves current state of min_values_x
        
        # Add vertical lines at the median X value for each cluster
        for (i in 1:nrow(region_medians)) {
          abline(v = region_medians$median_X[i], col = "green", lwd = 2, lty = 2)
        }
        
        # Add horizontal line for mean Y
        abline(h = mean(brushed_data$Y), col = "red", lwd = 2)
      })
    } else {
      # No points selected, plot a blank plot
      output$brushed_plot_bot <- renderPlot({
        plot(0, 0, type = "n", xlab = "X", ylab = "Y", main = "No Points Selected")
      })
    }
    
    # Reset the condition and combined data for future use
    done_pressed_top(FALSE)
    combined_brushed_data_top(data.frame(X = numeric(), Y = numeric()))
  })
  
  # Save .rds event
  observeEvent(input$save_rds, {
    # Extract the basename of the tif file (without the extension)
    basename_tif <- tools::file_path_sans_ext(basename(input$tif_file))
    # Define the path to save the RDS file
    save_path <- file.path(timing_ticks_dir, paste0(basename_tif, ".rds"))
    saved_obj <- list(min_values_bot(), min_values_top()) # Save both objects
    
    # Save both Top and Bot min_values_X data to the dynamically constructed path
    saveRDS(saved_obj, save_path)
    
    # Show notification
    showNotification(paste("RDS file saved to:", save_path), type = "message", duration = 5)
  })
}

# Run the app
shinyApp(ui = ui, server = server)