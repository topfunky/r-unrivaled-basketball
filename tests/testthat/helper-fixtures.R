# Purpose: Test helper functions for finding fixture files and custom assertions
# This file is automatically sourced by testthat before running tests

#' Find fixture file across different test run contexts
#'
#' Searches for a fixture file in multiple possible locations to handle
#' both direct test runs and package coverage runs.
#'
#' @param filename Name of the fixture file (can include subdirectory)
#' @return Full path to the fixture file
#' @examples
#' find_fixture("schedule_with_final_games.html")
#' find_fixture("2026/schedule.html")
find_fixture <- function(filename) {
  possible_paths <- c(
    testthat::test_path("..", "..", "fixtures", filename),
    file.path(getwd(), "fixtures", filename),
    file.path("fixtures", filename)
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      return(path)
    }
  }

  stop(paste("Fixture not found:", filename))
}

# Custom test assertions with informative failure messages

#' Expect value is in collection
#'
#' @param needle The value to search for
#' @param haystack The collection to search in
#' @param label Optional label for the needle in failure messages
expect_in <- function(needle, haystack, label = NULL) {
  needle_label <- label %||% deparse(substitute(needle))
  haystack_label <- deparse(substitute(haystack))

  testthat::expect(
    needle %in% haystack,
    sprintf(
      "%s ('%s') not found in %s.\nCollection contains: %s",
      needle_label,
      needle,
      haystack_label,
      paste(haystack, collapse = ", ")
    )
  )
  invisible(needle)
}

#' Expect value is not in collection
#'
#' @param needle The value to search for
#' @param haystack The collection to search in
#' @param label Optional label for the needle in failure messages
expect_not_in <- function(needle, haystack, label = NULL) {
  needle_label <- label %||% deparse(substitute(needle))
  haystack_label <- deparse(substitute(haystack))

  testthat::expect(
    !(needle %in% haystack),
    sprintf(
      "%s ('%s') should not be in %s, but it was found.\nCollection contains: %s",
      needle_label,
      needle,
      haystack_label,
      paste(haystack, collapse = ", ")
    )
  )
  invisible(needle)
}

#' Expect all values are in collection
#'
#' @param needles Vector of values to search for
#' @param haystack The collection to search in
expect_all_in <- function(needles, haystack) {
  needles_label <- deparse(substitute(needles))
  haystack_label <- deparse(substitute(haystack))
  missing <- needles[!(needles %in% haystack)]

  testthat::expect(
    length(missing) == 0,
    sprintf(
      "Not all values from %s found in %s.\nMissing: %s\nCollection contains: %s",
      needles_label,
      haystack_label,
      paste(missing, collapse = ", "),
      paste(haystack, collapse = ", ")
    )
  )
  invisible(needles)
}

#' Expect none of the values are in collection
#'
#' @param needles Vector of values that should not be present
#' @param haystack The collection to search in
expect_none_in <- function(needles, haystack) {
  needles_label <- deparse(substitute(needles))
  haystack_label <- deparse(substitute(haystack))
  found <- needles[needles %in% haystack]

  testthat::expect(
    length(found) == 0,
    sprintf(
      "Expected none of %s to be in %s.\nUnexpectedly found: %s",
      needles_label,
      haystack_label,
      paste(found, collapse = ", ")
    )
  )
  invisible(needles)
}

#' Expect collections contain the same elements (order independent)
#'
#' @param actual The actual collection
#' @param expected The expected collection
expect_setequal <- function(actual, expected) {
  actual_label <- deparse(substitute(actual))
  expected_label <- deparse(substitute(expected))

  missing_from_actual <- expected[!(expected %in% actual)]
  extra_in_actual <- actual[!(actual %in% expected)]

  testthat::expect(
    length(missing_from_actual) == 0 && length(extra_in_actual) == 0,
    sprintf(
      "%s and %s do not contain the same elements.\nMissing: %s\nExtra: %s",
      actual_label,
      expected_label,
      if (length(missing_from_actual) > 0)
        paste(missing_from_actual, collapse = ", ") else "(none)",
      if (length(extra_in_actual) > 0)
        paste(extra_in_actual, collapse = ", ") else "(none)"
    )
  )
  invisible(actual)
}

#' Expect string contains substring
#'
#' @param string The string to search in
#' @param pattern The substring or pattern to find
#' @param fixed If TRUE, pattern is a fixed string, not a regex
expect_contains <- function(string, pattern, fixed = TRUE) {
  string_label <- deparse(substitute(string))

  if (fixed) {
    found <- grepl(pattern, string, fixed = TRUE)
  } else {
    found <- grepl(pattern, string)
  }

  testthat::expect(
    found,
    sprintf(
      "%s does not contain '%s'.\nActual value: '%s'",
      string_label,
      pattern,
      string
    )
  )
  invisible(string)
}

#' Expect string does not contain substring
#'
#' @param string The string to search in
#' @param pattern The substring or pattern that should not be present
#' @param fixed If TRUE, pattern is a fixed string, not a regex
expect_not_contains <- function(string, pattern, fixed = TRUE) {
  string_label <- deparse(substitute(string))

  if (fixed) {
    found <- grepl(pattern, string, fixed = TRUE)
  } else {
    found <- grepl(pattern, string)
  }

  testthat::expect(
    !found,
    sprintf(
      "%s should not contain '%s', but it does.\nActual value: '%s'",
      string_label,
      pattern,
      string
    )
  )
  invisible(string)
}

#' Expect value is empty (length 0)
#'
#' @param x The value to check
expect_empty <- function(x) {
  x_label <- deparse(substitute(x))

  testthat::expect(
    length(x) == 0,
    sprintf(
      "%s should be empty but has length %d.\nContents: %s",
      x_label,
      length(x),
      paste(x, collapse = ", ")
    )
  )
  invisible(x)
}

#' Expect value is not empty (length > 0)
#'
#' @param x The value to check
expect_not_empty <- function(x) {
  x_label <- deparse(substitute(x))

  testthat::expect(
    length(x) > 0,
    sprintf("%s should not be empty but has length 0", x_label)
  )
  invisible(x)
}
