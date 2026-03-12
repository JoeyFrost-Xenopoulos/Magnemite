# Reusable timing tick clustering helpers.

#' Process a Trace Cluster Region
#'
#' Runs k-means clustering on a selected image column range and extracts two
#' viable trace clusters aligned to the digitized trace extent.
#'
#' @param tif_path Path to the source `.tif` image.
#' @param rds_path Path to the digitized trace `.rds` file.
#' @param column_range Integer vector of matrix columns to cluster.
#'
#' @return A list with `cluster_2` and `cluster_3` data frames.
#' @export
magnemite_process_trace_cluster <- function(tif_path, rds_path, column_range) {
  img <- magick::image_read(tif_path)
  if (magick::image_info(img)$width < magick::image_info(img)$height) {
    img <- magick::image_rotate(img, -90)
  }

  suppressWarnings(mymat <- as(raster::raster(tif_path), "matrix"))
  img_rds <- readRDS(rds_path)

  if (!is.list(img_rds) || is.null(img_rds$BottomTraceStartEnds)) {
    stop("The .rds file does not have the expected structure. It must be a list with 'BottomTraceStartEnds'.")
  }

  subset_mymat <- mymat[, column_range, drop = FALSE]
  mymat_long <- reshape2::melt(subset_mymat)
  colnames(mymat_long) <- c("X", "Y", "Value")

  kmeans_result <- kmeans(mymat_long$Value, centers = 3)
  mymat_long$Cluster <- as.factor(kmeans_result$cluster)

  cluster_counts <- mymat_long |>
    dplyr::group_by(Cluster) |>
    dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(count))

  viable_clusters <- cluster_counts[-1, ]
  filtered_data <- mymat_long |> dplyr::filter(Cluster %in% viable_clusters$Cluster)

  clusters <- unique(filtered_data$Cluster)
  filtered_data_1 <- filtered_data |> dplyr::filter(Cluster == clusters[1])
  filtered_data_2 <- filtered_data |> dplyr::filter(Cluster == clusters[2])

  mean_y_1 <- round(mean(filtered_data_1$Y), 0)
  exact_mean_rows_1 <- filtered_data_1 |> dplyr::filter(Y == mean_y_1)
  mean_y_2 <- round(mean(filtered_data_2$Y), 0)
  exact_mean_rows_2 <- filtered_data_2 |> dplyr::filter(Y == mean_y_2)

  start_x <- img_rds$BottomTraceStartEnds$Start + 125
  end_x <- img_rds$BottomTraceStartEnds$End + 125

  exact_mean_rows_1 <- exact_mean_rows_1[exact_mean_rows_1$X >= start_x & exact_mean_rows_1$X <= end_x, ]
  exact_mean_rows_2 <- exact_mean_rows_2[exact_mean_rows_2$X >= start_x & exact_mean_rows_2$X <= end_x, ]

  if (length(exact_mean_rows_1$Y) > length(exact_mean_rows_2$Y)) {
    cluster_2 <- filtered_data_1
    cluster_3 <- filtered_data_2
  } else {
    cluster_2 <- filtered_data_2
    cluster_3 <- filtered_data_1
  }

  list(cluster_2 = cluster_2, cluster_3 = cluster_3)
}

#' Process Bottom Trace Cluster
#'
#' Convenience wrapper to process the bottom trace region.
#'
#' @param tif_path Path to the source `.tif` image.
#' @param rds_path Path to the digitized trace `.rds` file.
#'
#' @return A list with clustered bottom-trace data components.
#' @export
magnemite_process_bottom_trace_cluster <- function(tif_path, rds_path) {
  magnemite_process_trace_cluster(tif_path = tif_path, rds_path = rds_path, column_range = 1:250)
}

#' Process Top Trace Cluster
#'
#' Convenience wrapper to process the top trace region.
#'
#' @param tif_path Path to the source `.tif` image.
#' @param rds_path Path to the digitized trace `.rds` file.
#'
#' @return A list with clustered top-trace data components.
#' @export
magnemite_process_top_trace_cluster <- function(tif_path, rds_path) {
  magnemite_process_trace_cluster(tif_path = tif_path, rds_path = rds_path, column_range = 250:500)
}

#' Compute Cluster Region Medians
#'
#' Computes median x positions for each cluster within a configurable local
#' region around each cluster minimum x value.
#'
#' @param min_values_x Data frame containing `Cluster` and `min_X` columns.
#' @param data Clustered data frame containing x values.
#' @param region_width Width of the local window around each cluster minimum.
#'
#' @return A data frame with `Cluster` and `median_X`.
#' @export
magnemite_cluster_region_medians <- function(min_values_x, data, region_width = 40) {
  medians <- sapply(min_values_x$min_X, function(x) {
    subset_region <- data[data$X >= (x - region_width / 2) & data$X <= (x + region_width / 2), ]
    stats::median(subset_region$X, na.rm = TRUE)
  })

  data.frame(Cluster = min_values_x$Cluster, median_X = medians)
}
