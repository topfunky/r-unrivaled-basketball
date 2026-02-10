# Purpose: Functions for extracting the full season schedule
# (completed + upcoming games) and calculating remaining
# strength of schedule based on Elo ratings.

#' Extract all games from schedule HTML (completed and upcoming)
#'
#' Parses the main layout of the Unrivaled schedule HTML and
#' extracts both Final and Scheduled games. Returns a tibble
#' with date, teams, game_id, and status for every game.
#'
#' @param html An rvest html_document of the schedule page
#' @param season_year The season year (e.g., 2026)
#' @return tibble with columns: date, away_team, home_team,
#'   game_id, status
#' @export
extract_all_schedule_games <- function(html, season_year = 2026) {
  s_params <- get_season_params(season_year)

  main_days <- html |>
    rvest::html_elements("div.flex.row-12.p-12")

  all_games <- list()

  for (day_container in main_days) {
    date_el <- day_container |>
      rvest::html_element("span.uppercase.weight-500")

    if (is.null(date_el)) next

    date_text <- rvest::html_text(date_el)
    game_date <- parse_date_text(date_text, season_year)

    if (is.na(game_date)) next

    cards <- day_container |>
      rvest::html_elements("div.flex.w-100.radius-8")

    for (card in cards) {
      game <- parse_schedule_card(card, game_date, s_params)
      if (!is.null(game)) {
        all_games[[length(all_games) + 1]] <- game
      }
    }
  }

  if (length(all_games) == 0) {
    return(tibble::tibble(
      date = as.Date(character()),
      away_team = character(),
      home_team = character(),
      game_id = character(),
      status = character()
    ))
  }

  result <- dplyr::bind_rows(all_games)

  # Only deduplicate rows that have a non-NA game_id
  has_id <- result |> dplyr::filter(!is.na(game_id))
  no_id <- result |> dplyr::filter(is.na(game_id))

  dplyr::bind_rows(
    has_id |> dplyr::distinct(game_id, .keep_all = TRUE),
    no_id
  )
}

#' Parse a single schedule card from the main layout
#'
#' Extracts game information from a div.flex.w-100.radius-8
#' card. Works for both Final and upcoming (Scheduled) games.
#'
#' @param card HTML node of the game card
#' @param game_date Date of the game
#' @param s_params Season parameters from get_season_params()
#' @return Single-row tibble or NULL if card cannot be parsed
parse_schedule_card <- function(card, game_date, s_params) {
  valid_teams <- s_params$valid_teams

  # Extract status text from the status span
  status_el <- card |>
    rvest::html_element("span.uppercase.weight-500.font-14")

  status_text <- if (!is.null(status_el)) {
    trimws(rvest::html_text(status_el))
  } else {
    NA_character_
  }

  status <- if (!is.na(status_text) && status_text == "Final") {
    "Final"
  } else {
    "Scheduled"
  }

  # Extract team names from div.color-blue (Final games) or
  # img alt attributes (upcoming games with logo-only display)
  teams <- card |>
    rvest::html_elements("div.color-blue.weight-500.font-14") |>
    rvest::html_text()

  if (length(teams) < 2) {
    img_alts <- card |>
      rvest::html_elements("img[alt*='Logo']") |>
      rvest::html_attr("alt")
    teams <- gsub(" Logo$", "", img_alts)
  }

  if (length(teams) < 2) return(NULL)

  away_team <- teams[1]
  home_team <- teams[2]

  if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
    return(NULL)
  }


  # Extract game_id from any game link (box-score or direct)
  game_link <- card |>
    rvest::html_element("a[href*='/game/']")

  game_id <- if (!is.null(game_link)) {
    href <- rvest::html_attr(game_link, "href")
    gsub("/box-score$", "", gsub(".*/game/", "", href))
  } else {
    NA_character_
  }

  tibble::tibble(
    date = game_date,
    away_team = away_team,
    home_team = home_team,
    game_id = game_id,
    status = status
  )
}

#' Calculate remaining strength of schedule
#'
#' For each team at each games_played level in the Elo table,
#' calculates the expected remaining wins based on the team's
#' current Elo and the Elo of each future opponent.
#'
#' Remaining games are all games in the full schedule that have
#' not yet been played (status != "Final"), minus games that
#' correspond to games the team has already played at this
#' games_played count.
#'
#' @param elo_table tibble with columns: team, elo_rating,
#'   games_played
#' @param full_schedule tibble with columns: away_team,
#'   home_team, status
#' @return The elo_table with added columns: games_remaining,
#'   remaining_estimated_wins
#' @export
calculate_remaining_sos <- function(elo_table, full_schedule) {
  total_games_per_team <- full_schedule |>
    tidyr::pivot_longer(
      cols = c(away_team, home_team),
      names_to = "role",
      values_to = "team"
    ) |>
    dplyr::count(team, name = "total_games")

  # Build opponent schedule: for each team, list all opponents
  # with a game index (order of appearance)
  team_schedules <- full_schedule |>
    dplyr::mutate(game_order = dplyr::row_number()) |>
    tidyr::pivot_longer(
      cols = c(away_team, home_team),
      names_to = "role",
      values_to = "team"
    ) |>
    dplyr::mutate(
      opponent = dplyr::if_else(
        role == "away_team",
        # opponent is the home_team from original row
        full_schedule$home_team[game_order],
        full_schedule$away_team[game_order]
      )
    ) |>
    dplyr::group_by(team) |>
    dplyr::mutate(team_game_number = dplyr::row_number()) |>
    dplyr::ungroup() |>
    dplyr::select(team, team_game_number, opponent)

  # For each row in elo_table, find remaining games and compute
  # expected wins
  result <- elo_table |>
    dplyr::left_join(total_games_per_team, by = "team") |>
    dplyr::mutate(
      total_games = dplyr::if_else(is.na(total_games), 0L, total_games),
      games_remaining = pmax(total_games - games_played, 0L)
    ) |>
    dplyr::rowwise() |>
    dplyr::mutate(
      remaining_estimated_wins = compute_expected_wins(
        team,
        games_played,
        elo_rating,
        team_schedules,
        elo_table
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-total_games)

  result
}

#' Compute expected wins for remaining games
#'
#' For a given team at a given games_played count, looks up
#' the team's remaining opponents and sums win probabilities.
#'
#' @param team_name Name of the team
#' @param n_played Number of games already played
#' @param my_elo Team's current Elo rating
#' @param team_schedules Full team schedule with game order
#' @param elo_table Full Elo table for looking up opponent Elo
#' @return Numeric expected remaining wins
compute_expected_wins <- function(
  team_name,
  n_played,
  my_elo,
  team_schedules,
  elo_table
) {
  # Remaining games are those with team_game_number > n_played
  remaining <- team_schedules |>
    dplyr::filter(
      team == team_name,
      team_game_number > n_played
    )

  if (nrow(remaining) == 0) return(0)

  # Look up each opponent's Elo at their latest known rating
  # Use the opponent's most recent Elo from the elo_table
  opponent_elos <- remaining |>
    dplyr::left_join(
      elo_table |>
        dplyr::group_by(team) |>
        dplyr::slice_max(games_played, n = 1, with_ties = FALSE) |>
        dplyr::ungroup() |>
        dplyr::select(team, opp_elo = elo_rating),
      by = c("opponent" = "team")
    ) |>
    dplyr::mutate(
      opp_elo = dplyr::if_else(is.na(opp_elo), 1500, opp_elo)
    )

  sum(purrr::map_dbl(
    opponent_elos$opp_elo,
    ~ elo_win_prob(my_elo, .x)
  ))
}
