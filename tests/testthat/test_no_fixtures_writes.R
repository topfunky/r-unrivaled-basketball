# Purpose: Test that no non-test code writes to fixtures directory.
# This ensures fixtures remain read-only for all production code.

library(testthat)

test_that("no non-test code writes to fixtures directory", {
  # Get project root directory (testthat runs from tests/testthat)
  project_root <- file.path("..", "..")
  
  # Find all R files in project root, excluding tests directory
  r_files <- list.files(
    path = project_root,
    pattern = "\\.R$",
    recursive = TRUE,
    full.names = TRUE
  )
  
  # Filter out test files and files in tests directory
  r_files <- r_files[
    !grepl("^tests/", gsub(paste0(project_root, "/"), "", r_files))
  ]
  
  # Patterns that indicate writes to fixtures directory
  write_patterns <- c(
    'write_csv\\([^)]*["\']fixtures',
    'write_feather\\([^)]*["\']fixtures',
    'write_tsv\\([^)]*["\']fixtures',
    'write_delim\\([^)]*["\']fixtures',
    'write.table\\([^)]*["\']fixtures',
    'saveRDS\\([^)]*["\']fixtures',
    'save\\([^)]*["\']fixtures',
    'dir.create\\([^)]*["\']fixtures',
    'file.create\\([^)]*["\']fixtures',
    'cat\\([^)]*["\']fixtures.*file\\s*=',
    'sink\\([^)]*["\']fixtures',
    'writeLines\\([^)]*["\']fixtures',
    'write\\([^)]*["\']fixtures',
    'write_file\\([^)]*["\']fixtures',
    'write_file_raw\\([^)]*["\']fixtures'
  )
  
  violations <- list()
  
  # Check each R file for violations
  for (r_file in r_files) {
    file_content <- readLines(r_file, warn = FALSE)
    
    for (line_num in seq_along(file_content)) {
      line <- file_content[line_num]
      
      # Check each pattern
      for (pattern in write_patterns) {
        if (grepl(pattern, line, ignore.case = TRUE)) {
          # Skip if it's a comment
          if (!grepl("^\\s*#", line)) {
            violations[[length(violations) + 1]] <- list(
              file = gsub(paste0(project_root, "/"), "", r_file),
              line = line_num,
              content = trimws(line),
              pattern = pattern
            )
          }
        }
      }
    }
  }
  
  # Report violations
  if (length(violations) > 0) {
    violation_messages <- sapply(violations, function(v) {
      paste0(
        "  - ", v$file, ":", v$line, " - ", v$content
      )
    })
    
    fail_msg <- paste0(
      "Found ", length(violations), " violation(s) writing to fixtures directory:\n",
      paste(violation_messages, collapse = "\n")
    )
    
    fail(fail_msg)
  }
  
  # Test passes if no violations found
  expect_true(TRUE)
})
