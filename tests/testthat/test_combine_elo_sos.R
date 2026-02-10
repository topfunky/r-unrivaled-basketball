# Purpose: Tests for the combined Elo rankings + SOS output
# Verifies long-format conversion, cumulative record tracking,
# and strict join with elo_with_sos by (team, team_game_index).

library(dplyr)

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

# --- scores_to_long ---

describe("scores_to_long", {
  it("produces exactly two rows per game (one per team)", {
    scores <- build_test_scores()
    result <- scores_to_long(scores)

    # 2 games * 2 teams = 4 rows
    expect_equal(nrow(result), 4)
  })

  it("returns required columns", {
    scores <- build_test_scores()
    result <- scores_to_long(scores)

    expected_cols <- c(
      "date", "game_id", "team", "opponent",
      "team_score", "opponent_score", "won"
    )
    expect_all_in(expected_cols, names(result))
  })

  it("correctly assigns team and opponent for home side", {
    scores <- build_test_scores()
    result <- scores_to_long(scores)

    # Game g1: home=A vs away=B, A won 80-70
    a_g1 <- result |> filter(game_id == "g1", team == "A")
    expect_equal(nrow(a_g1), 1)
    expect_equal(a_g1$opponent, "B")
    expect_equal(a_g1$team_score, 80)
    expect_equal(a_g1$opponent_score, 70)
    expect_equal(a_g1$won, 1L)
  })

  it("correctly assigns team and opponent for away side", {
    scores <- build_test_scores()
    result <- scores_to_long(scores)

    # Game g1: away=B vs home=A, B lost 70-80
    b_g1 <- result |> filter(game_id == "g1", team == "B")
    expect_equal(nrow(b_g1), 1)
    expect_equal(b_g1$opponent, "A")
    expect_equal(b_g1$team_score, 70)
    expect_equal(b_g1$opponent_score, 80)
    expect_equal(b_g1$won, 0L)
  })
})

# --- add_cumulative_record ---

describe("add_cumulative_record", {
  it("adds team_game_index, wins_to_date, losses_to_date, games_played_to_date", {
    scores <- build_test_scores()
    long <- scores_to_long(scores)
    result <- add_cumulative_record(long)

    expected_cols <- c(
      "team_game_index", "wins_to_date",
      "losses_to_date", "games_played_to_date"
    )
    expect_all_in(expected_cols, names(result))
  })

  it("team_game_index starts at 1 and increments per team", {
    scores <- build_test_scores()
    long <- scores_to_long(scores)
    result <- add_cumulative_record(long)

    a_rows <- result |> filter(team == "A") |> arrange(team_game_index)
    expect_equal(a_rows$team_game_index, c(1L, 2L))

    b_rows <- result |> filter(team == "B") |> arrange(team_game_index)
    expect_equal(b_rows$team_game_index, c(1L, 2L))
  })

  it("computes cumulative wins correctly", {
    scores <- build_test_scores()
    long <- scores_to_long(scores)
    result <- add_cumulative_record(long)

    # A wins both games
    a_rows <- result |> filter(team == "A") |> arrange(team_game_index)
    expect_equal(a_rows$wins_to_date, c(1L, 2L))
    expect_equal(a_rows$losses_to_date, c(0L, 0L))

    # B loses both games
    b_rows <- result |> filter(team == "B") |> arrange(team_game_index)
    expect_equal(b_rows$wins_to_date, c(0L, 0L))
    expect_equal(b_rows$losses_to_date, c(1L, 2L))
  })

  it("games_played_to_date equals wins_to_date + losses_to_date", {
    scores <- build_test_scores()
    long <- scores_to_long(scores)
    result <- add_cumulative_record(long)

    expect_equal(
      result$games_played_to_date,
      result$wins_to_date + result$losses_to_date
    )
  })
})

# --- combine_elo_with_sos (long format) ---

describe("combine_elo_with_sos", {
  it("returns long-format output with one row per team per game", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    # 2 games * 2 teams = 4 rows
    expect_equal(nrow(result), nrow(scores) * 2)
  })

  it("includes cumulative record columns", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    required_cols <- c(
      "team", "team_game_index",
      "wins_to_date", "losses_to_date", "games_played_to_date"
    )
    expect_all_in(required_cols, names(result))
  })

  it("includes integer wins and losses columns", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    expect_all_in(c("wins", "losses"), names(result))
    expect_equal(is.integer(result$wins), TRUE)
    expect_equal(is.integer(result$losses), TRUE)
  })

  it("wins and losses match wins_to_date and losses_to_date", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    expect_equal(result$wins, result$wins_to_date)
    expect_equal(result$losses, result$losses_to_date)
  })

  it("wins and losses are running totals per team", {
    # 3 games: A beats B, C beats A, B beats C
    scores <- tibble(
      date = as.Date(c("2026-01-05", "2026-01-06", "2026-01-07")),
      game_id = c("g1", "g2", "g3"),
      home_team = c("A", "C", "B"),
      away_team = c("B", "A", "C"),
      home_team_score = c(80, 90, 85),
      away_team_score = c(70, 75, 80),
      season = c(2026, 2026, 2026),
      season_type = rep("Regular Season", 3)
    )

    elo_with_sos <- tibble(
      team = rep(c("A", "B", "C"), each = 3),
      elo_rating = rep(1500, 9),
      games_played = rep(c(0L, 1L, 2L), 3),
      games_remaining = rep(c(2L, 1L, 0L), 3),
      remaining_estimated_wins = rep(0.5, 9)
    )

    result <- combine_elo_with_sos(elo_with_sos, scores)

    # A: wins game 1 (1-0), loses game 2 (1-1)
    a_rows <- result |> filter(team == "A") |> arrange(team_game_index)
    expect_equal(a_rows$wins, c(1L, 1L))
    expect_equal(a_rows$losses, c(0L, 1L))

    # B: loses game 1 (0-1), wins game 3 (1-1)
    b_rows <- result |> filter(team == "B") |> arrange(team_game_index)
    expect_equal(b_rows$wins, c(0L, 1L))
    expect_equal(b_rows$losses, c(1L, 1L))

    # C: wins game 2 (1-0), loses game 3 (1-1)
    c_rows <- result |> filter(team == "C") |> arrange(team_game_index)
    expect_equal(c_rows$wins, c(1L, 1L))
    expect_equal(c_rows$losses, c(0L, 1L))
  })

  it("includes SOS columns from elo_with_sos", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    sos_cols <- c(
      "games_remaining", "remaining_estimated_wins"
    )
    expect_all_in(sos_cols, names(result))
  })

  it("includes total_estimated_wins", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    expect_in("total_estimated_wins", names(result))
  })

  it("joins SOS by team and team_game_index", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    # A's first game: team_game_index=1, games_remaining=1,
    # remaining_estimated_wins=0.6
    a_g1 <- result |> filter(team == "A", team_game_index == 1)
    expect_equal(nrow(a_g1), 1)
    expect_equal(a_g1$games_remaining, 1L)
    expect_equal(a_g1$remaining_estimated_wins, 0.6)

    # B's first game: team_game_index=1, games_remaining=1,
    # remaining_estimated_wins=0.4
    b_g1 <- result |> filter(team == "B", team_game_index == 1)
    expect_equal(nrow(b_g1), 1)
    expect_equal(b_g1$games_remaining, 1L)
    expect_equal(b_g1$remaining_estimated_wins, 0.4)
  })

  it("computes total_estimated_wins as wins_to_date + remaining_estimated_wins", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    expect_equal(
      result$total_estimated_wins,
      result$wins_to_date + result$remaining_estimated_wins
    )
  })

  it("has no NA values in join-derived fields", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- combine_elo_with_sos(elo_with_sos, scores)

    expect_equal(sum(is.na(result$games_remaining)), 0)
    expect_equal(sum(is.na(result$remaining_estimated_wins)), 0)
    expect_equal(sum(is.na(result$total_estimated_wins)), 0)
    expect_equal(sum(is.na(result$wins_to_date)), 0)
    expect_equal(sum(is.na(result$losses_to_date)), 0)
  })

  it("errors when elo_with_sos is missing a team-game key", {
    scores <- build_test_scores()

    # elo_with_sos missing team B's game 2
    incomplete_sos <- tibble(
      team = c("A", "A", "A", "B", "B"),
      elo_rating = c(1500, 1516, 1532, 1500, 1484),
      games_played = c(0L, 1L, 2L, 0L, 1L),
      games_remaining = c(2L, 1L, 0L, 2L, 1L),
      remaining_estimated_wins = c(1.1, 0.6, 0.0, 0.9, 0.4)
    )

    expect_error(
      combine_elo_with_sos(incomplete_sos, scores),
      "unmatched"
    )
  })

  it("errors on duplicate team-game keys in long scores", {
    # Scores with a duplicated game
    dup_scores <- tibble(
      date = as.Date(c("2026-01-05", "2026-01-05")),
      game_id = c("g1", "g1"),
      home_team = c("A", "A"),
      away_team = c("B", "B"),
      home_team_score = c(80, 80),
      away_team_score = c(70, 70),
      season = c(2026, 2026),
      season_type = c("Regular Season", "Regular Season")
    )

    expect_error(
      scores_to_long(dup_scores),
      "duplicate"
    )
  })
})

# --- Edge cases ---

describe("scores_to_long edge cases", {
  it("handles same-day games (doubleheaders) deterministically", {
    # Two games on the same date, different game_ids
    scores <- tibble(
      date = as.Date(c("2026-01-05", "2026-01-05")),
      game_id = c("g1", "g2"),
      home_team = c("A", "C"),
      away_team = c("B", "D"),
      home_team_score = c(80, 90),
      away_team_score = c(70, 85),
      season = c(2026, 2026),
      season_type = c("Regular Season", "Regular Season")
    )

    result <- scores_to_long(scores)

    # 2 games * 2 teams = 4 rows
    expect_equal(nrow(result), 4)

    # Each team appears exactly once
    expect_equal(
      sort(result$team),
      c("A", "B", "C", "D")
    )
  })

  it("handles a team playing twice on the same day", {
    # Team A plays two games on the same day (different game_ids)
    scores <- tibble(
      date = as.Date(c("2026-01-05", "2026-01-05")),
      game_id = c("g1", "g2"),
      home_team = c("A", "B"),
      away_team = c("B", "A"),
      home_team_score = c(80, 90),
      away_team_score = c(70, 85),
      season = c(2026, 2026),
      season_type = c("Regular Season", "Regular Season")
    )

    result <- scores_to_long(scores)

    # 2 games * 2 teams = 4 rows
    expect_equal(nrow(result), 4)

    # A appears twice (once per game)
    a_rows <- result |> filter(team == "A")
    expect_equal(nrow(a_rows), 2)
  })
})

describe("add_cumulative_record with three teams", {
  it("tracks independent records across multiple teams", {
    # 3 games: A beats B, C beats A, B beats C
    scores <- tibble(
      date = as.Date(c("2026-01-05", "2026-01-06", "2026-01-07")),
      game_id = c("g1", "g2", "g3"),
      home_team = c("A", "C", "B"),
      away_team = c("B", "A", "C"),
      home_team_score = c(80, 90, 85),
      away_team_score = c(70, 75, 80),
      season = c(2026, 2026, 2026),
      season_type = rep("Regular Season", 3)
    )

    long <- scores_to_long(scores)
    result <- add_cumulative_record(long)

    # A: wins game 1, loses game 2 => 1-1
    a_rows <- result |> filter(team == "A") |> arrange(team_game_index)
    expect_equal(a_rows$team_game_index, c(1L, 2L))
    expect_equal(a_rows$wins_to_date, c(1L, 1L))
    expect_equal(a_rows$losses_to_date, c(0L, 1L))

    # B: loses game 1, wins game 3 => 1-1
    b_rows <- result |> filter(team == "B") |> arrange(team_game_index)
    expect_equal(b_rows$team_game_index, c(1L, 2L))
    expect_equal(b_rows$wins_to_date, c(0L, 1L))
    expect_equal(b_rows$losses_to_date, c(1L, 1L))

    # C: wins game 2, loses game 3 => 1-1
    c_rows <- result |> filter(team == "C") |> arrange(team_game_index)
    expect_equal(c_rows$team_game_index, c(1L, 2L))
    expect_equal(c_rows$wins_to_date, c(1L, 1L))
    expect_equal(c_rows$losses_to_date, c(0L, 1L))
  })
})

# --- add_wins_losses_to_sos ---

describe("add_wins_losses_to_sos", {
  it("adds integer wins and losses columns", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- add_wins_losses_to_sos(elo_with_sos, scores)

    expect_all_in(c("wins", "losses"), names(result))
    expect_equal(is.integer(result$wins), TRUE)
    expect_equal(is.integer(result$losses), TRUE)
  })

  it("games_played=0 rows get wins=0 and losses=0", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- add_wins_losses_to_sos(elo_with_sos, scores)

    zero_rows <- result |> filter(games_played == 0)
    expect_equal(unique(zero_rows$wins), 0L)
    expect_equal(unique(zero_rows$losses), 0L)
  })

  it("running wins/losses align with games_played snapshot", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- add_wins_losses_to_sos(elo_with_sos, scores)

    # A wins both games: after 1 game => 1-0, after 2 => 2-0
    a_rows <- result |>
      filter(team == "A") |>
      arrange(games_played)
    expect_equal(a_rows$wins, c(0L, 1L, 2L))
    expect_equal(a_rows$losses, c(0L, 0L, 0L))

    # B loses both games: after 1 game => 0-1, after 2 => 0-2
    b_rows <- result |>
      filter(team == "B") |>
      arrange(games_played)
    expect_equal(b_rows$wins, c(0L, 0L, 0L))
    expect_equal(b_rows$losses, c(0L, 1L, 2L))
  })

  it("preserves all original SOS columns", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- add_wins_losses_to_sos(elo_with_sos, scores)

    original_cols <- c(
      "team", "elo_rating", "games_played",
      "games_remaining", "remaining_estimated_wins"
    )
    expect_all_in(original_cols, names(result))
  })

  it("has no NA values in wins or losses", {
    elo_with_sos <- build_test_elo_with_sos()
    scores <- build_test_scores()

    result <- add_wins_losses_to_sos(elo_with_sos, scores)

    expect_equal(sum(is.na(result$wins)), 0)
    expect_equal(sum(is.na(result$losses)), 0)
  })
})
