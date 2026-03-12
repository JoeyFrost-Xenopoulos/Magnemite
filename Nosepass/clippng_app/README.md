# Clippng App (Reproducible)

This folder contains a reproducible copy of the original Clippng Shiny app.

Included:
- app.R (from Clippng, adapted for portable paths)

Not included:
- anything from FixClippng

## What this app does

The app loads magnetogram images and existing RDS trace objects, lets you click start/end clip points for top and bottom traces, and writes clipped trace coordinates to CSV.

Clipping flow:
1. Top trace start
2. Top trace end
3. Bottom trace start
4. Bottom trace end
5. Save clipped traces to CSV

## Reproducible path behavior

This app no longer depends on machine-specific paths like C:/sqlite or Desktop folders.

Default behavior if no environment variables are set:
- Project directory: D:/Nosepass/clippng
- Database path: D:/Nosepass/clippng/data/magnet.db
- CSV output directory: D:/Nosepass/clippng/clipped_traces

In the app UI, you can specify a custom output directory before starting clipping. Leave it blank to use the default.

## Optional environment variables

Set these if your data lives elsewhere or to override defaults:
- NOSEPASS_CLIPPNG_PROJECT_DIR (overrides D:/Nosepass/clippng default)
- NOSEPASS_CLIPPNG_DB (overrides project_dir/data/magnet.db)
- NOSEPASS_CLIPPNG_OUTPUT_DIR (overrides project_dir/clipped_traces; must be set before app launch)

You can also specify a custom output directory in the app UI (optional field, appears before "Start Clipping").

## Required database table

The app expects SQLite table file_list with at least:
- FileName
- year
- Path

Path should point to image files without the .png suffix (the app appends .png).

## Run

From repository root:

```powershell
Rscript -e "shiny::runApp('Nosepass/clippng_app')"
```

Or from inside clippng_app:

```powershell
Rscript -e "shiny::runApp('.')"
```
