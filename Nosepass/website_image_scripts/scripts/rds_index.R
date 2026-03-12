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
rds_index_path <- file.path(paths$indexes_dir, "rds-index.json")

if (!dir.exists(root_dir)) {
  stop("Server directory not found: ", root_dir)
}
dir.create(paths$indexes_dir, recursive = TRUE, showWarnings = FALSE)

# Get list of year directories and filter out unwanted ones
year_dirs <- get_year_dirs(root_dir)

# Initialize master index list
rds_index <- list()

# Loop through each year directory
for (year_dir in year_dirs) {
  year <- basename(year_dir)
  
  # Get all .RDS files
  rds_files <- list.files(year_dir, pattern = "\\.RDS$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
  rds_files <- rds_files[!grepl("FailToProcess", rds_files, ignore.case = TRUE)]
  
  for (file in rds_files) {
    rds_filename <- basename(file)
    
    # Strip known suffixes to get base image name
    image_base <- gsub("(-Digitized|-FailToProcess-Data)?\\.RDS$", "", rds_filename, ignore.case = TRUE)
    
    # Convert .tif to .tif.png
    image_filename <- sub("\\.tif$", ".tif.png", image_base, ignore.case = TRUE)
    
    # Add entry
    rds_index <- append(rds_index, list(list(
      rds_file = rds_filename,
      image_file = image_filename,
      year = year
    )))
  }
}

# Write to JSON
write_json(rds_index, rds_index_path, pretty = TRUE, auto_unbox = TRUE)
cat("Saved", length(rds_index), "entries to", rds_index_path, "\n")
