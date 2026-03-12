# BrushClust

Interactive Shiny app for brush-based clustering and extraction of timing tick X positions.

## File
- `app.R`: Loads `.tif` images and corresponding digitized `.rds`, supports brushing candidate timing points, and saves tick results.

## Path Configuration
- `MAGNETO_SERVER_DIR` (default: `D:/SERVER/1902`)
- `MAGNETO_OUTPUT_DIR` (default: `<current working directory>/output`)

Saved timing tick files are written to:
- `<MAGNETO_SERVER_DIR>/TimingTicks/<base_name>.rds`

## Run
From this directory in R:

```r
shiny::runApp("app.R")
```
