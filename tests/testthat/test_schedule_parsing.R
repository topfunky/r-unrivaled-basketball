# Purpose: Tests that schedule.html can be parsed
# and game IDs are extracted correctly

test_that("2026 schedule.html contains game links with expected IDs", {
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

  # Extract game IDs using function from package
  game_ids <- extract_game_ids(schedule_file, season_year = 2026)

  expect_equal(
    61,
    length(game_ids),
    label = paste("game_ids found:", paste(game_ids, collapse = ", "))
  )

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
