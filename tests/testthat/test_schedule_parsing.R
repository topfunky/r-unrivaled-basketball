# Purpose: Tests that schedule.html can be parsed and game IDs are extracted correctly

test_that("schedule.html contains game links with expected IDs", {
  # Find the fixtures directory - try multiple locations to handle both
 # direct test runs and covr package coverage runs
  possible_paths <- c(
    testthat::test_path("..", "..", "fixtures", "2026", "schedule.html"),
    file.path(getwd(), "fixtures", "2026", "schedule.html"),
    "fixtures/2026/schedule.html"
  )

  schedule_file <- NULL
  for (path in possible_paths) {
    if (file.exists(path)) {
      schedule_file <- path
      break
    }
  }

  skip_if(is.null(schedule_file), "Schedule file not found in any expected location")

  # Extract game IDs using function from package
  game_ids <- extract_game_ids(schedule_file, season_year = 2026)

  expect_true(length(game_ids) > 0, info = "Should find at least one game ID")

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

  expect_true(
    all(stringr::str_detect(game_ids, "^[a-z0-9]+$")),
    info = "All game IDs should match pattern [a-z0-9]+"
  )
})
