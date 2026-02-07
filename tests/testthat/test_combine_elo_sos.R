# Purpose: Tests for the combined Elo rankings + SOS output
# Verifies that the combined per-game output includes SOS columns,
# current wins, and total estimated wins for both home and away teams.

library(dplyr)

# Helper to build a minimal ratings_history for testing
build_test_ratings_history <- function() {
  tibble(
    team.A = c("A", "B"),
    team.B = c("B", "A"),
    p.A = c(0.5, 0.5),
    wins.A = c(1, 0),
    update.A = c(16, -16),
    update.B = c(-16, 16),
    home_team_elo = c(1516, 1484),
    away_team_elo = c(1484, 1516),
    date = as.Date(c("2026-01-05", "2026-01-09")),
    game_id = c("g1", "g2"),
    home_team = c("A", "B"),
    away_team = c("B", "A"),
    result = c(1, 0),
    season = c(2026, 2026),
    home_team_elo_prev = c(1500, 1500),
    away_team_elo_prev = c(1500, 1500)
  )
}

# Helper to build a minimal elo_with_sos for testing
build_test_elo_with_sos <- function() {
  tibble(
    team = c("A", "A", "A", "B", "B", "B"),
    elo_rating = c(1500, 1516, 1532, 1500, 1484, 1468),
    games_played = c(0L, 1L, 2L, 0L, 1L, 2L),
    games_remaining = c(2L, 1L, 0L, 2L, 1L, 0L),
    remaining_estimated_wins = c(1.1, 0.6, 0.0, 0.9, 0.4, 0.0)
  )
}

# Helper to build minimal scores for computing current wins
build_test_scores <- function() {
  tibble(
    date = as.Date(c("2026-01-05", "2026-01-09")),
    game_id = c("g1", "g2"),
    home_team = c("A", "B"),
    away_team = c("B", "A"),
    home_team_score = c(80, 70),
    away_team_score = c(70, 80),
    season = c(2026, 2026),
    season_type = c("Regular Season", "Regular Season")
  )
}

describe("compute_current_wins", {
  it("returns per-team cumulative wins at each game", {
    scores <- build_test_scores()
    result <- compute_current_wins(scores)

    expect_equal(nrow(result), 4)
    expected_cols <- c(
      "team", "games_played", "current_wins"
    )
    expect_all_in(expected_cols, names(result))
  })

  it("counts wins correctly for winning and losing teams", {
    scores <- build_test_scores()
    result <- compute_current_wins(scores)

    # After game 1: A won at home (1 win), B lost away (0 wins)
    a_g1 <- result |> filter(team == "A", games_played == 1)
    b_g1 <- result |> filter(team == "B", games_played == 1)
    expect_equal(a_g1$current_wins, 1)
    expect_equal(b_g1$current_wins, 0)

    # After game 2: A won away (2 wins), B lost at home (0 wins)
    a_g2 <- result |> filter(team == "A", games_played == 2)
    b_g2 <- result |> filter(team == "B", games_played == 2)
    expect_equal(a_g2$current_wins, 2)
    expect_equal(b_g2$current_wins, 0)
  })
})

describe("combine_elo_with_sos", {
  it("returns all original ratings_history columns", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    original_cols <- names(ratings_history)
    expect_all_in(original_cols, names(result))
  })

  it("adds home and away SOS columns", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    sos_cols <- c(
      "home_team_games_played",
      "home_team_games_remaining",
      "home_team_remaining_estimated_wins",
      "away_team_games_played",
      "away_team_games_remaining",
      "away_team_remaining_estimated_wins"
    )
    expect_all_in(sos_cols, names(result))
  })

  it("adds current wins and total estimated wins columns", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    wins_cols <- c(
      "home_team_current_wins",
      "away_team_current_wins",
      "home_team_total_estimated_wins",
      "away_team_total_estimated_wins"
    )
    expect_all_in(wins_cols, names(result))
  })

  it("joins SOS by team and games_played", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    # Game 1: home=A (gp=1), away=B (gp=1)
    row1 <- result[1, ]
    expect_equal(row1$home_team_games_played, 1L)
    expect_equal(row1$away_team_games_played, 1L)
    expect_equal(row1$home_team_games_remaining, 1L)
    expect_equal(row1$away_team_games_remaining, 1L)
    expect_equal(row1$home_team_remaining_estimated_wins, 0.6)
    expect_equal(row1$away_team_remaining_estimated_wins, 0.4)
  })

  it("computes total_estimated_wins as current_wins + remaining_estimated_wins", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    # Game 1: home=A won 1 game + 0.6 remaining = 1.6
    row1 <- result[1, ]
    expect_equal(
      row1$home_team_total_estimated_wins,
      row1$home_team_current_wins + row1$home_team_remaining_estimated_wins
    )
    expect_equal(
      row1$away_team_total_estimated_wins,
      row1$away_team_current_wins + row1$away_team_remaining_estimated_wins
    )
  })

  it("preserves the same number of rows as ratings_history", {
    ratings_history <- build_test_ratings_history()
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(ratings_history, elo_with_sos, scores)

    expect_equal(nrow(result), nrow(ratings_history))
  })
})
