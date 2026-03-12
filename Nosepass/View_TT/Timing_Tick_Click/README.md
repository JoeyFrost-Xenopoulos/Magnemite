# Timing_Tick_Click

Manual QA/correction Shiny app for timing tick positions.

## File
- `app.R`: Displays selected image and current timing ticks, allows click-to-add points, then writes back updated timing tick `.rds`.

## Path Configuration
- `MAGNETO_SERVER_DIR` (default: `D:/SERVER/1902`)

Reads/writes timing tick files at:
- `<MAGNETO_SERVER_DIR>/TimingTicks/<base_name>.rds`

## Run
From this directory in R:

```r
shiny::runApp("app.R")
```
