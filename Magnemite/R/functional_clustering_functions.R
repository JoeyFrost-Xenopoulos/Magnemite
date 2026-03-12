# Reusable functions migrated from Nosepass/Functional_Clustering notebooks.

magnemite_functional_paths <- function(server_dir = NULL, attempts_dir = NULL, output_dir = NULL) {
  resolved_server_dir <- if (!is.null(server_dir) && nzchar(server_dir)) {
    server_dir
  } else {
    Sys.getenv("MAGNETO_SERVER_DIR", unset = Sys.getenv("MAGNEMITE_SERVER_DIR", unset = "D:/SERVER/1902"))
  }

  resolved_attempts_dir <- if (!is.null(attempts_dir) && nzchar(attempts_dir)) {
    attempts_dir
  } else {
    Sys.getenv("MAGNETO_ATTEMPTS_DIR", unset = file.path(magnemite_default_output_root(), "data", "Attempts"))
  }

  resolved_output_dir <- if (!is.null(output_dir) && nzchar(output_dir)) {
    output_dir
  } else {
    Sys.getenv("MAGNETO_OUTPUT_DIR", unset = file.path(magnemite_default_output_root(), "output"))
  }

  list(
    server_dir = normalizePath(resolved_server_dir, winslash = "/", mustWork = FALSE),
    attempts_dir = normalizePath(resolved_attempts_dir, winslash = "/", mustWork = FALSE),
    output_dir = normalizePath(resolved_output_dir, winslash = "/", mustWork = FALSE),
    timing_ticks_dir = normalizePath(file.path(resolved_server_dir, "TimingTicks"), winslash = "/", mustWork = FALSE)
  )
}

magnemite_list_trace_rds_files <- function(server_dir, exclude_base_names = character()) {
  data_files <- list.files(server_dir, pattern = "\\.RDS$|\\.rds$", full.names = TRUE)

  base_names <- sub("\\.RDS$|\\.rds$", "", basename(data_files))
  base_names <- sub("\\.tif-(Digitized|FailToProcess)$", "", base_names)

  keep <- !(base_names %in% exclude_base_names)
  data_files[keep]
}

magnemite_assign_actual_times <- function(tt, min_length = 25) {
  if (is.null(tt[[1]]) && is.null(tt[[2]])) {
    return(tt)
  }

  if (!is.null(tt[[1]]) && !is.null(tt[[1]]$median_X)) {
    tt[[1]]$median_X <- sort(tt[[1]]$median_X, decreasing = FALSE)
  }
  if (!is.null(tt[[2]]) && !is.null(tt[[2]]$median_X)) {
    tt[[2]]$median_X <- sort(tt[[2]]$median_X, decreasing = FALSE)
  }

  length_bot <- ifelse(!is.null(tt[[1]]) && is.data.frame(tt[[1]]), nrow(tt[[1]]), 0)
  length_top <- ifelse(!is.null(tt[[2]]) && is.data.frame(tt[[2]]), nrow(tt[[2]]), 0)
  max_length <- max(length_bot, length_top, min_length)

  if (!is.null(tt[[1]])) {
    start_time <- if (length_bot <= 24) "12:00:00" else "11:00:00"
    times <- seq(from = as.POSIXct(start_time, format = "%H:%M"), by = "hour", length.out = max_length)
    tt[[1]]$actual_time <- format(times, format = "%H:%M")[1:length_bot]
  }

  if (!is.null(tt[[2]])) {
    start_time <- if (length_top <= 24) "12:00:00" else "11:00:00"
    times <- seq(from = as.POSIXct(start_time, format = "%H:%M"), by = "hour", length.out = max_length)
    tt[[2]]$actual_time <- format(times, format = "%H:%M")[1:length_top]
  }

  tt
}

magnemite_assign_actual_times_batch <- function(
  input_dir,
  output_dir,
  include_files = NULL,
  exclude_files = c("AGC-D-19020930-19021001.rds", "AGC-D-19021106-19021107.rds")
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  files <- if (is.null(include_files)) {
    list.files(input_dir)
  } else {
    include_files
  }

  files <- files[!(files %in% exclude_files)]
  written <- character()

  for (file in files) {
    full_path <- file.path(input_dir, file)
    tt <- tryCatch(readRDS(full_path), error = function(e) NULL)
    if (is.null(tt)) {
      next
    }

    updated <- magnemite_assign_actual_times(tt)
    out_path <- file.path(output_dir, file)
    saveRDS(updated, out_path)
    written <- c(written, out_path)
  }

  invisible(written)
}

magnemite_adjust_actual_times <- function(tt, trace = c("top", "bot", "both"), direction = c("<-", "->"), amount = 1) {
  trace <- match.arg(trace)
  direction <- match.arg(direction)

  adjust_vector <- function(times) {
    numeric_times <- as.numeric(sub(":00", "", times))

    if (direction == "<-") {
      numeric_times <- numeric_times + amount
    } else {
      numeric_times <- numeric_times - amount
    }

    numeric_times[numeric_times == 24] <- 0
    numeric_times <- (numeric_times + 24) %% 24
    sprintf("%02d:00", numeric_times)
  }

  if (trace %in% c("top", "both") && !is.null(tt[[2]]) && !is.null(tt[[2]]$actual_time)) {
    tt[[2]]$actual_time <- adjust_vector(tt[[2]]$actual_time)
  }

  if (trace %in% c("bot", "both") && !is.null(tt[[1]]) && !is.null(tt[[1]]$actual_time)) {
    tt[[1]]$actual_time <- adjust_vector(tt[[1]]$actual_time)
  }

  tt
}

magnemite_apply_time_adjustments <- function(rds_files, adjustments) {
  for (date_key in names(adjustments)) {
    matched_file <- rds_files[sapply(rds_files, function(file) {
      match <- regmatches(file, regexpr("D-\\d{8}", file))
      if (length(match) > 0) {
        extracted_date <- sub("D-", "", match)
        return(extracted_date == date_key)
      }
      FALSE
    })]

    if (length(matched_file) == 0) {
      next
    }

    tt <- readRDS(matched_file[1])
    adj <- adjustments[[date_key]]

    direction <- substr(adj[["direction"]], 1, 2)
    amount <- as.numeric(substr(adj[["direction"]], 4, 4))
    trace <- adj[["trace"]]

    tt <- magnemite_adjust_actual_times(tt, trace = trace, direction = direction, amount = amount)
    saveRDS(tt, matched_file[1])
  }

  invisible(TRUE)
}

magnemite_build_midnight_curves <- function(data_files, center_value = 638) {
  time_vec <- c()
  data_vec <- c()

  for (file in data_files) {
    data <- readRDS(file)

    if (!is.null(data$BotTimeSeq)) {
      time_vec <- c(time_vec, data$BotTimeSeq)
    }
    if (!is.null(data$TopTimeSeq)) {
      time_vec <- c(time_vec, data$TopTimeSeq)
    }
  }

  for (i in seq_along(data_files)) {
    data <- readRDS(data_files[i])

    if (i == 1) {
      data_vec <- c(data_vec, data$BottomTraceMatrix)
      final_val <- tail(data$BottomTraceMatrix, 1)
      adj_val <- data$TopTraceMatrix[1] - final_val
      new_first <- data$TopTraceMatrix - adj_val
      data_vec <- c(data_vec, new_first)
    } else {
      if (!is.null(data$BotTimeSeq)) {
        adj_val <- data$BottomTraceMatrix[1] - center_value
        data_vec <- c(data_vec, data$BottomTraceMatrix - adj_val)
      }
      if (!is.null(data$TopTimeSeq)) {
        adj_val <- data$TopTraceMatrix[1] - center_value
        data_vec <- c(data_vec, data$TopTraceMatrix - adj_val)
      }
    }
  }

  oop <- stats::na.omit(time_vec)
  time_stops <- which(oop == 0)
  mid_mid <- list()

  if (length(time_stops) < 2) {
    return(mid_mid)
  }

  for (i in 1:(length(time_stops) - 1)) {
    time <- oop[time_stops[i]:(time_stops[i + 1] - 1)]
    data <- data_vec[time_stops[i]:(time_stops[i + 1] - 1)]
    mid_mid[[i]] <- data.frame(x = time, y = data)
  }

  mid_mid
}
