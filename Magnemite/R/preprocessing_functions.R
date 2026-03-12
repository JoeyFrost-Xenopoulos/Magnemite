# Reusable functions migrated from Nosepass/pre_Processing notebooks.

magnemite_preprocessing_paths <- function(server_dir = NULL, timing_ticks_dir = NULL) {
  resolved_server_dir <- if (!is.null(server_dir) && nzchar(server_dir)) {
    server_dir
  } else {
    Sys.getenv("MAGNETO_SERVER_DIR", unset = Sys.getenv("MAGNEMITE_SERVER_DIR", unset = "D:/SERVER/1902"))
  }

  resolved_server_dir <- normalizePath(resolved_server_dir, winslash = "/", mustWork = FALSE)

  resolved_timing_ticks_dir <- if (!is.null(timing_ticks_dir) && nzchar(timing_ticks_dir)) {
    timing_ticks_dir
  } else {
    file.path(resolved_server_dir, "TimingTicks")
  }

  list(
    server_dir = resolved_server_dir,
    timing_ticks_dir = normalizePath(resolved_timing_ticks_dir, winslash = "/", mustWork = FALSE)
  )
}

magnemite_load_trace_bundle <- function(base_name, server_dir = NULL, timing_ticks_dir = NULL, rotate_if_vertical = TRUE) {
  paths <- magnemite_preprocessing_paths(server_dir = server_dir, timing_ticks_dir = timing_ticks_dir)

  tif_path <- file.path(paths$server_dir, paste0(base_name, ".tif"))
  digitized_rds_path <- file.path(paths$server_dir, paste0(base_name, ".tif-Digitized.rds"))
  timing_ticks_rds_path <- file.path(paths$timing_ticks_dir, paste0(base_name, ".rds"))

  if (!file.exists(tif_path)) {
    stop("TIF file not found: ", tif_path)
  }
  if (!file.exists(digitized_rds_path)) {
    stop("Digitized RDS not found: ", digitized_rds_path)
  }
  if (!file.exists(timing_ticks_rds_path)) {
    stop("Timing tick RDS not found: ", timing_ticks_rds_path)
  }

  img <- magick::image_read(tif_path)
  if (isTRUE(rotate_if_vertical)) {
    info <- magick::image_info(img)
    if (info$width < info$height) {
      img <- magick::image_rotate(img, -90)
    }
  }

  list(
    base_name = base_name,
    paths = list(
      tif_path = normalizePath(tif_path, winslash = "/", mustWork = FALSE),
      digitized_rds_path = normalizePath(digitized_rds_path, winslash = "/", mustWork = FALSE),
      timing_ticks_rds_path = normalizePath(timing_ticks_rds_path, winslash = "/", mustWork = FALSE)
    ),
    image = img,
    img_rds = readRDS(digitized_rds_path),
    timing_ticks = readRDS(timing_ticks_rds_path)
  )
}

magnemite_kmeans_trace_clusters <- function(
  tif_path,
  digitized_rds_path,
  column_range = 500:1100,
  centers = 3,
  scale_values = TRUE,
  seed = 123
) {
  if (!file.exists(tif_path)) {
    stop("TIF file not found: ", tif_path)
  }
  if (!file.exists(digitized_rds_path)) {
    stop("Digitized RDS not found: ", digitized_rds_path)
  }

  if (!is.null(seed)) {
    set.seed(seed)
  }

  mymat <- as(raster::raster(tif_path), "matrix")
  img_rds <- readRDS(digitized_rds_path)

  if (max(column_range) > ncol(mymat) || min(column_range) < 1) {
    stop("column_range is out of matrix bounds.")
  }

  subset_mymat <- mymat[, column_range, drop = FALSE]
  mymat_long <- reshape2::melt(subset_mymat)
  colnames(mymat_long) <- c("X", "Y", "Value")
  mymat_long <- stats::na.omit(mymat_long)

  if (isTRUE(scale_values)) {
    mymat_long$Value <- as.numeric(scale(mymat_long$Value))
  }

  kmeans_result <- stats::kmeans(mymat_long$Value, centers = centers)
  mymat_long$Cluster <- as.factor(kmeans_result$cluster)

  cluster_counts <- mymat_long |>
    dplyr::group_by(Cluster) |>
    dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(count))

  if (nrow(cluster_counts) < 3) {
    stop("kmeans did not produce enough clusters for trace extraction.")
  }

  viable_clusters <- cluster_counts[-1, ]
  filtered_data <- mymat_long |> dplyr::filter(Cluster %in% viable_clusters$Cluster)

  clusters <- unique(filtered_data$Cluster)
  filtered_data_1 <- filtered_data |> dplyr::filter(Cluster == clusters[1])
  filtered_data_2 <- filtered_data |> dplyr::filter(Cluster == clusters[2])

  var_y_1 <- round(stats::var(filtered_data_1$Y), 0)
  var_y_2 <- round(stats::var(filtered_data_2$Y), 0)

  if (var_y_1 < var_y_2) {
    cluster_2 <- filtered_data_1
    cluster_3 <- filtered_data_2
  } else {
    cluster_2 <- filtered_data_2
    cluster_3 <- filtered_data_1
  }

  start_x_top <- img_rds$TopTraceStartEnds$Start + 125
  end_x_top <- img_rds$TopTraceStartEnds$End + 125
  start_x_bot <- img_rds$BottomTraceStartEnds$Start + 125
  end_x_bot <- img_rds$BottomTraceStartEnds$End + 125

  top_trace <- dplyr::filter(cluster_2, X >= start_x_top & X <= end_x_top)
  bot_trace <- dplyr::filter(cluster_3, X >= start_x_bot & X <= end_x_bot)

  list(
    img_rds = img_rds,
    matrix_long = mymat_long,
    cluster_2 = cluster_2,
    cluster_3 = cluster_3,
    top_trace = top_trace,
    bottom_trace = bot_trace
  )
}

magnemite_trace_medians_by_x <- function(trace_df) {
  if (is.null(trace_df) || nrow(trace_df) == 0) {
    return(data.frame(X = numeric(0), median_Y = numeric(0)))
  }

  trace_df |>
    dplyr::group_by(X) |>
    dplyr::summarise(median_Y = stats::median(Y), .groups = "drop") |>
    dplyr::arrange(X)
}

magnemite_plot_traces_with_ticks <- function(bundle, tick_y_top = c(300, 400), tick_y_bottom = c(100, 200)) {
  if (is.null(bundle$image) || is.null(bundle$img_rds) || is.null(bundle$timing_ticks)) {
    stop("bundle must come from magnemite_load_trace_bundle().")
  }

  graphics::plot(bundle$image)

  graphics::lines(
    seq(from = bundle$img_rds$TopTraceStartEnds$Start + 125, to = bundle$img_rds$TopTraceStartEnds$End + 125),
    y = bundle$img_rds$TopTraceMatrix + 96,
    col = "red"
  )

  graphics::lines(
    seq(from = bundle$img_rds$BottomTraceStartEnds$Start + 125, to = bundle$img_rds$BottomTraceStartEnds$End + 125),
    y = bundle$img_rds$BottomTraceMatrix + 96,
    col = "red"
  )

  tt <- bundle$timing_ticks

  if (!is.null(tt[[2]]) && !is.null(tt[[2]][["median_X"]])) {
    for (i in seq_along(tt[[2]][["median_X"]])) {
      graphics::segments(
        x0 = tt[[2]][["median_X"]][i], x1 = tt[[2]][["median_X"]][i],
        y0 = tick_y_top[1], y1 = tick_y_top[2], col = "red", lwd = 1
      )
    }
  }

  if (!is.null(tt[[1]]) && !is.null(tt[[1]][["median_X"]])) {
    for (i in seq_along(tt[[1]][["median_X"]])) {
      graphics::segments(
        x0 = tt[[1]][["median_X"]][i], x1 = tt[[1]][["median_X"]][i],
        y0 = tick_y_bottom[1], y1 = tick_y_bottom[2], col = "red", lwd = 1
      )
    }
  }

  invisible(NULL)
}
