# Magnemite

Magnemite is the package workspace for migrating reusable logic out of Nosepass scripts into testable, documented R functions.

## Module Organization

The package is now organized by functional area using file naming in `R/`:

- `web_assets_*.R`: Website image/index/overlay asset workflows
- `clippng_app.R`: Interactive clipping app integration
- `timing_ticks_*.R`: Timing tick clustering and manual correction workflows
- `preprocessing_functions.R`: Reusable image/trace preprocessing helpers from notebook code
- `functional_clustering_functions.R`: Reusable time-assignment and midnight-curve helpers

## Migrated in current state

From Nosepass website image scripts:

- Image full-size processing
  - `magnemite_process_fullsize_images()`
- Image thumbnail processing
  - `magnemite_process_thumbnail_images()`
- Per-year and master image indexes
  - `magnemite_write_master_index()`
- RDS-to-image index JSON
  - `magnemite_write_rds_index()`
- Overlay and trace exports
  - `magnemite_write_rds_overlays()`
  - `magnemite_copy_rds_assets()`
  - `magnemite_write_trace_csv_assets()`
  - `magnemite_build_web_trace_assets()`
- Shared web asset path helpers
  - `magnemite_paths()`
  - `magnemite_year_dirs()`

From Nosepass clipping app:

- `magnemite_clippng_paths()`
- `magnemite_clippng_app()`
- `run_magnemite_clippng_app()`

From Nosepass timing tick tools:

- `magnemite_timing_ticks_paths()`
- `magnemite_process_bottom_trace_cluster()`
- `magnemite_process_top_trace_cluster()`
- `magnemite_cluster_region_medians()`
- `magnemite_brushclust_app()`
- `run_magnemite_brushclust_app()`
- `magnemite_timing_tick_click_app()`
- `run_magnemite_timing_tick_click_app()`

From Nosepass pre_Processing notebooks:

- `magnemite_preprocessing_paths()`
- `magnemite_load_trace_bundle()`
- `magnemite_kmeans_trace_clusters()`
- `magnemite_trace_medians_by_x()`
- `magnemite_plot_traces_with_ticks()`

From Nosepass Functional_Clustering notebooks:

- `magnemite_functional_paths()`
- `magnemite_list_trace_rds_files()`
- `magnemite_assign_actual_times()`
- `magnemite_assign_actual_times_batch()`
- `magnemite_adjust_actual_times()`
- `magnemite_apply_time_adjustments()`
- `magnemite_build_midnight_curves()`

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
