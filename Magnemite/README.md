# Magnemite

Workflows for historical magnetogram processing, manual curation, and time-series preparation. Provides reproducible path helpers, web asset and index generation, Shiny apps for clipping and timing tick correction, and reusable preprocessing and functional clustering utilities migrated from legacy analysis notebooks.

## Workflow Overview

Magnemite is organized as a reproducible function pipeline:

1. Resolve paths and defaults through package helpers (no hardcoded local paths required).
2. Build or refresh web-facing image assets and indexes.
3. Run clipping and timing tick apps for manual curation.
4. Run preprocessing and functional clustering functions for analysis-ready outputs.
5. Use script wrappers in `inst/scripts` only as temporary entrypoints while migrating legacy workflows.

## Function Map

### Path and default resolution

- `magnemite_paths()`: Resolve server/output roots and derived web asset directories.
- `magnemite_year_dirs()`: Detect year-named subdirectories under a root.
- `magnemite_default_output_root()`: Resolve the package-wide output root.
- `magnemite_find_package_file()`: Find bundled package files (installed or local dev tree).
- `magnemite_default_clippng_project_dir()`: Resolve default clipping project directory.
- `magnemite_default_clippng_db()`: Resolve default clipping database path.
- `magnemite_clippng_paths()`: Resolve clipping app project/db/output paths.
- `magnemite_timing_ticks_paths()`: Resolve timing tick source, tick RDS, and output directories.
- `magnemite_preprocessing_paths()`: Resolve preprocessing source and timing tick directories.
- `magnemite_functional_paths()`: Resolve functional clustering source, attempts, and output paths.

### Web asset generation

- `magnemite_process_fullsize_images()`: Normalize and export full-size magnetogram PNG assets by year.
- `magnemite_process_thumbnail_images()`: Create representative per-year thumbnails.
- `magnemite_write_master_index()`: Write year-level `index.json` and package `master-index.json`.
- `magnemite_write_rds_index()`: Build JSON mapping of RDS trace files to corresponding images.
- `magnemite_write_rds_overlays()`: Render transparent line overlays from digitized traces.
- `magnemite_copy_rds_assets()`: Copy RDS trace files into output asset directories.
- `magnemite_write_trace_csv_assets()`: Export top/bottom traces into CSV assets.
- `magnemite_build_web_trace_assets()`: Run overlay, RDS copy, and CSV export as one pipeline.

### Clipping app

- `magnemite_clippng_app()`: Build the clipping Shiny app object.
- `run_magnemite_clippng_app()`: Launch the clipping app.

### Timing tick workflow

- `magnemite_list_tif_files()`: List source `.tif` files for timing tick workflows.
- `magnemite_find_digitized_rds()`: Find matching digitized/failed RDS for a `.tif`.
- `magnemite_timing_tick_rds_path()`: Build the timing tick output RDS path for an image.
- `magnemite_process_trace_cluster()`: Run clustering on a trace region from image pixels.
- `magnemite_process_bottom_trace_cluster()`: Bottom-trace clustering wrapper.
- `magnemite_process_top_trace_cluster()`: Top-trace clustering wrapper.
- `magnemite_cluster_region_medians()`: Compute median x-position per clustered region.
- `magnemite_brushclust_app()`: Build the BrushClust app for timing tick brushing.
- `run_magnemite_brushclust_app()`: Launch the BrushClust app.
- `magnemite_timing_tick_click_app()`: Build manual click-correction app for timing ticks.
- `run_magnemite_timing_tick_click_app()`: Launch manual click-correction app.

### Preprocessing and clustering helpers

- `magnemite_load_trace_bundle()`: Load image + digitized trace + timing tick bundle by base name.
- `magnemite_kmeans_trace_clusters()`: Extract trace clusters from image matrix values with k-means.
- `magnemite_trace_medians_by_x()`: Summarize trace y values by x median.
- `magnemite_plot_traces_with_ticks()`: Plot image traces and timing tick markers together.
- `magnemite_list_trace_rds_files()`: List and optionally filter trace RDS files.
- `magnemite_assign_actual_times()`: Add hourly time labels to timing tick objects.
- `magnemite_assign_actual_times_batch()`: Batch-assign actual times to timing tick RDS files.
- `magnemite_adjust_actual_times()`: Shift assigned times by direction and amount.
- `magnemite_apply_time_adjustments()`: Apply date-specific manual adjustments across files.
- `magnemite_build_midnight_curves()`: Build midnight-aligned curve segments from trace files.

## Environment variables

Magnemite supports the following variables:

- `MAGNEMITE_SERVER_DIR`
- `MAGNEMITE_OUTPUT_DIR`
- `MAGNEMITE_CLIPPNG_PROJECT_DIR`
- `MAGNEMITE_CLIPPNG_DB`
- `MAGNEMITE_CLIPPNG_OUTPUT_DIR`

For compatibility with existing Nosepass setup, fallback values are read from:

- `NOSEPASS_SERVER_DIR`
- `NOSEPASS_OUTPUT_DIR`
- `NOSEPASS_CLIPPNG_PROJECT_DIR`
- `NOSEPASS_CLIPPNG_DB`
- `NOSEPASS_CLIPPNG_OUTPUT_DIR`

Default Magnemite output root is `D:/Magnemite_Out` when no env var or explicit argument is provided.
For the clipping app, a bundled database at `data/magnet.db` is used by default when available.

## Script wrappers

Temporary wrappers are included under `inst/scripts`:

- `inst/scripts/image_resize.R`
- `inst/scripts/thumbnail_resize.R`
- `inst/scripts/master_index.R`
- `inst/scripts/rds_index.R`
- `inst/scripts/overlay_assets.R`
- `inst/scripts/run_clippng_app.R`
- `inst/scripts/run_brushclust_app.R`
- `inst/scripts/run_timing_tick_click_app.R`
- `inst/scripts/assign_actual_times_batch.R`
- `inst/scripts/plot_trace_bundle.R`

These wrappers call package functions and make it easier to transition existing workflows.

## Using the clipping app

From an R session after installing or loading the package:

```r
Magnemite::run_magnemite_clippng_app()
```

If `data/magnet.db` is present in the package, that bundled database is used automatically.

You can also override paths explicitly:

```r
Magnemite::run_magnemite_clippng_app(
  project_dir = "D:/Nosepass/clippng",
  db_path = "D:/Nosepass/clippng/data/magnet.db",
  output_dir = "D:/Magnemite_Out/data/clipped_traces"
)
```

App flow:

1. Select a year and image.
2. Check `Start Clipping`.
3. Click top trace start, then top trace end.
4. Click bottom trace start, then bottom trace end.
5. Save the clipped CSV.

By default, clipped CSV files now write to `D:/Magnemite_Out/data/clipped_traces`.

Other package outputs use the same root by default, for example:

- website assets under `D:/Magnemite_Out/assets`
- indexes under `D:/Magnemite_Out/indexes`
- clipping CSVs under `D:/Magnemite_Out/data/clipped_traces`
- timing tick app outputs under `D:/Magnemite_Out/data/timing_ticks`

## Using the timing tick apps

From an R session after installing or loading the package:

```r
Magnemite::run_magnemite_brushclust_app()
Magnemite::run_magnemite_timing_tick_click_app()
```

These are packaged functions and do not require sourcing external scripts.
They still require access to the underlying `.tif`, digitized `.rds`, and timing tick `.rds` files.
By default they look for source data via `MAGNEMITE_SERVER_DIR` or `NOSEPASS_SERVER_DIR`, falling back to `D:/SERVER/1902`.

## Notebook Migration Notes

The notebook migrations prioritize stable reusable logic and batch operations.
Exploratory plotting and one-off experimental chunks were intentionally left out of package APIs.

## Suggested migration pattern

1. Identify reusable pure logic in script.
2. Move logic into `R/` function(s) with explicit arguments.
3. Keep temporary script wrapper in `inst/scripts` that calls the function.
4. Add tests after each migration batch.
