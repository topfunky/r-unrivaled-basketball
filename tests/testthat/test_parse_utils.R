# Purpose: Tests for parse_utils.R functions
# Tests parsing of play-by-play, box score, and summary data

library(fs)

# Project root is needed so parse_* (which use relative "games/...") find files
project_root <- NULL
for (root in c(testthat::test_path("..", ".."), getwd(), ".")) {
  if (dir.exists(file.path(root, "R"))) {
    project_root <- root
    break
  }
}

# Helper to check if game files exist under a base path
game_files_exist <- function(game_id, season_year, base = getwd()) {
  pbp_file <- fs::path(base, "games", season_year, game_id, "play-by-play.html")
  box_file <- fs::path(base, "games", season_year, game_id, "box-score.html")
  sum_file <- fs::path(base, "games", season_year, game_id, "summary.html")
  fs::file_exists(pbp_file) &&
    fs::file_exists(box_file) &&
    fs::file_exists(sum_file)
}

# Fail test with clear error if project root or game files are missing
require_game_files <- function(game_id, season_year) {
  if (is.null(project_root)) {
    stop("Project root not found. Run tests from project root (directory with R/).")
  }
  if (!game_files_exist(game_id, season_year, base = project_root)) {
    stop(
      "Game files not available. Run tests from project root with ",
      "games/", season_year, "/", game_id, "/ present."
    )
  }
}

describe("parse_play_by_play", {
  it("returns NULL with warning for non-existent file", {
    expect_warning(
      result <- parse_play_by_play("nonexistent_game", 2026),
      "Play by play file not found"
    )
    expect_null(result)
  })

  it("returns NULL with warning when game has not occurred (no parseable data)", {
    # Game that has not been played has HTML but no play-by-play tables
    game_id <- "xaqzbkbp7wg0"
    if (!game_files_exist(game_id, 2026, base = project_root)) {
      testthat::skip(
        sprintf("Game %s not present; run from project root with games/2026/%s/",
                game_id, game_id)
      )
    }
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    expect_warning(
      result <- parse_play_by_play(game_id, 2026),
      "No tables found in play by play file"
    )
    expect_null(result)
  })

  it("parses real game play-by-play data", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_play_by_play(game_id, 2026)

    expect_s3_class(result, "tbl_df")

    # Check expected columns
    expected_cols <- c(
      "game_id",
      "season",
      "quarter",
      "time",
      "minute",
      "second",
      "play",
      "pos_team",
      "away_score",
      "home_score"
    )
    expect_true(all(expected_cols %in% names(result)))

    # Check game_id is set correctly
    expect_true(all(result$game_id == game_id))

    # Check season is set correctly
    expect_true(all(result$season == 2026))

    # Check scores are numeric
    expect_type(result$away_score, "double")
    expect_type(result$home_score, "double")
  })

  it("extracts quarter information correctly", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_play_by_play(game_id, 2026)

    # Quarters should be 1-4 (or NA for non-quarter-start plays)
    valid_quarters <- result$quarter[!is.na(result$quarter)]
    expect_true(all(valid_quarters %in% 1:4))
  })
})

describe("parse_box_score", {
  it("returns NULL with warning for non-existent file", {
    expect_warning(
      result <- parse_box_score("nonexistent_game", 2026),
      "Box score file not found"
    )
    expect_null(result)
  })

  it("returns NULL with warning when game has not occurred (no parseable data)", {
    game_id <- "xaqzbkbp7wg0"
    if (!game_files_exist(game_id, 2026, base = project_root)) {
      testthat::skip(
        sprintf("Game %s not present; run from project root with games/2026/%s/",
                game_id, game_id)
      )
    }
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    expect_warning(
      result <- parse_box_score(game_id, 2026),
      "No tables found in box score file"
    )
    expect_null(result)
  })

  it("parses real game box score data", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_box_score(game_id, 2026)

    expect_s3_class(result, "tbl_df")

    # Check expected columns
    expected_cols <- c(
      "game_id",
      "season",
      "is_starter",
      "player_name",
      "jersey_number",
      "MIN",
      "field_goals_made",
      "field_goals_attempted",
      "three_point_field_goals_made",
      "three_point_field_goals_attempted",
      "free_throws_made",
      "free_throws_attempted",
      "two_point_field_goals_made",
      "two_point_field_goals_attempted",
      "REB",
      "OREB",
      "DREB",
      "AST",
      "STL",
      "BLK",
      "TO",
      "PF",
      "PTS"
    )
    expect_true(all(expected_cols %in% names(result)))

    # Check game_id is set correctly
    expect_true(all(result$game_id == game_id))

    # Check is_starter is logical
    expect_type(result$is_starter, "logical")

    # Check stats are numeric
    expect_type(result$PTS, "double")
    expect_type(result$REB, "double")
  })

  it("correctly identifies starters", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_box_score(game_id, 2026)

    # Should have some starters and some non-starters
    expect_true(any(result$is_starter))
    expect_true(any(!result$is_starter))
  })

  it("calculates two-point field goals correctly", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_box_score(game_id, 2026)

    # Two-point FG = Total FG - Three-point FG
    calculated_2pt_made <- result$field_goals_made -
      result$three_point_field_goals_made
    expect_equal(result$two_point_field_goals_made, calculated_2pt_made)

    calculated_2pt_attempted <- result$field_goals_attempted -
      result$three_point_field_goals_attempted
    expect_equal(
      result$two_point_field_goals_attempted,
      calculated_2pt_attempted
    )
  })
})

describe("parse_summary", {
  it("returns NULL with warning for non-existent file", {
    expect_warning(
      result <- parse_summary("nonexistent_game", 2026),
      "Summary file not found"
    )
    expect_null(result)
  })

  it("returns NULL with warning when game has not occurred (no parseable data)", {
    game_id <- "xaqzbkbp7wg0"
    if (!game_files_exist(game_id, 2026, base = project_root)) {
      testthat::skip(
        sprintf("Game %s not present; run from project root with games/2026/%s/",
                game_id, game_id)
      )
    }
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    expect_warning(
      result <- parse_summary(game_id, 2026),
      "No tables found in summary file"
    )
    expect_null(result)
  })

  it("parses real game summary data", {
    game_id <- "24w1j54rlgk9"
    require_game_files(game_id, 2026)
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- parse_summary(game_id, 2026)

    expect_s3_class(result, "tbl_df")

    # Check expected columns
    expected_cols <- c(
      "game_id",
      "season",
      "team",
      "field_goals",
      "field_goal_pct",
      "three_pointers",
      "three_point_pct",
      "free_throws",
      "free_throw_pct"
    )
    expect_true(all(expected_cols %in% names(result)))

    # Should have exactly 2 rows (one per team)
    expect_equal(nrow(result), 2)

    # Teams should be team_a and team_b
    expect_setequal(result$team, c("team_a", "team_b"))

    # Percentages should be numeric
    expect_type(result$field_goal_pct, "double")
    expect_type(result$three_point_pct, "double")
    expect_type(result$free_throw_pct, "double")
  })
})

describe("process_season", {
  it("returns NULL for non-existent season directory", {
    result <- process_season(1999)
    expect_null(result)
  })

  it("returns list with expected components for valid season", {
    if (is.null(project_root)) {
      stop("Project root not found. Run tests from project root (directory with R/).")
    }
    games_2026 <- fs::path(project_root, "games", "2026")
    if (!fs::dir_exists(games_2026)) {
      stop(
        "Games directory not available. Run tests from project root with ",
        "games/2026/ present."
      )
    }
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(project_root)

    result <- process_season(2026)

    expect_type(result, "list")
    expect_true("play_by_play" %in% names(result))
    expect_true("box_score" %in% names(result))
    expect_true("summary" %in% names(result))

    # Each component should be a tibble
    expect_s3_class(result$play_by_play, "tbl_df")
    expect_s3_class(result$box_score, "tbl_df")
    expect_s3_class(result$summary, "tbl_df")

    # Games that have not occurred have no parseable data and contribute no rows
    not_yet_played_id <- "xaqzbkbp7wg0"
    expect_false(
      not_yet_played_id %in% result$play_by_play$game_id,
      info = "Not-yet-played game should have no rows in play_by_play"
    )
    expect_false(
      not_yet_played_id %in% result$box_score$game_id,
      info = "Not-yet-played game should have no rows in box_score"
    )
    expect_false(
      not_yet_played_id %in% result$summary$game_id,
      info = "Not-yet-played game should have no rows in summary"
    )
  })
})
