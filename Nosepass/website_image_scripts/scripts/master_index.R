library(jsonlite)
script_ofile <- tryCatch(sys.frame(1)$ofile, error = function(e) NA_character_)
script_dir <- if (!is.na(script_ofile) && nzchar(script_ofile)) {
  dirname(normalizePath(script_ofile, mustWork = FALSE))
} else if (basename(normalizePath(getwd(), mustWork = FALSE)) == "scripts") {
  normalizePath(getwd(), mustWork = FALSE)
} else {
  file.path(normalizePath(getwd(), mustWork = FALSE), "scripts")
}
source(file.path(script_dir, "path_helpers.R"))

args <- commandArgs(trailingOnly = TRUE)
custom_output_dir <- if (length(args) > 0) args[1] else NULL
if (is.na(custom_output_dir)) custom_output_dir <- NULL

paths <- get_paths(custom_output_dir)
root_dir <- paths$server_dir
master_index_path <- file.path(paths$indexes_dir, "master-index.json")

if (!dir.exists(root_dir)) {
  stop("Server directory not found: ", root_dir)
}
dir.create(paths$indexes_dir, recursive = TRUE, showWarnings = FALSE)

# Get list of year directories
year_dirs <- get_year_dirs(root_dir)

# Initialize list for master index
master_index <- list()

# Loop over each year directory
for (dir in year_dirs) {
  # Extract the year from the directory name
  year <- basename(dir)
  
  # Get list of .png files
  png_files <- list.files(dir, pattern = "\\.png$", full.names = FALSE, ignore.case = TRUE)
  
  # Exclude files with "-FailToProcess" or "-Plot" in the name
  png_files <- png_files[!grepl("-FailToProcess|-Plot", png_files, ignore.case = TRUE)]
  
  # Create path to per-year index.json file
  index_path <- file.path(dir, "index.json")
  
  # Write per-year JSON file
  write(toJSON(png_files, pretty = TRUE, auto_unbox = TRUE), index_path)
  cat("Wrote", index_path, "with", length(png_files), "images\n")
  
  # Add to master index
  master_index[[year]] <- png_files
}

# Write master index to desktop
write(toJSON(master_index, pretty = TRUE, auto_unbox = TRUE), master_index_path)
cat("Master index saved to", master_index_path, "with", length(master_index), "years\n")
