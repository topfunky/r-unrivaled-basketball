# Purpose: Exports all feather data files to CSV format in a data directory.

# Load required libraries
library(tidyverse)
library(fs)
library(feather)

# Create data directory if it doesn't exist
data_dir <- "data"
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

# Find all feather files in the current directory
feather_files <- dir_ls(".", glob = "*.feather")

# Check if any feather files were found
if (length(feather_files) == 0) {
  message("No feather files found in the current directory")
} else {
  message(sprintf("Found %d feather file(s) to convert", length(feather_files)))
  
  # Convert each feather file to CSV
  for (feather_file in feather_files) {
    # Get the base filename without extension
    base_name <- path_ext_remove(path_file(feather_file))
    
    # Create output CSV path in data directory
    csv_file <- path(data_dir, paste0(base_name, ".csv"))
    
    # Read feather file and write to CSV
    message(sprintf("Converting %s to %s...", path_file(feather_file), path_file(csv_file)))
    
    read_feather(feather_file) |>
      write_csv(csv_file)
    
    message(sprintf("Successfully converted %s", path_file(feather_file)))
  }
  
  message(sprintf("\nAll feather files have been exported to the %s directory", data_dir))
}
