# View_TT

Visualization and QA tools for timing ticks and trace overlays.

## Contents
- `TT_asImages.Rmd`: Batch rendering of images with trace/timing overlays.
- `BrushClust/`: Shiny app for clustered brush-based timing tick detection.
- `Timing_Tick_Click/`: Shiny app for manual timing tick correction.
- `plotting_attempts/`: Experimental plotting notebooks.

## Path Configuration
Scripts in this folder now use configurable directories:

- `MAGNETO_SERVER_DIR` (default: `D:/SERVER/1902`)
- `MAGNETO_TT_IMAGES_DIR` (default: `<current working directory>/TTimages`)
- `MAGNETO_OUTPUT_DIR` (default: `<current working directory>/output`)

## Typical Data Layout
- Magnetograms and digitized trace files under `MAGNETO_SERVER_DIR`
- Timing tick files under `MAGNETO_SERVER_DIR/TimingTicks`

## Notes
Some scripts are exploratory and may assume specific data completeness for both top and bottom traces.
