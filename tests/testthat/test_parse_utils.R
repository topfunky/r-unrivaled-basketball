# Purpose: Tests for parse_utils.R functions
# Tests parsing of play-by-play, box score, and summary data

library(fs)

# Helper to check if game files exist
game_files_exist <- function(game_id, season_year) {
  pbp_file <- fs::path("games", season_year, game_id, "play-by-play.html")
  box_file <- fs::path("games", season_year, game_id, "box-score.html")
  sum_file <- fs::path("games", season_year, game_id, "summary.html")
  fs::file_exists(pbp_file) && fs::file_exists(box_file) && fs::file_exists(sum_file)
}

describe("parse_play_by_play", {
  it("returns NULL with warning for non-existent file", {
    expect_warning(
      result <- parse_play_by_play("nonexistent_game", 2026),
      "Play by play file not found"
    )
    expect_null(result)
  })

  it("parses real game play-by-play data", {
    # Use a real game from the games directory
    game_id <- "24w1j54rlgk9"
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

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
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

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

  it("parses real game box score data", {
    game_id <- "24w1j54rlgk9"
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

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
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

    result <- parse_box_score(game_id, 2026)

    # Should have some starters and some non-starters
    expect_true(any(result$is_starter))
    expect_true(any(!result$is_starter))
  })

  it("calculates two-point field goals correctly", {
    game_id <- "24w1j54rlgk9"
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

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

  it("parses real game summary data", {
    game_id <- "24w1j54rlgk9"
    skip_if(!game_files_exist(game_id, 2026), "Game files not available")

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
    skip_if(!fs::dir_exists("games/2026"), "Games directory not available")

    result <- process_season(2026)

    expect_type(result, "list")
    expect_true("play_by_play" %in% names(result))
    expect_true("box_score" %in% names(result))
    expect_true("summary" %in% names(result))

    # Each component should be a tibble
    expect_s3_class(result$play_by_play, "tbl_df")
    expect_s3_class(result$box_score, "tbl_df")
    expect_s3_class(result$summary, "tbl_df")
  })
})
