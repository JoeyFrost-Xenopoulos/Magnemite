library(magick)
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
output_dir <- file.path(paths$magnetograms_dir, "fullsize")

if (!dir.exists(root_dir)) {
  stop("Server directory not found: ", root_dir)
}

# Get list of year directories
year_dirs <- get_year_dirs(root_dir)

# Loop through each year directory
for (dir in year_dirs) {
  year <- basename(dir)
  
  # List valid PNG files (excluding 'FailToProcess' and 'Plot')
  png_files <- list.files(dir, pattern = "\\.png$", full.names = FALSE, ignore.case = TRUE)
  png_files <- png_files[!grepl("-FailToProcess|-Plot", png_files, ignore.case = TRUE)]
  
  if (length(png_files) == 0) {
    message("No valid images found for year ", year)
    next
  }
  
  # Create year-specific output subfolder
  year_output_dir <- file.path(output_dir, year)
  dir.create(year_output_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Process each image
  for (file in png_files) {
    input_path <- file.path(dir, file)
    
    # Read image
    img <- image_read(input_path)
    
    # Rotate if vertical
    info <- image_info(img)
    if (info$height > info$width) {
      img <- image_rotate(img, 90)
    }
    
    # Write to appropriate subfolder
    output_path <- file.path(year_output_dir, file)
    image_write(img, output_path, format = "png")
    
    message("Processed: ", output_path)
  }
}
