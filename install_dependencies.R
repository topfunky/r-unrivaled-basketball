# Purpose: Installs all required R packages for the project

install.packages(
  "pak",
  repos = sprintf(
    "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
    .Platform$pkgType,
    R.Version()$os,
    R.Version()$arch
  )
)

# Set CRAN mirror
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install remotes if not already installed
# if (!require("remotes", quietly = TRUE)) {
# pak::pkg_install("remotes")
# }

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
  "patchwork", # For arranging plots
  "ggforce",
  "ggrepel"
)

# List of GitHub packages
github_packages <- c(
  "topfunky/gghighcontrast" # High contrast ggplot theme
)

# Function to install and load CRAN packages
install_and_load <- function(package) {
  if (!require(package, character.only = TRUE)) {
    message(sprintf("Installing %s from CRAN...", package))
    pak::pkg_install(package)
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
    pak::pkg_install(package)
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

# Reinstall openssl package to ensure it's linked against correct system libraries
# This is necessary if openssl was previously installed but system OpenSSL libraries
# were missing or have been updated
message("Checking and reinstalling openssl package if needed...")
tryCatch(
  {
    # Try to load openssl to check if it works
    if (requireNamespace("openssl", quietly = TRUE)) {
      # Try to actually use it to verify it works
      test_result <- tryCatch(
        {
          openssl::md5("test")
          TRUE
        },
        error = function(e) FALSE
      )

      if (!test_result) {
        message("openssl package exists but is broken. Reinstalling...")
        pak::pkg_remove("openssl")
        pak::pkg_install("openssl")
      }
    } else {
      message("Installing openssl package...")
      pak::pkg_install("openssl")
    }
  },
  error = function(e) {
    message("Error checking openssl, attempting reinstall...")
    pak::pkg_remove("openssl")
    pak::pkg_install("openssl")
  }
)

# You can install wehoop using the pacman package using the following code:
if (!requireNamespace('pacman', quietly = TRUE)) {
  install.packages('pacman')
}

pacman::p_load(wehoop, dplyr, tictoc, progressr)

message("All dependencies installed and loaded successfully!")
