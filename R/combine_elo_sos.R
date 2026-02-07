# Purpose: Functions to combine per-game Elo ratings history
# with remaining strength of schedule and current win counts
# into a single output table.

#' Compute per-team cumulative wins at each game
#'
#' Takes the scores data and returns one row per team per game
#' with the team's cumulative wins and games_played at that point.
#'
#' @param scores Tibble of game scores with home_team, away_team,
#'   home_team_score, away_team_score columns
#' @return Tibble with team, games_played, current_wins
#' @export
compute_current_wins <- function(scores) {
  home_rows <- scores |>
    dplyr::arrange(date) |>
    dplyr::mutate(
      team = home_team,
      won = as.integer(home_team_score > away_team_score)
    ) |>
    dplyr::select(date, game_id, team, won)

  away_rows <- scores |>
    dplyr::arrange(date) |>
    dplyr::mutate(
      team = away_team,
      won = as.integer(away_team_score > home_team_score)
    ) |>
    dplyr::select(date, game_id, team, won)

  dplyr::bind_rows(home_rows, away_rows) |>
    dplyr::arrange(date, game_id) |>
    dplyr::group_by(team) |>
    dplyr::mutate(
      games_played = dplyr::row_number(),
      current_wins = cumsum(won)
    ) |>
    dplyr::ungroup() |>
    dplyr::select(team, games_played, current_wins)
}

#' Combine per-game Elo ratings with SOS and current wins
#'
#' Joins remaining SOS data and current win counts onto the
#' per-game ratings_history table for both home and away teams.
#' Adds total_estimated_wins = current_wins + remaining_estimated_wins.
#'
#' @param ratings_history Per-game Elo ratings from get_ratings_history()
#' @param elo_with_sos Per-team-per-games_played SOS from add_remaining_sos()
#' @param scores Game scores for computing current wins
#' @return Combined tibble with all original columns plus SOS and wins
#' @export
combine_elo_with_sos <- function(ratings_history, elo_with_sos, scores) {
  # Build per-team current wins lookup

  current_wins <- compute_current_wins(scores)

  # Build SOS lookup keyed by team + games_played
  sos_lookup <- elo_with_sos |>
    dplyr::select(
      team,
      games_played,
      games_remaining,
      remaining_estimated_wins
    )

  # Compute home_team games_played per game row
  home_gp <- ratings_history |>
    dplyr::group_by(home_team) |>
    dplyr::mutate(home_team_games_played = dplyr::row_number()) |>
    dplyr::ungroup() |>
    dplyr::select(game_id, home_team_games_played)

  # Compute away_team games_played per game row
  away_gp <- ratings_history |>
    dplyr::group_by(away_team) |>
    dplyr::mutate(away_team_games_played = dplyr::row_number()) |>
    dplyr::ungroup() |>
    dplyr::select(game_id, away_team_games_played)

  combined <- ratings_history |>
    dplyr::left_join(home_gp, by = "game_id") |>
    dplyr::left_join(away_gp, by = "game_id") |>
    # Join SOS for home team
    dplyr::left_join(
      sos_lookup |>
        dplyr::rename(
          home_team_games_remaining = games_remaining,
          home_team_remaining_estimated_wins = remaining_estimated_wins
        ),
      by = c("home_team" = "team",
             "home_team_games_played" = "games_played")
    ) |>
    # Join SOS for away team
    dplyr::left_join(
      sos_lookup |>
        dplyr::rename(
          away_team_games_remaining = games_remaining,
          away_team_remaining_estimated_wins = remaining_estimated_wins
        ),
      by = c("away_team" = "team",
             "away_team_games_played" = "games_played")
    ) |>
    # Join current wins for home team
    dplyr::left_join(
      current_wins |>
        dplyr::rename(home_team_current_wins = current_wins),
      by = c("home_team" = "team",
             "home_team_games_played" = "games_played")
    ) |>
    # Join current wins for away team
    dplyr::left_join(
      current_wins |>
        dplyr::rename(away_team_current_wins = current_wins),
      by = c("away_team" = "team",
             "away_team_games_played" = "games_played")
    ) |>
    # Compute total estimated wins
    dplyr::mutate(
      home_team_total_estimated_wins =
        home_team_current_wins + home_team_remaining_estimated_wins,
      away_team_total_estimated_wins =
        away_team_current_wins + away_team_remaining_estimated_wins
    )

  combined
}
