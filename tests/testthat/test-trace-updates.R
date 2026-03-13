test_that("apply_clipped_csv updates trace matrices and bounds", {
  tmp <- tempfile("clip-update-")
  dir.create(tmp)

  csv_path <- file.path(tmp, "sample_clipped_traces.csv")
  rds_path <- file.path(tmp, "sample.tif-Digitized.rds")

  utils::write.csv(
    data.frame(
      top_x = c(130, 131, NA),
      top_y = c(100, 101, NA),
      bottom_x = c(140, 141, 142),
      bottom_y = c(120, 121, 122)
    ),
    csv_path,
    row.names = FALSE
  )

  saveRDS(
    list(
      TopTraceMatrix = numeric(),
      TopTraceStartEnds = list(Start = 0, End = 0),
      BottomTraceMatrix = numeric(),
      BottomTraceStartEnds = list(Start = 0, End = 0)
    ),
    rds_path
  )

  updated <- apply_clipped_csv(csv_path, rds_path)
  saved <- readRDS(rds_path)

  expect_equal(updated$TopTraceMatrix, c(4, 5))
  expect_equal(updated$TopTraceStartEnds$Start, 5)
  expect_equal(updated$TopTraceStartEnds$End, 6)
  expect_equal(saved$BottomTraceMatrix, c(24, 25, 26))
  expect_equal(saved$BottomTraceStartEnds$Start, 15)
  expect_equal(saved$BottomTraceStartEnds$End, 17)
})

test_that("apply_clipped_csv_batch prefers digitized files and updates matches", {
  tmp <- tempfile("clip-batch-")
  dir.create(tmp)
  clipped_dir <- file.path(tmp, "clipped")
  server_dir <- file.path(tmp, "server", "1902")
  dir.create(clipped_dir, recursive = TRUE)
  dir.create(server_dir, recursive = TRUE)

  csv_path <- file.path(clipped_dir, "AGC-D-19020102-19020104.tif_clipped_traces.csv")
  utils::write.csv(
    data.frame(
      top_x = c(126, 127),
      top_y = c(100, 102),
      bottom_x = c(130, 131),
      bottom_y = c(110, 111)
    ),
    csv_path,
    row.names = FALSE
  )

  digitized_path <- file.path(server_dir, "AGC-D-19020102-19020104.tif-Digitized.rds")
  failed_path <- file.path(server_dir, "AGC-D-19020102-19020104.tif-FailToProcess-Data.rds")
  blank_rds <- list(
    TopTraceMatrix = numeric(),
    TopTraceStartEnds = list(Start = 0, End = 0),
    BottomTraceMatrix = numeric(),
    BottomTraceStartEnds = list(Start = 0, End = 0)
  )
  saveRDS(blank_rds, digitized_path)
  saveRDS(blank_rds, failed_path)

  updated <- apply_clipped_csv_batch(clipped_csv_dir = clipped_dir, server_dir = file.path(tmp, "server"))

  expect_equal(
    normalizePath(updated, winslash = "/", mustWork = FALSE),
    normalizePath(digitized_path, winslash = "/", mustWork = FALSE)
  )
  expect_equal(readRDS(digitized_path)$TopTraceMatrix, c(4, 6))
  expect_equal(readRDS(failed_path)$TopTraceMatrix, numeric())
})