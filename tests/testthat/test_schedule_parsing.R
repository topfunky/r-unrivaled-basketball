# Purpose: Tests that schedule.html can be parsed and game IDs are extracted correctly

library(testthat)

# Source the function from scrape_unrivaled_scores.R
source(file.path("..", "..", "scrape_unrivaled_scores.R"))

test_that("schedule.html contains game links with expected IDs", {
  # Get path relative to project root (testthat runs from tests/testthat)
  schedule_file <- file.path("..", "..", "fixtures", "2026", "schedule.html")

  # Check that file exists
  expect_true(file.exists(schedule_file), info = "Schedule file should exist")

  # Extract game IDs using function from scrape_unrivaled_scores.R
  game_ids <- extract_game_ids(schedule_file, season_year = 2026)

  # Verify that game IDs are found
  expect_true(length(game_ids) > 0, info = "Should find at least one game ID")

  # Verify specific game IDs are present
  expected_ids <- c(
    "24w1j54rlgk9",
    "rqmx9jwdey3k",
    "8z57p4vocgku",
    "o5h5wwa88ubf"
  )

  for (expected_id in expected_ids) {
    expect_true(
      expected_id %in% game_ids,
      info = paste("Game ID", expected_id, "should be found in schedule")
    )
  }

  # Verify that all found IDs match the expected pattern
  expect_true(
    all(str_detect(game_ids, "^[a-z0-9]+$")),
    info = "All game IDs should match pattern [a-z0-9]+"
  )
})
