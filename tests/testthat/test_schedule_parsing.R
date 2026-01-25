# Purpose: Tests that schedule.html can be parsed and game IDs are extracted correctly

library(testthat)
library(rvest)
library(tidyverse)

test_that("schedule.html contains game links with expected IDs", {
  # Get path relative to project root (testthat runs from tests/testthat)
  schedule_file <- file.path("..", "..", "fixtures", "2026", "schedule.html")

  # Check that file exists
  expect_true(file.exists(schedule_file), info = "Schedule file should exist")

  # Read the HTML file
  html <- read_html(schedule_file)

  # Find all game links
  game_links <- html |>
    html_elements("a[href*='/game/']")

  # Extract game IDs from href attributes
  game_ids <- map_chr(
    game_links,
    ~ {
      href <- html_attr(.x, "href")
      if (is.na(href) || is.null(href)) return(NA_character_)
      # Extract ID from /game/{id} pattern
      id <- str_extract(href, "(?<=/game/)[a-z0-9]+")
      if (is.na(id)) return(NA_character_)
      id
    }
  )

  # Remove NA values
  game_ids <- game_ids[!is.na(game_ids)]

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
