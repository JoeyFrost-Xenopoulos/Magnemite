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

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Manual Check of BrushClust"),
  
  fluidRow(
    column(3,  # Sidebar takes up 3 out of 12 columns
           selectInput("tif_file", "Select .tif File", choices = NULL), # Select .tif file
           actionButton("next_image", "Next Image"),  # Add "Next Image" button
           actionButton("save_rds", "Save .rds")
           # actionButton("click_mode", "Click Mode"),
           # actionButton("delete_mode", "Delete Mode")
    ),
    
    column(12,  # Main panel takes up 9 out of 12 columns
           plotOutput("plot_output", click = "plot_click", height = "800px")
    )
  )
)


server <- function(input, output, session) {
  # Reactive value to store the current index of the selected .tif file
  current_index <- reactiveVal(1)
  # Get the list of .tif files
  tif_files <- reactive({
    list.files(server_dir, pattern = "\\.tif$", full.names = TRUE)
  })
  # Store Clicked Values
  clicked_values <- reactiveVal(data.frame(x = numeric(), y = numeric()))
  # Define a reactive value to act as a trigger
  trigger_plot <- reactiveVal(0)
  
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

    # Update the selected .tif file in the dropdown
    updateSelectInput(session, "tif_file", selected = tif_files()[new_index])
  })

  # Updates index
  observeEvent(input$tif_file, {
    # Find the index of the selected file in tif_files()
    new_index <- match(input$tif_file, tif_files())

    # Update the current index
    if (!is.na(new_index)) {
      current_index(new_index)
    }

  })

  # Plot the image
  output$plot_output <- renderPlot({
    trigger_plot()
    
    # Pulling path from list
    img_path <- tif_files()[current_index()]
    # Replacing .tif with .png
    img_path_png <- paste0(img_path, ".png")
    img <- image_read(img_path_png)
    
    # Building .rds path
    base_name <- tools::file_path_sans_ext(basename(img_path))
    rds_path <- file.path(timing_ticks_dir, paste0(base_name, ".rds"))
    tt <- readRDS(rds_path)

    plot(img)
    for (i in seq_along(tt[[2]][["median_X"]])) {
      segments(
        x0 = tt[[2]][["median_X"]][i],  # x position for the line
        x1 = tt[[2]][["median_X"]][i],  # same x for vertical line
        y0 = 300,           # starting y position
        y1 = 400,           # ending y position
        col = "red",        # line color
        lwd = 2.3             # line width
      )
    }
    for (i in seq_along(tt[[1]][["median_X"]])) {
      segments(
        x0 = tt[[1]][["median_X"]][i],  # x position for the line
        x1 = tt[[1]][["median_X"]][i],  # same x for vertical line
        y0 = 100,           # starting y position
        y1 = 200,           # ending y position
        col = "red",        # line color
        lwd = 2.3             # line width
      )
    }
    
  })
  
  observeEvent(input$plot_click, {
    new_click <- data.frame(x = round(input$plot_click$x, 0), 
                            y = round(input$plot_click$y, 0))
    
    # Append new click to the list
    clicked_values(rbind(clicked_values(), new_click))
  })
  
  observeEvent(input$save_rds, {
    # Pulling path from list
    img_path <- tif_files()[current_index()]
    # Building .rds path
    base_name <- tools::file_path_sans_ext(basename(img_path))
    rds_path <- file.path(timing_ticks_dir, paste0(base_name, ".rds"))
    tt <- readRDS(rds_path)
    
    # Initializes if Brush Clust did not pick anything up
    if(is.null(tt[[2]]) && is.null(tt[[1]]))
    {
      tt[[2]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
      tt[[1]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))
    }
    else if(is.null(tt[[2]]))
    {tt[[2]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))}
    else if(is.null(tt[[1]]))
    {tt[[1]] <- data.frame(Cluster = numeric(0), median_X = numeric(0))}
    
    # Get stored clicks
    clicks <- clicked_values()
    
    if (nrow(clicks) == 0) {
      showNotification("No clicks to save!", type = "warning")
      return(NULL)
    }
    
    for (i in seq_len(nrow(clicks))) {
      clicked_x_value <- clicks$x[i]
      clicked_value_y <- clicks$y[i]
      
      if (clicked_value_y > 250) {
        # Convert Cluster to numeric if it exists, otherwise start from 0
        if (nrow(tt[[2]]) > 0) {
          max_cluster <- max(as.numeric(as.character(tt[[2]]$Cluster)), na.rm = TRUE)
        } else {
          max_cluster <- 0
        }
        
        new_cluster <- max_cluster + 1
        
        # Append new row
        tt[[2]] <- rbind(tt[[2]], data.frame(median_X = clicked_x_value, Cluster = as.factor(new_cluster)))
      } else {
        # Convert Cluster to numeric if it exists, otherwise start from 0
        if (nrow(tt[[1]]) > 0) {
          max_cluster <- max(as.numeric(as.character(tt[[1]]$Cluster)), na.rm = TRUE)
        } else {
          max_cluster <- 0
        }
        
        new_cluster <- max_cluster + 1
        
        # Append new row
        tt[[1]] <- rbind(tt[[1]], data.frame(median_X = clicked_x_value, Cluster = as.factor(new_cluster)))
      }
    }
    
    # Save the modified RDS file back
    saveRDS(tt, rds_path)
    
    # Clear stored clicks after saving
    clicked_values(data.frame(x = numeric(), y = numeric()))
    
    showNotification("RDS file saved successfully!", type = "message")
    
    # Invalidate the reactive value to trigger the plot re-render
    trigger_plot(trigger_plot() + 1)
  })
}

# Run the app
shinyApp(ui = ui, server = server)