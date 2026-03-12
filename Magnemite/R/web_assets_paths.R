# Shared path helpers for website asset workflows.

magnemite_paths <- function(output_dir = NULL, server_dir = NULL) {
  resolved_server_dir <- if (!is.null(server_dir) && nzchar(server_dir)) {
    server_dir
  } else {
    Sys.getenv("MAGNEMITE_SERVER_DIR", unset = Sys.getenv("NOSEPASS_SERVER_DIR", unset = "D:/Nosepass/SERVER"))
  }

  resolved_output_dir <- if (!is.null(output_dir) && nzchar(output_dir)) {
    output_dir
  } else {
    Sys.getenv("MAGNEMITE_OUTPUT_DIR", unset = Sys.getenv("NOSEPASS_OUTPUT_DIR", unset = "D:/Magnemite_Out"))
  }

  resolved_server_dir <- normalizePath(resolved_server_dir, mustWork = FALSE)
  resolved_output_dir <- normalizePath(resolved_output_dir, mustWork = FALSE)

  list(
    server_dir = resolved_server_dir,
    output_dir = resolved_output_dir,
    magnetograms_dir = file.path(resolved_output_dir, "assets", "img", "magnetograms"),
    indexes_dir = file.path(resolved_output_dir, "indexes")
  )
}

magnemite_year_dirs <- function(root_dir) {
  dirs <- list.dirs(root_dir, full.names = TRUE, recursive = FALSE)
  year_dirs <- dirs[grepl("^[0-9]{4}$", basename(dirs))]

  if (length(year_dirs) > 0) {
    return(year_dirs)
  }

  dirs
}
