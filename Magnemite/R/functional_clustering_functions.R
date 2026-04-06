# Reusable functions migrated from Nosepass/Functional_Clustering notebooks.

#' Resolve Functional Clustering Paths
#'
#' Resolves source, attempts, output, and timing tick paths used by functional
#' clustering workflows.
#'
#' @param server_dir Optional server source directory override.
#' @param attempts_dir Optional attempts directory override.
#' @param output_dir Optional output directory override.
#'
#' @return A list of normalized path settings.
#' @noRd
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

#' List Trace RDS Files
#'
#' List Timing-Trace RDS Files
#'
#' Lists timing-trace RDS files in a directory and optionally removes records
#' whose normalized base names appear in an exclusion list.
#'
#' The matching key is the file name with the `.rds` or `.RDS` extension
#' removed, followed by removal of `.tif-Digitized` or
#' `.tif-FailToProcess`. This makes it easier to exclude files using the core
#' magnetogram identifier rather than the exact on-disk suffix.
#'
#' @param server_dir Directory containing timing-trace RDS files.
#' @param exclude_base_names Character vector of normalized base names to
#'   exclude after suffix cleanup.
#'
#' @return A character vector of matching RDS file paths.
#'
#' @examples
#' tmp <- tempdir()
#' files <- c(
#'   "AGC-D-19020101.tif-Digitized.rds",
#'   "AGC-D-19020102.tif-FailToProcess.rds"
#' )
#' file.create(file.path(tmp, files))
#' list_tick_rds(tmp)
#' list_tick_rds(tmp, exclude_base_names = "AGC-D-19020102")
#' @export
list_tick_rds <- function(server_dir, exclude_base_names = character()) {
  data_files <- list.files(server_dir, pattern = "\\.RDS$|\\.rds$", full.names = TRUE)

  base_names <- sub("\\.RDS$|\\.rds$", "", basename(data_files))
  base_names <- sub("\\.tif-(Digitized|FailToProcess)$", "", base_names)

  keep <- !(base_names %in% exclude_base_names)
  data_files[keep]
}

#' Assign Actual Times to Timing Ticks
#'
#' Adds hourly `actual_time` labels to top and/or bottom timing tick tables.
#'
#' The function sorts each available `median_X` vector in ascending order before
#' generating times. A starting label of `12:00` is used for shorter traces and
#' `11:00` for longer traces so the assigned sequence matches the historical
#' workflows used in the original notebooks.
#'
#' @param tt A timing tick object stored as a two-element list, where `tt[[1]]`
#'   is the bottom trace table and `tt[[2]]` is the top trace table.
#' @param min_length Minimum sequence length used when building the candidate
#'   hourly time vector.
#'
#' @return The updated timing tick object, with an `actual_time` column added to
#'   each available trace table.
#'
#' @examples
#' tt <- list(
#'   data.frame(Cluster = 1:3, median_X = c(30, 10, 20)),
#'   data.frame(Cluster = 1:2, median_X = c(40, 15))
#' )
#' assign_times(tt)
#' @export
assign_times <- function(tt, min_length = 25) {
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

#' Batch Assign Actual Times
#'
#' Reads timing tick RDS files, assigns actual times, and writes updated files
#' to an output directory.
#'
#' This is a batch wrapper around [assign_times()]. Files that fail to read are
#' skipped silently, and successfully processed files are written to
#' `output_dir` using the same file names.
#'
#' @param input_dir Directory containing input timing tick RDS files.
#' @param output_dir Directory for updated output files.
#' @param include_files Optional explicit character vector of file names to
#'   process. When `NULL`, all files in `input_dir` are considered.
#' @param exclude_files Character vector of file names to skip.
#'
#' @return A character vector of written output file paths, returned invisibly.
#'
#' @examples
#' input_dir <- tempfile("input")
#' output_dir <- tempfile("output")
#' dir.create(input_dir)
#' saveRDS(list(data.frame(Cluster = 1, median_X = 10), NULL), file.path(input_dir, "sample.rds"))
#' assign_times_batch(input_dir, output_dir)
#' @export
assign_times_batch <- function(
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

    updated <- assign_times(tt)
    out_path <- file.path(output_dir, file)
    saveRDS(updated, out_path)
    written <- c(written, out_path)
  }

  invisible(written)
}

#' Adjust Assigned Actual Times
#'
#' Shifts assigned `actual_time` values for top, bottom, or both traces by a
#' specified direction and amount.
#'
#' The direction convention follows the legacy workflow. Choosing `"<-"`
#' increases the underlying hour labels, while `"->"` decreases them. Values
#' are wrapped modulo 24 so the result always stays in `HH:00` format.
#'
#' @param tt Timing tick object produced by [assign_times()] or read from a
#'   timing tick RDS file.
#' @param trace Which trace(s) to adjust: `"top"`, `"bot"`, or `"both"`.
#' @param direction Shift direction: `"<-"` or `"->"`.
#' @param amount Integer number of hours to shift.
#'
#' @return The updated timing tick object.
#'
#' @examples
#' tt <- list(
#'   data.frame(actual_time = c("12:00", "13:00")),
#'   data.frame(actual_time = c("14:00", "15:00"))
#' )
#' adjust_times(tt, trace = "both", direction = "<-", amount = 1)
#' @export
adjust_times <- function(tt, trace = c("top", "bot", "both"), direction = c("<-", "->"), amount = 1) {
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

#' Apply Date-Based Time Adjustments
#'
#' Applies manual date-keyed time adjustments to matching RDS files.
#'
#' `adjustments` should be a named list keyed by dates in `YYYYMMDD` format.
#' Each entry is expected to contain at least `trace` and `direction`, where
#' `direction` stores both the arrow and hour amount, for example `"<- 2"` or
#' `"-> 1"`.
#'
#' @param rds_files Character vector of RDS file paths.
#' @param adjustments Named list of adjustment definitions by date key.
#'
#' @return `TRUE`, invisibly, after applying all matching adjustments.
#'
#' @seealso [adjust_times()]
#' @export
apply_adjustments <- function(rds_files, adjustments) {
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

    tt <- adjust_times(tt, trace = trace, direction = direction, amount = amount)
    saveRDS(tt, matched_file[1])
  }

  invisible(TRUE)
}

#' Build Midnight Curves
#'
#' Builds midnight-segmented curve data from a sequence of trace RDS files.
#'
#' The function concatenates available top and bottom time sequences, aligns the
#' associated trace values, and then splits the combined series into intervals
#' bounded by occurrences of `0` in the time vector. Each interval is returned
#' as a data frame with `x` and `y` columns for downstream plotting or model
#' fitting.
#'
#' @param data_files Character vector of trace RDS file paths.
#' @param center_value Reference value used to align all files after the first
#'   file in the sequence.
#'
#' @return A list of data frames with `x` and `y` columns, one per detected
#'   midnight-to-midnight segment.
#' @export
midnight_curves <- function(data_files, center_value = 638) {
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
