# Purpose: Tests for remaining strength of schedule features
# Tests schedule parsing for upcoming games and SOS calculation

library(dplyr)

describe("extract_all_schedule_games", {
  it("extracts both final and upcoming games from main layout", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    # Should find 4 games total: 2 final + 2 upcoming
    expect_equal(nrow(games), 4)
  })

  it("correctly identifies game status", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    expect_equal(sum(games$status == "Final"), 2)
    expect_equal(sum(games$status == "Scheduled"), 2)
  })

  it("extracts team names for upcoming games", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)
    upcoming <- games |> filter(status == "Scheduled")

    expect_equal(nrow(upcoming), 2)
    all_teams <- c(upcoming$away_team, upcoming$home_team)
    expect_in("Hive", all_teams)
    expect_in("Breeze", all_teams)
    expect_in("Rose", all_teams)
    expect_in("Phantom", all_teams)
  })

  it("extracts dates for all games", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    expect_true(all(!is.na(games$date)))
    expect_equal(games$date[1], as.Date("2026-01-05"))
    expect_equal(games$date[3], as.Date("2026-01-09"))
  })

  it("returns expected columns", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    expected_cols <- c("date", "away_team", "home_team", "game_id", "status")
    expect_all_in(expected_cols, names(games))
  })

  it("extracts game IDs from box-score links", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)
    final_games <- games |> filter(status == "Final")

    expect_equal(final_games$game_id[1], "abc123")
    expect_equal(final_games$game_id[2], "def456")
  })

  it("extracts game IDs from upcoming game links", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)
    upcoming_games <- games |> filter(status == "Scheduled")

    expect_equal(upcoming_games$game_id[1], "upcoming01")
    expect_equal(upcoming_games$game_id[2], "upcoming02")
  })

  it("extracts teams from img alt attributes for upcoming games", {
    fixture_path <- find_fixture("schedule_with_upcoming_main.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)
    upcoming <- games |> filter(status == "Scheduled")

    # First upcoming: Hive @ Breeze
    expect_equal(upcoming$away_team[1], "Hive")
    expect_equal(upcoming$home_team[1], "Breeze")

    # Second upcoming: Rose @ Phantom
    expect_equal(upcoming$away_team[2], "Rose")
    expect_equal(upcoming$home_team[2], "Phantom")
  })
})

describe("extract_all_schedule_games with real 2026 fixture", {
  it("extracts all 56 regular season games", {
    fixture_path <- find_fixture("2026/schedule.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    expect_equal(nrow(games), 56)
  })

  it("finds 14 games per team", {
    fixture_path <- find_fixture("2026/schedule.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    all_team_games <- c(games$away_team, games$home_team)
    games_per_team <- table(all_team_games)

    for (team in names(games_per_team)) {
      expect_equal(
        as.integer(games_per_team[[team]]),
        14L,
        label = paste(team, "games count")
      )
    }
  })

  it("includes both Final and Scheduled games", {
    fixture_path <- find_fixture("2026/schedule.html")
    html <- rvest::read_html(fixture_path)

    games <- extract_all_schedule_games(html, season_year = 2026)

    expect_gt(sum(games$status == "Final"), 0)
    expect_gt(sum(games$status == "Scheduled"), 0)
  })
})

describe("calculate_remaining_sos", {
  it("returns a tibble with games_played, games_remaining, and remaining_estimated_wins", {
    # Minimal elo table: team played 1 game with elo 1516
    elo_table <- tibble(
      team = c("A", "A", "B", "B"),
      elo_rating = c(1516, 1516, 1484, 1484),
      games_played = c(1, 1, 1, 1)
    )

    # Full schedule: A plays B twice total
    full_schedule <- tibble(
      away_team = c("A", "B"),
      home_team = c("B", "A"),
      status = c("Final", "Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    expected_cols <- c(
      "team", "games_played", "games_remaining", "remaining_estimated_wins"
    )
    expect_all_in(expected_cols, names(result))
  })

  it("calculates remaining wins using elo_win_prob", {
    # Team A has elo 1600, team B has elo 1400
    # A has one remaining game against B
    elo_table <- tibble(
      team = c("A", "B"),
      elo_rating = c(1600, 1400),
      games_played = c(1, 1)
    )

    full_schedule <- tibble(
      away_team = c("A", "B"),
      home_team = c("B", "A"),
      status = c("Final", "Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    expected_prob_a <- elo_win_prob(1600, 1400)
    expected_prob_b <- elo_win_prob(1400, 1600)

    result_a <- result |> filter(team == "A")
    result_b <- result |> filter(team == "B")

    expect_equal(result_a$remaining_estimated_wins, expected_prob_a)
    expect_equal(result_b$remaining_estimated_wins, expected_prob_b)
  })

  it("sums probabilities across multiple remaining games", {
    elo_table <- tibble(
      team = c("A", "B", "C"),
      elo_rating = c(1600, 1400, 1500),
      games_played = c(1, 1, 1)
    )

    # A has played B (Final), still has to play B again and C
    full_schedule <- tibble(
      away_team = c("A", "B", "A"),
      home_team = c("B", "A", "C"),
      status = c("Final", "Scheduled", "Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)
    result_a <- result |> filter(team == "A")

    expected <- elo_win_prob(1600, 1400) + elo_win_prob(1600, 1500)
    expect_equal(result_a$remaining_estimated_wins, expected)
  })

  it("returns 0 remaining wins when no games remain", {
    elo_table <- tibble(
      team = c("A", "B"),
      elo_rating = c(1600, 1400),
      games_played = c(2, 2)
    )

    full_schedule <- tibble(
      away_team = c("A", "B"),
      home_team = c("B", "A"),
      status = c("Final", "Final")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    expect_equal(result$remaining_estimated_wins[result$team == "A"], 0)
    expect_equal(result$remaining_estimated_wins[result$team == "B"], 0)
  })

  it("uses initial elo of 1500 for teams with zero games played", {
    elo_table <- tibble(
      team = c("A", "B"),
      elo_rating = c(1500, 1500),
      games_played = c(0, 0)
    )

    full_schedule <- tibble(
      away_team = c("A"),
      home_team = c("B"),
      status = c("Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    # Both teams equal elo, so remaining_estimated_wins = 0.5
    expect_equal(result$remaining_estimated_wins[result$team == "A"], 0.5)
    expect_equal(result$remaining_estimated_wins[result$team == "B"], 0.5)
  })

  it("calculates games_remaining correctly", {
    elo_table <- tibble(
      team = c("A", "B", "C"),
      elo_rating = c(1600, 1400, 1500),
      games_played = c(1, 1, 0)
    )

    full_schedule <- tibble(
      away_team = c("A", "B", "A"),
      home_team = c("B", "C", "C"),
      status = c("Final", "Scheduled", "Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    # A played 1, has 1 remaining (vs C)
    expect_equal(result$games_remaining[result$team == "A"], 1)
    # B played 1, has 1 remaining (vs C)
    expect_equal(result$games_remaining[result$team == "B"], 1)
    # C played 0, has 2 remaining (vs B and vs A)
    expect_equal(result$games_remaining[result$team == "C"], 2)
  })

  it("tracks remaining SOS at each games_played level", {
    # After 0 games, A has 2 remaining; after 1 game, A has 1 remaining
    elo_table <- tibble(
      team = c("A", "A", "B", "B"),
      elo_rating = c(1500, 1516, 1500, 1484),
      games_played = c(0, 1, 0, 1)
    )

    full_schedule <- tibble(
      away_team = c("A", "B"),
      home_team = c("B", "A"),
      status = c("Final", "Scheduled")
    )

    result <- calculate_remaining_sos(elo_table, full_schedule)

    # At games_played=0, A has 2 games remaining
    a_gp0 <- result |> filter(team == "A", games_played == 0)
    expect_equal(a_gp0$games_remaining, 2)

    # At games_played=1, A has 1 game remaining
    a_gp1 <- result |> filter(team == "A", games_played == 1)
    expect_equal(a_gp1$games_remaining, 1)
  })
})
