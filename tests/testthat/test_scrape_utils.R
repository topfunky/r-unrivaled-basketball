# Purpose: Tests for scrape_utils.R functions
# Tests season parameters and game scraping utilities

library(rvest)
library(lubridate)

describe("get_season_params", {
  it("returns parameters for 2025 season", {
    params <- get_season_params(2025)

    expect_type(params, "list")
    expect_not_empty(params$valid_teams)
    expect_s3_class(params$skip_start, "Date")
    expect_s3_class(params$skip_end, "Date")
    expect_s3_class(params$postseason_start, "Date")
    expect_type(params$schedule_file, "character")
  })

  it("returns parameters for 2026 season", {
    params <- get_season_params(2026)

    expect_type(params, "list")
    expect_not_empty(params$valid_teams)
    expect_s3_class(params$skip_start, "Date")
    expect_s3_class(params$skip_end, "Date")
    expect_s3_class(params$postseason_start, "Date")
    expect_type(params$schedule_file, "character")
  })

  it("returns NULL for unknown season", {
    params <- get_season_params(2020)
    expect_null(params)
  })

  it("2025 season has 6 valid teams", {
    params <- get_season_params(2025)
    expect_equal(length(params$valid_teams), 6)
  })

  it("2026 season has 8 valid teams (expansion)", {
    params <- get_season_params(2026)
    expect_equal(length(params$valid_teams), 8)

    # Check expansion teams are included
    expect_in("Breeze", params$valid_teams)
    expect_in("Hive", params$valid_teams)
  })

  it("skip dates are in February", {
    params_2025 <- get_season_params(2025)
    params_2026 <- get_season_params(2026)

    expect_equal(lubridate::month(params_2025$skip_start), 2)
    expect_equal(lubridate::month(params_2025$skip_end), 2)
    expect_equal(lubridate::month(params_2026$skip_start), 2)
    expect_equal(lubridate::month(params_2026$skip_end), 2)
  })

  it("postseason starts in March", {
    params_2025 <- get_season_params(2025)
    params_2026 <- get_season_params(2026)

    expect_equal(lubridate::month(params_2025$postseason_start), 3)
    expect_equal(lubridate::month(params_2026$postseason_start), 3)
  })

  it("accepts season year as string", {
    params <- get_season_params("2025")
    expect_type(params, "list")
  })
})

describe("parse_game_day", {
  it("returns NULL for invalid day node", {
    html_content <- "<div>No game data</div>"
    day_node <- read_html(html_content) |> html_element("div")
    s_params <- get_season_params(2026)

    expect_warning(
      result <- parse_game_day(day_node, 2026, s_params),
      "Date text is empty or NA|Could not find date element"
    )
    expect_null(result)
  })
})

describe("scrape_unrivaled_games", {
  it("returns NULL with warning when schedule file not found", {
    # 2025 schedule file doesn't exist in test environment
    expect_warning(
      result <- scrape_unrivaled_games(2025),
      "Schedule file.*not found"
    )
    expect_null(result)
  })

  it("stops with error for unknown season", {
    expect_error(
      scrape_unrivaled_games(1999),
      "Parameters for season 1999 not found"
    )
  })
})

describe("find_game_date", {
  it("returns NA for game not in HTML", {
    html_content <- "<div>No games</div>"
    html <- read_html(html_content)

    result <- find_game_date("nonexistent123", html, 2026)
    expect_true(is.na(result))
  })
})
