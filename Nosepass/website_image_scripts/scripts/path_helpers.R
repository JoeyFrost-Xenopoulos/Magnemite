get_paths <- function(custom_output_dir = NULL) {
  server_dir <- Sys.getenv("NOSEPASS_SERVER_DIR", unset = "D:/Nosepass/SERVER")
  
  if (!is.null(custom_output_dir) && nzchar(custom_output_dir)) {
    output_dir <- normalizePath(custom_output_dir, mustWork = FALSE)
  } else {
    output_dir <- Sys.getenv("NOSEPASS_OUTPUT_DIR", unset = "D:/Nosepass/output")
    output_dir <- normalizePath(output_dir, mustWork = FALSE)
  }

  list(
    server_dir = normalizePath(server_dir, mustWork = FALSE),
    output_dir = normalizePath(output_dir, mustWork = FALSE),
    magnetograms_dir = file.path(output_dir, "assets", "img", "magnetograms"),
    indexes_dir = file.path(output_dir, "indexes")
  )
}

get_year_dirs <- function(root_dir) {
  dirs <- list.dirs(root_dir, full.names = TRUE, recursive = FALSE)
  year_dirs <- dirs[grepl("^[0-9]{4}$", basename(dirs))]
  if (length(year_dirs) > 0) {
    return(year_dirs)
  }
  dirs
}