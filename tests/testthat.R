# Purpose: Test runner for testthat tests

library(testthat)

# Try to load the package if installed, otherwise source the R files directly
if (requireNamespace("unrivaled", quietly = TRUE)) {
  library(unrivaled)
  test_check("unrivaled")
} else {
  # Source package files for direct test runs without package installation
  r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
  for (f in r_files) {
    source(f)
  }
  test_dir("tests/testthat")
}
