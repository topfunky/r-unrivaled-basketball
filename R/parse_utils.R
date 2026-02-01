# Purpose: Utility functions for parsing play-by-play, box score, and summary
# data from downloaded game HTML files.
#
# Dependencies: tidyverse, rvest, fs

#' Parse play-by-play data for a single game
#'
#' @param game_id The game ID
#' @param season_year The season year
#' @return tibble of play-by-play data or NULL if file not found
#' @export
parse_play_by_play <- function(game_id, season_year) {
  play_by_play_file <- fs::path(
    "games",
    season_year,
    game_id,
    "play-by-play.html"
  )
  if (!fs::file_exists(play_by_play_file)) {
    warning(sprintf("Play by play file not found for game %s", game_id))
    return(NULL)
  }

  html <- rvest::read_html(play_by_play_file)

  tables <- html |> rvest::html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf(
      "No tables found in play by play file for game %s",
      game_id
    ))
    return(NULL)
  }

  table_data <- rvest::html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in play by play file for game %s", game_id))
    return(NULL)
  }

  # Extract possessing team from image alt text
  play_cells <- html |> rvest::html_nodes("td:nth-child(2)")
  pos_teams <- purrr::map_chr(play_cells, function(cell) {
    img <- rvest::html_node(cell, "img")
    if (!is.null(img)) {
      alt_text <- rvest::html_attr(img, "alt")
      if (!is.na(alt_text) && stringr::str_detect(alt_text, "Logo$")) {
        return(stringr::str_remove(alt_text, " Logo$"))
      }
    }
    return(NA_character_)
  })

  plays <- table_data[[1]] |>
    tibble::as_tibble() |>
    purrr::set_names(c("time", "play", "score")) |>
    dplyr::mutate(
      game_id = game_id,
      season = season_year,
      quarter = dplyr::if_else(
        stringr::str_detect(play, "^Q\\d"),
        as.numeric(stringr::str_match(play, "^Q(\\d)")[, 2]),
        NA_real_
      ),
      play = dplyr::if_else(
        stringr::str_detect(play, "^Q\\d"),
        stringr::str_remove(play, "^Q\\d"),
        play
      ),
      away_score = as.numeric(stringr::str_extract(score, "^\\d+")),
      home_score = as.numeric(stringr::str_extract(score, "\\d+$")),
      minute = dplyr::if_else(
        stringr::str_detect(time, ":"),
        as.numeric(stringr::str_extract(time, "^\\d+")),
        0
      ),
      second = dplyr::if_else(
        stringr::str_detect(time, ":"),
        round(as.numeric(stringr::str_extract(time, "\\d+\\.?\\d*$"))),
        round(as.numeric(time))
      ),
      pos_team = pos_teams
    ) |>
    dplyr::select(
      game_id,
      season,
      quarter,
      time,
      minute,
      second,
      play,
      pos_team,
      away_score,
      home_score
    )

  return(plays)
}

#' Parse box score data for a single game
#'
#' @param game_id The game ID
#' @param season_year The season year
#' @return tibble of box score data or NULL if file not found
#' @export
parse_box_score <- function(game_id, season_year) {
  box_score_file <- fs::path("games", season_year, game_id, "box-score.html")
  if (!fs::file_exists(box_score_file)) {
    warning(sprintf("Box score file not found for game %s", game_id))
    return(NULL)
  }

  html <- rvest::read_html(box_score_file)

  tables <- html |> rvest::html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf("No tables found in box score file for game %s", game_id))
    return(NULL)
  }

  table_data <- rvest::html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in box score file for game %s", game_id))
    return(NULL)
  }

  box_score <- table_data[[1]] |>
    tibble::as_tibble() |>
    dplyr::mutate(
      game_id = game_id,
      season = season_year,
      MIN = as.character(MIN),
      is_starter = stringr::str_starts(PLAYERS, "S "),
      player_name_raw = dplyr::if_else(
        is_starter,
        stringr::str_remove(PLAYERS, "^S "),
        PLAYERS
      )
    ) |>
    dplyr::filter(
      !is.na(player_name_raw),
      stringr::str_trim(player_name_raw) != "",
      stringr::str_trim(player_name_raw) != "TEAM"
    ) |>
    dplyr::mutate(
      jersey_number = as.numeric(
        stringr::str_extract(player_name_raw, "(?<=#)\\d+$")
      ),
      player_name = stringr::str_remove(player_name_raw, " #\\d+$")
    ) |>
    dplyr::mutate(
      field_goals_made = as.numeric(stringr::str_extract(FG, "^\\d+")),
      field_goals_attempted = as.numeric(stringr::str_extract(FG, "\\d+$")),
      three_point_field_goals_made = as.numeric(
        stringr::str_extract(`3PT`, "^\\d+")
      ),
      three_point_field_goals_attempted = as.numeric(
        stringr::str_extract(`3PT`, "\\d+$")
      ),
      free_throws_made = as.numeric(stringr::str_extract(FT, "^\\d+")),
      free_throws_attempted = as.numeric(stringr::str_extract(FT, "\\d+$")),
      two_point_field_goals_made = field_goals_made -
        three_point_field_goals_made,
      two_point_field_goals_attempted = field_goals_attempted -
        three_point_field_goals_attempted,
      dplyr::across(
        c(REB, OREB, DREB, AST, STL, BLK, TO, PF, PTS),
        ~ as.numeric(.)
      )
    ) |>
    dplyr::select(
      game_id,
      season,
      is_starter,
      player_name,
      jersey_number,
      MIN,
      field_goals_made,
      field_goals_attempted,
      three_point_field_goals_made,
      three_point_field_goals_attempted,
      free_throws_made,
      free_throws_attempted,
      two_point_field_goals_made,
      two_point_field_goals_attempted,
      REB,
      OREB,
      DREB,
      AST,
      STL,
      BLK,
      TO,
      PF,
      PTS
    )

  return(box_score)
}

#' Parse summary data for a single game
#'
#' @param game_id The game ID
#' @param season_year The season year
#' @return tibble of summary data or NULL if file not found
#' @export
parse_summary <- function(game_id, season_year) {
  summary_file <- fs::path("games", season_year, game_id, "summary.html")
  if (!fs::file_exists(summary_file)) {
    warning(sprintf("Summary file not found for game %s", game_id))
    return(NULL)
  }

  html <- rvest::read_html(summary_file)

  tables <- html |> rvest::html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf("No tables found in summary file for game %s", game_id))
    return(NULL)
  }

  table_data <- rvest::html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in summary file for game %s", game_id))
    return(NULL)
  }

  summary <- table_data[[1]] |>
    tibble::as_tibble(.name_repair = "minimal") |>
    purrr::set_names(c("col1", "col2", "col3")) |>
    dplyr::filter(
      col1 %in%
        c("FG", "Field Goal %", "3PT", "Three Point %", "FT", "Free Throw %")
    ) |>
    dplyr::mutate(
      game_id = game_id,
      season = season_year,
      stat = dplyr::case_when(
        col1 == "FG" ~ "field_goals",
        col1 == "Field Goal %" ~ "field_goal_pct",
        col1 == "3PT" ~ "three_pointers",
        col1 == "Three Point %" ~ "three_point_pct",
        col1 == "FT" ~ "free_throws",
        col1 == "Free Throw %" ~ "free_throw_pct",
        TRUE ~ col1
      )
    ) |>
    tidyr::pivot_longer(
      cols = c(col2, col3),
      names_to = "team_col",
      values_to = "value"
    ) |>
    dplyr::mutate(
      team = dplyr::if_else(team_col == "col2", "team_a", "team_b")
    ) |>
    dplyr::select(game_id, season, team, stat, value) |>
    tidyr::pivot_wider(
      names_from = stat,
      values_from = value
    ) |>
    dplyr::mutate(
      field_goal_pct = as.numeric(stringr::str_remove(field_goal_pct, "%")),
      three_point_pct = as.numeric(stringr::str_remove(three_point_pct, "%")),
      free_throw_pct = as.numeric(stringr::str_remove(free_throw_pct, "%"))
    )

  return(summary)
}

#' Process all games for a season
#'
#' @param season_year The season year
#' @return List containing play_by_play, box_score, and summary tibbles
#' @export
process_season <- function(season_year) {
  season_dir <- fs::path("games", season_year)
  if (!fs::dir_exists(season_dir)) {
    return(NULL)
  }

  game_dirs <- fs::dir_ls(season_dir, type = "directory") |>
    fs::path_file()

  list(
    play_by_play = purrr::map_dfr(
      game_dirs,
      ~ parse_play_by_play(.x, season_year)
    ),
    box_score = purrr::map_dfr(game_dirs, ~ parse_box_score(.x, season_year)),
    summary = purrr::map_dfr(game_dirs, ~ parse_summary(.x, season_year))
  )
}
