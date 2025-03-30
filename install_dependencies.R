# Purpose: Installs all required R packages for the project

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# List of required packages
required_packages <- c(
  "tidyverse",    # Data manipulation and visualization
  "xgboost",      # For XGBoost model
  "feather",      # For fast data storage
  "gghighcontrast", # For high contrast ggplot theme
  "rvest",        # For web scraping
  "fs",           # For file system operations
  "httr",         # For HTTP requests
  "lubridate",    # For date handling
  "elo",          # For ELO calculations
  "ggbump",       # For smooth bump charts
  "glue"          # For string interpolation
)

# Function to install and load packages
install_and_load <- function(package) {
  if (!require(package, character.only = TRUE)) {
    message(sprintf("Installing %s...", package))
    install.packages(package)
    library(package, character.only = TRUE)
  } else {
    message(sprintf("%s is already installed.", package))
  }
}

# Install and load all required packages
message("Installing and loading required packages...")
for (package in required_packages) {
  install_and_load(package)
}

message("All dependencies installed and loaded successfully!") 