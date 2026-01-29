# Purpose: Test runner for testthat tests

library(testthat)

# Try to load the package if installed, otherwise source the R files directly
if (requireNamespace("unrivaled", quietly = TRUE)) {
  library(unrivaled)
  test_check("unrivaled")
} else {
  # Source package files for direct test runs without package installation
  # Source team_colors.R first since other files depend on its exported values
  r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  team_colors_file <- r_files[grepl("team_colors\\.R$", r_files)]
  other_files <- r_files[!grepl("team_colors\\.R$", r_files)]

  # Source team_colors first, then other files
  if (length(team_colors_file) > 0) {
    source(team_colors_file)
  }
  for (f in other_files) {
    source(f)
  }
  test_dir("tests/testthat")
}
