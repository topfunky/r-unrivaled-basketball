# Purpose: Functions to combine per-game Elo ratings history
# with remaining strength of schedule and current win counts
# into a single long-format output table (one row per team
# per game).

#' Convert wide-format scores to long format (one row per team per game)
#'
#' Each game produces two rows: one for the home team and one for the
#' away team. Validates that no duplicate (game_id, team) pairs exist.
#'
#' @param scores Tibble with home_team, away_team, home_team_score,
#'   away_team_score, date, game_id columns
#' @return Tibble with columns: date, game_id, team, opponent,
#'   team_score, opponent_score, won
#' @export
scores_to_long <- function(scores) {
  home_rows <- scores |>
    dplyr::transmute(
      date = date,
      game_id = game_id,
      team = home_team,
      opponent = away_team,
      team_score = home_team_score,
      opponent_score = away_team_score,
      won = as.integer(home_team_score > away_team_score)
    )

  away_rows <- scores |>
    dplyr::transmute(
      date = date,
      game_id = game_id,
      team = away_team,
      opponent = home_team,
      team_score = away_team_score,
      opponent_score = home_team_score,
      won = as.integer(away_team_score > home_team_score)
    )

  long <- dplyr::bind_rows(home_rows, away_rows) |>
    dplyr::arrange(date, game_id, team)

  # Validate no duplicate (game_id, team) pairs
  dup_check <- long |>
    dplyr::count(game_id, team) |>
    dplyr::filter(n > 1)

  if (nrow(dup_check) > 0) {
    dup_desc <- paste(
      dup_check$game_id, dup_check$team,
      sep = "/", collapse = ", "
    )
    stop(paste(
      "scores_to_long found duplicate (game_id, team) pairs:",
      dup_desc
    ))
  }

  long
}

#' Add cumulative record columns to long-format game data
#'
#' Computes team_game_index (1-based chronological game number
#' per team), wins_to_date, losses_to_date, and
#' games_played_to_date.
#'
#' @param long_scores Long-format scores from scores_to_long()
#' @return Input tibble with added cumulative columns
#' @export
add_cumulative_record <- function(long_scores) {
  long_scores |>
    dplyr::arrange(date, game_id, team) |>
    dplyr::group_by(team) |>
    dplyr::mutate(
      team_game_index = dplyr::row_number(),
      wins_to_date = cumsum(won),
      losses_to_date = cumsum(1L - won),
      games_played_to_date = team_game_index
    ) |>
    dplyr::ungroup()
}

#' Combine per-game Elo ratings with SOS and cumulative record
#'
#' Converts scores to long format, computes cumulative record,
#' then joins elo_with_sos by (team, team_game_index). Produces
#' one row per team per game with actual record and projected
#' remaining wins.
#'
#' Fails with an error if any team-game key is unmatched in the
#' join.
#'
#' @param elo_with_sos Per-team-per-games_played SOS table
#' @param scores Game scores for computing cumulative record
#' @return Long-format tibble with cumulative record and SOS
#' @export
combine_elo_with_sos <- function(elo_with_sos, scores) {
  long_scores <- scores_to_long(scores) |>
    add_cumulative_record()

  # Build SOS lookup keyed by team + games_played
  # (games_played in elo_with_sos corresponds to team_game_index)
  sos_lookup <- elo_with_sos |>
    dplyr::select(
      team,
      games_played,
      games_remaining,
      remaining_estimated_wins
    )

  # Join SOS by (team, team_game_index = games_played)
  combined <- long_scores |>
    dplyr::left_join(
      sos_lookup,
      by = c("team" = "team", "team_game_index" = "games_played")
    )

  # Validate no unmatched keys
  unmatched <- combined |>
    dplyr::filter(is.na(games_remaining) | is.na(remaining_estimated_wins))

  if (nrow(unmatched) > 0) {
    unmatched_desc <- unmatched |>
      dplyr::distinct(team, team_game_index) |>
      dplyr::mutate(
        desc = paste0(team, " game ", team_game_index)
      ) |>
      dplyr::pull(desc) |>
      paste(collapse = ", ")
    stop(paste(
      "combine_elo_with_sos found unmatched team-game keys:",
      unmatched_desc
    ))
  }

  # Compute total estimated wins
  combined |>
    dplyr::mutate(
      total_estimated_wins = wins_to_date + remaining_estimated_wins
    )
}
