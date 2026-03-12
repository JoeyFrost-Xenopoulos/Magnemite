# Magnemite

Magnemite is an R package for historical analog magnetogram timing tick processing:

1. Clip traces from digitized (.rds) files
2. Write clipped traces back into RDS
3. Detect timing ticks (BrushClust)
4. Manually correct timing ticks (Click app)
5. Convert timing ticks to clock times

## Core Pipeline

### 1) Clip traces

```r
Magnemite::clippng_app()
```

This app saves clipped CSV files to:

- `D:/Magnemite_Out/data/clipped_traces` (default)

Each CSV contains:

- `top_x`, `top_y`
- `bottom_x`, `bottom_y`

### 2) Apply clipped CSVs back to digitized RDS

Single file:

```r
Magnemite::apply_clipped_csv(
	csv_path = "D:/Magnemite_Out/data/clipped_traces/AGC-D-19020102-19020104.tif_clipped_traces.csv",
	rds_path = "D:/SERVER/1902/AGC-D-19020102-19020104.tif-Digitized.rds"
)
```

Batch mode:

```r
Magnemite::apply_clipped_csv_batch(
	clipped_csv_dir = "D:/Magnemite_Out/data/clipped_traces",
	server_dir = "D:/SERVER"
)
```

`apply_clipped_csv_batch()` scans recursively and matches CSVs to either:

- `*.tif-Digitized.rds`
- `*.tif-FailToProcess.rds`
- `*.tif-FailToProcess-Data.rds`

### 3) Create first-pass timing ticks

```r
Magnemite::brushclust_app()
```

BrushClust writes timing tick RDS files to:

- `D:/Magnemite_Out/data/timing_ticks` (default)

### 4) Manually correct timing ticks

```r
Magnemite::tick_click_app()
```

The click app reads/writes the same timing tick directory by default, so no extra path wiring is needed after BrushClust.

### 5) Assign clock times

Single object:

```r
tt <- readRDS("D:/Magnemite_Out/data/timing_ticks/AGC-D-19020102-19020104.rds")
tt <- Magnemite::assign_times(tt)
saveRDS(tt, "D:/Magnemite_Out/data/Attempts/AGC-D-19020102-19020104.rds")
```

Batch:

```r
Magnemite::assign_times_batch(
	input_dir = "D:/Magnemite_Out/data/timing_ticks",
	output_dir = "D:/Magnemite_Out/data/Attempts"
)
```

Optional manual adjustments:

```r
rds_files <- list.files("D:/Magnemite_Out/data/Attempts", pattern = "\\.rds$", full.names = TRUE)

Magnemite::apply_adjustments(
	rds_files,
	adjustments = list(
		"19020102" = list(trace = "both", direction = "<- 1")
	)
)
```

### 6) Build midnight curves

```r
files <- Magnemite::list_tick_rds("D:/Magnemite_Out/data/Attempts")
curves <- Magnemite::midnight_curves(files)
```

## Default Path Behavior

- Output root: `MAGNEMITE_OUTPUT_DIR` or `D:/Magnemite_Out`
- Server root: `MAGNEMITE_SERVER_DIR` or `NOSEPASS_SERVER_DIR`, then `D:/SERVER`
- Clipped CSV output: `<output_root>/data/clipped_traces`
- Timing tick output/input: `<output_root>/data/timing_ticks`
- Time-assigned output (recommended): `<output_root>/data/Attempts`

## Exported User Functions

Apps:

- `clippng_app()`
- `brushclust_app()`
- `tick_click_app()`

Trace update:

- `apply_clipped_csv()`
- `apply_clipped_csv_batch()`

Timing tick to time:

- `assign_times()`
- `assign_times_batch()`
- `adjust_times()`
- `apply_adjustments()`

Downstream curves:

- `list_tick_rds()`
- `midnight_curves()`

