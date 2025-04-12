# Purpose: Installs all required R packages for the project

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install remotes if not already installed
if (!require("remotes", quietly = TRUE)) {
  install.packages("remotes")
}

# List of required packages from CRAN
required_packages <- c(
  "tidyverse", # Data manipulation and visualization
  "xgboost", # For XGBoost model
  "feather", # For fast data storage
  "rvest", # For web scraping
  "fs", # For file system operations
  "httr", # For HTTP requests
  "lubridate", # For date handling
  "elo", # For ELO calculations
  "ggbump", # For smooth bump charts
  "glue", # For string interpolation
  "wehoop", # For women's basketball data
  "patchwork", # For arranging plots
  "ggforce"
)

# List of GitHub packages
github_packages <- c(
  "topfunky/gghighcontrast" # High contrast ggplot theme
)

# Function to install and load CRAN packages
install_and_load <- function(package) {
  if (!require(package, character.only = TRUE)) {
    message(sprintf("Installing %s from CRAN...", package))
    install.packages(package)
    library(package, character.only = TRUE)
  } else {
    message(sprintf("%s is already installed.", package))
  }
}

# Function to install and load GitHub packages
install_and_load_github <- function(package) {
  pkg_name <- basename(package)
  if (!require(pkg_name, character.only = TRUE)) {
    message(sprintf("Installing %s from GitHub...", package))
    remotes::install_github(package)
    library(pkg_name, character.only = TRUE)
  } else {
    message(sprintf("%s is already installed.", pkg_name))
  }
}

# Install and load all required packages
message("Installing and loading required packages...")

# Install CRAN packages
for (package in required_packages) {
  install_and_load(package)
}

# Install GitHub packages
for (package in github_packages) {
  install_and_load_github(package)
}

message("All dependencies installed and loaded successfully!")
