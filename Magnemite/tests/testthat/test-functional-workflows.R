test_that("list_tick_rds excludes normalized base names", {
  tmp <- tempfile("tick-rds-")
  dir.create(tmp)

  files <- c(
    "AGC-D-19020101.tif-Digitized.rds",
    "AGC-D-19020102.tif-FailToProcess.rds",
    "notes.txt"
  )
  file.create(file.path(tmp, files))

  listed <- list_tick_rds(tmp)
  expect_length(listed, 2)
  expect_true(all(grepl("\\.rds$", listed, ignore.case = TRUE)))

  filtered <- list_tick_rds(tmp, exclude_base_names = "AGC-D-19020102")
  expect_length(filtered, 1)
  expect_match(basename(filtered), "19020101")
})

test_that("assign_times sorts median_X and adds actual_time labels", {
  tt <- list(
    data.frame(Cluster = 1:3, median_X = c(30, 10, 20)),
    data.frame(Cluster = 1:2, median_X = c(40, 15))
  )

  updated <- assign_times(tt)

  expect_equal(updated[[1]]$median_X, c(10, 20, 30))
  expect_equal(updated[[2]]$median_X, c(15, 40))
  expect_equal(updated[[1]]$actual_time, c("12:00", "13:00", "14:00"))
  expect_equal(updated[[2]]$actual_time, c("12:00", "13:00"))
})

test_that("assign_times_batch writes processed files", {
  input_dir <- tempfile("timing-input-")
  output_dir <- tempfile("timing-output-")
  dir.create(input_dir)

  saveRDS(
    list(data.frame(Cluster = 1:2, median_X = c(9, 3)), NULL),
    file.path(input_dir, "sample.rds")
  )
  saveRDS(
    list(data.frame(Cluster = 1, median_X = 5), NULL),
    file.path(input_dir, "skip-me.rds")
  )

  written <- assign_times_batch(
    input_dir = input_dir,
    output_dir = output_dir,
    exclude_files = "skip-me.rds"
  )

  expect_length(written, 1)
  expect_true(file.exists(file.path(output_dir, "sample.rds")))
  expect_false(file.exists(file.path(output_dir, "skip-me.rds")))

  saved <- readRDS(file.path(output_dir, "sample.rds"))
  expect_equal(saved[[1]]$median_X, c(3, 9))
  expect_equal(saved[[1]]$actual_time, c("12:00", "13:00"))
})

test_that("adjust_times shifts hours and wraps around midnight", {
  tt <- list(
    data.frame(actual_time = c("23:00", "00:00")),
    data.frame(actual_time = c("01:00", "02:00"))
  )

  shifted_left <- adjust_times(tt, trace = "both", direction = "<-", amount = 1)
  expect_equal(shifted_left[[1]]$actual_time, c("00:00", "01:00"))
  expect_equal(shifted_left[[2]]$actual_time, c("02:00", "03:00"))

  shifted_right <- adjust_times(tt, trace = "top", direction = "->", amount = 2)
  expect_equal(shifted_right[[1]]$actual_time, c("23:00", "00:00"))
  expect_equal(shifted_right[[2]]$actual_time, c("23:00", "00:00"))
})

test_that("apply_adjustments updates matching files only", {
  tmp <- tempfile("adjustments-")
  dir.create(tmp)

  match_path <- file.path(tmp, "AGC-D-20200101-20200102.rds")
  other_path <- file.path(tmp, "AGC-D-20200103-20200104.rds")
  tt <- list(
    data.frame(actual_time = c("12:00", "13:00")),
    data.frame(actual_time = c("14:00", "15:00"))
  )
  saveRDS(tt, match_path)
  saveRDS(tt, other_path)

  result <- apply_adjustments(
    rds_files = c(match_path, other_path),
    adjustments = list("20200101" = list(trace = "both", direction = "<- 2"))
  )

  expect_true(isTRUE(result))
  expect_equal(readRDS(match_path)[[1]]$actual_time, c("14:00", "15:00"))
  expect_equal(readRDS(other_path)[[1]]$actual_time, c("12:00", "13:00"))
})

test_that("midnight_curves splits the combined series at midnight markers", {
  tmp <- tempfile("curves-")
  dir.create(tmp)

  rds_path <- file.path(tmp, "curve.rds")
  saveRDS(
    list(
      BotTimeSeq = c(0, 1),
      TopTimeSeq = c(2, 0),
      BottomTraceMatrix = c(5, 7),
      TopTraceMatrix = c(11, 13)
    ),
    rds_path
  )

  curves <- midnight_curves(rds_path)

  expect_length(curves, 1)
  expect_equal(curves[[1]]$x, c(0, 1, 2))
  expect_equal(curves[[1]]$y, c(5, 7, 7))
})