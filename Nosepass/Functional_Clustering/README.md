# Functional_Clustering

Functional-data and time-assignment workflows for magnetogram traces.

## Contents
- `HoursToData.Rmd`: Builds/adjusts timing information linked to digitized traces.
- `Final_HoursToData.Rmd`: Refined timing-sequence assignment pipeline.
- `FunctionalClustering.Rmd`: Functional clustering and visualization of trace curves.

## Path Configuration
Hardcoded user-specific paths were replaced with configurable variables:

- `MAGNETO_SERVER_DIR` (default: `D:/SERVER/1902`)
- `MAGNETO_ATTEMPTS_DIR` (default: `<current working directory>/Attempts`)
- `MAGNETO_OUTPUT_DIR` (default: `<current working directory>/output`)

## Outputs
Depending on script section:
- Updated `.rds` timing assignments written to attempts or source directories.
- Figures exported to `MAGNETO_OUTPUT_DIR`.

## Notes
These are research-oriented notebooks with multiple exploratory sections. Run sections selectively when reproducing prior analyses.
