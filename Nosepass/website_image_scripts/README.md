# Website Image Scripts

These scripts build image and metadata assets for the Nosepass website in a reproducible way.

They now use portable defaults (D:/Nosepass base) and optional environment variables, so anyone can run them without editing hardcoded local paths.

If no environment variables are set, scripts use:
- Input server data: `D:/Nosepass/SERVER`
- Output root: `D:/Nosepass/output`

Expected output tree under `D:/Nosepass/output`:
- `assets/img/magnetograms/fullsize/<year>/`
- `assets/img/magnetograms/thumbnails/<year>/`
- `assets/img/magnetograms/rds_overlays/<year>/`
- `assets/img/magnetograms/rds/<year>/`
- `assets/img/magnetograms/csv/<year>/`
- `indexes/master-index.json`
- `indexes/rds-index.json`

## Optional environment variables and custom output

Override defaults with environment variables:
- `NOSEPASS_SERVER_DIR` (overrides D:/Nosepass/SERVER)
- `NOSEPASS_OUTPUT_DIR` (overrides D:/Nosepass/output)

Or pass a custom output directory as a command-line argument (R scripts only):

```powershell
Rscript scripts/image_resize.R "D:/custom/output/path"
Rscript scripts/thumbnail_resize.R "D:/custom/output/path"
Rscript scripts/master_index.R "D:/custom/output/path"
Rscript scripts/rds_index.R "D:/custom/output/path"
```

For the Rmd overlay script, use the `NOSEPASS_OUTPUT_DIR` environment variable:

```powershell
$env:NOSEPASS_OUTPUT_DIR="D:/custom/output/path"
Rscript -e "rmarkdown::render('scripts/overlay_script.Rmd')"
```

## Run commands

From `Nosepass/website_image_scripts` (uses D:/Nosepass defaults):

```powershell
Rscript scripts/image_resize.R
Rscript scripts/thumbnail_resize.R
Rscript scripts/master_index.R
Rscript scripts/rds_index.R
```

To specify a custom output directory, pass it as an argument:

```powershell
Rscript scripts/image_resize.R "D:/alternative/output"
Rscript scripts/thumbnail_resize.R "D:/alternative/output"
Rscript scripts/master_index.R "D:/alternative/output"
Rscript scripts/rds_index.R "D:/alternative/output"
```

For overlays/csv/rds copy:

```powershell
Rscript -e "rmarkdown::render('scripts/overlay_script.Rmd')"
```

## What each script does

### `scripts/image_resize.R`
- Reads valid PNGs by year from server data.
- Skips `-FailToProcess` and `-Plot` files.
- Rotates portrait images.
- Writes full-size PNGs by year.

### `scripts/thumbnail_resize.R`
- Reads valid PNGs by year.
- Uses first valid image per year.
- Rotates portrait images and resizes to `750x250`.
- Writes thumbnail PNGs by year.

### `scripts/master_index.R`
- Writes per-year `index.json` in each year directory.
- Builds one `master-index.json` under `output/indexes`.

### `scripts/rds_index.R`
- Scans year folders for RDS files.
- Maps each RDS filename to the related image filename.
- Writes `rds-index.json` under `output/indexes`.

### `scripts/overlay_script.Rmd`
- Creates line overlays from RDS traces.
- Copies RDS files into website-ready output folders.
- Creates CSV exports for top/bottom trace coordinates.

## What usually needs regeneration

If analysis or cleaned traces change, rerun overlays first:
- `scripts/overlay_script.Rmd`

Depending on the change, also rerun:
- `scripts/rds_index.R` (if RDS filenames/coverage changed)
- `scripts/master_index.R` (if source PNG set changed)

## Full refresh order

1. `scripts/image_resize.R`
2. `scripts/thumbnail_resize.R`
3. `scripts/master_index.R`
4. `scripts/overlay_script.Rmd`
5. `scripts/rds_index.R`

## Important behavior note

These scripts collectively run almost everything in this asset pipeline, unless downstream website build steps outside this folder are required.