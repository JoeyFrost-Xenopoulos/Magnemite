# magnemite

`magnemite` is an R package for historical analog magnetogram curation and timing-tick processing.

The package workflow is:

1. Clip top and bottom traces from digitized records.
2. Write clipped coordinates back to digitized RDS files.
3. Generate first-pass timing ticks with clustering.
4. Manually correct timing ticks.
5. Assign and adjust clock times.
6. Build midnight-segmented curves for downstream analysis.

## Installation

From a local checkout:

```r
install.packages(".", repos = NULL, type = "source")
```

For development work:

```r
devtools::load_all()
```

## Quick Start

### 1. Clip traces

Use the clipping app to set start/end bounds for top and bottom traces.

```r
magnemite::clippng_app()
```

Output CSV columns:

- `top_x`, `top_y`
- `bottom_x`, `bottom_y`

### 2. Apply clipped CSV output to RDS

Single file:

```r
magnemite::apply_clipped_csv(
  csv_path = "D:/Magnemite_Out/data/clipped_traces/AGC-D-19020102-19020104.tif_clipped_traces.csv",
  rds_path = "D:/SERVER/1902/AGC-D-19020102-19020104.tif-Digitized.rds"
)
```

Batch mode:

```r
magnemite::apply_clipped_csv_batch(
  clipped_csv_dir = "D:/Magnemite_Out/data/clipped_traces",
  server_dir = "D:/SERVER"
)
```

### 3. Create first-pass timing ticks

```r
magnemite::brushclust_app()
```

### 4. Manually correct timing ticks

```r
magnemite::tick_click_app()
```

### 5. Assign and adjust times

```r
tt <- readRDS("D:/Magnemite_Out/data/timing_ticks/AGC-D-19020102-19020104.rds")
tt <- magnemite::assign_times(tt)
tt <- magnemite::adjust_times(tt, trace = "both", direction = "<-", amount = 1)
saveRDS(tt, "D:/Magnemite_Out/data/Attempts/AGC-D-19020102-19020104.rds")
```

Batch assignment:

```r
magnemite::assign_times_batch(
  input_dir = "D:/Magnemite_Out/data/timing_ticks",
  output_dir = "D:/Magnemite_Out/data/Attempts"
)
```

### 6. Build midnight curves

```r
files <- magnemite::list_tick_rds("D:/Magnemite_Out/data/Attempts")
curves <- magnemite::midnight_curves(files)
```

## Path Defaults

- Output root: `MAGNEMITE_OUTPUT_DIR` or `D:/Magnemite_Out`
- Server root: `MAGNEMITE_SERVER_DIR` or `NOSEPASS_SERVER_DIR`, then `D:/SERVER`
- Clipped CSV directory: `<output_root>/data/clipped_traces`
- Timing tick directory: `<output_root>/data/timing_ticks`
- Recommended assigned-time directory: `<output_root>/data/Attempts`

To make runs portable across machines:

```r
Sys.setenv(
  MAGNEMITE_OUTPUT_DIR = "D:/Magnemite_Out",
  MAGNEMITE_SERVER_DIR = "D:/SERVER"
)
```

## Function Reference

Apps:

- `clippng_app()`
- `brushclust_app()`
- `tick_click_app()`

Trace update:

- `apply_clipped_csv()`
- `apply_clipped_csv_batch()`

Timing assignment:

- `assign_times()`
- `assign_times_batch()`
- `adjust_times()`
- `apply_adjustments()`

Downstream curves:

- `list_tick_rds()`
- `midnight_curves()`

## Vignette

For a fuller workflow walkthrough, see the package vignette:

```r
vignette("magnemite-workflow", package = "magnemite")
```

