# Purpose: Utility functions for scraping Unrivaled game data from HTML files.
# These functions parse schedule HTML and extract game results.
#
# Dependencies: tidyverse, rvest, lubridate, glue

#' Season parameters for scraping
#'
#' Returns a list of season-specific parameters including valid teams,
#' skip dates, postseason start, and schedule file path.
#'
#' @param season_year The season year (e.g., 2025, 2026)
#' @return List of season parameters or NULL if not found
#' @export
get_season_params <- function(season_year) {
  params <- list(
    `2025` = list(
      valid_teams = c(
        "Lunar Owls",
        "Mist",
        "Rose",
        "Laces",
        "Phantom",
        "Vinyl"
      ),
      skip_start = as.Date("2025-02-10"),
      skip_end = as.Date("2025-02-15"),
      postseason_start = as.Date("2025-03-16"),
      schedule_file = "data/2025/schedule.html"
    ),
    `2026` = list(
      valid_teams = c(
        "Lunar Owls",
        "Mist",
        "Rose",
        "Laces",
        "Phantom",
        "Vinyl",
        "Breeze",
        "Hive"
      ),
      skip_start = as.Date("2026-02-10"),
      skip_end = as.Date("2026-02-15"),
      postseason_start = as.Date("2026-03-16"),
      schedule_file = "data/2026/schedule.html"
    )
  )

  params[[as.character(season_year)]]
}

#' Parse a single game day from HTML
#'
#' @param day_node HTML node containing game day data
#' @param season_year The season year
#' @param s_params Season parameters from get_season_params()
#' @return tibble of game data or NULL if no valid games found
#' @export
parse_game_day <- function(day_node, season_year, s_params) {
  valid_teams <- s_params$valid_teams

  # Extract date from the day header with error handling
  if (season_year == 2026) {
    date_div <- day_node |>
      rvest::html_element(
        "div.flex.justify-center.items-center.h-100.row-4.weight-500"
      )
    if (is.null(date_div)) {
      warning("Could not find date element in day node (2026 format)")
      return(NULL)
    }
    date_text <- rvest::html_text(date_div)
    date_text <- stringr::str_replace(
      date_text,
      "([A-Za-z]+)([0-9]+)([A-Za-z]+)",
      "\\1 \\2 \\3"
    )
  } else {
    date_element <- day_node |>
      rvest::html_element("span.uppercase.weight-500")
    if (is.null(date_element)) {
      warning("Could not find date element in day node (2025 format)")
      return(NULL)
    }
    date_text <- rvest::html_text(date_element)
  }

  if (is.na(date_text) || date_text == "" || is.null(date_text)) {
    warning("Date text is empty or NA")
    return(NULL)
  }

  # Convert date text to Date object
  today <- as.Date(lubridate::now(tzone = "America/New_York"))
  game_date <- if (stringr::str_detect(date_text, "^Today")) {
    today
  } else if (stringr::str_detect(date_text, "^Tomorrow")) {
    today + 1
  } else {
    d <- as.Date(date_text, format = "%A, %B %d, %Y")
    if (is.na(d)) {
      d <- as.Date(date_text, format = "%a, %b %d, %Y")
    }
    if (is.na(d)) {
      date_parts <- stringr::str_match(
        date_text,
        "([A-Za-z]+)\\s*([0-9]+)\\s*([A-Za-z]+)"
      )
      if (!is.na(date_parts[1, 1])) {
        month_abbr <- date_parts[1, 2]
        day_num <- date_parts[1, 3]
        date_str <- paste(month_abbr, day_num, season_year, sep = " ")
        d <- as.Date(date_str, format = "%b %d %Y")
      }
    }
    d
  }

  if (is.na(game_date)) {
    warning(glue::glue("Could not parse date from text: {date_text}"))
    return(NULL)
  }

  # Skip games in the specified date range
  if (game_date >= s_params$skip_start && game_date <= s_params$skip_end) {
    warning(glue::glue(
      "Skipping games on {game_date} (within skip date range)"
    ))
    return(NULL)
  }

  # Find all games in this day
  games_2025 <- day_node |>
    rvest::html_elements("div.flex-row.w-100.items-center.col-12")
  games_2026 <- day_node |>
    rvest::html_elements("a[href*='/game/']")

  if (length(games_2025) >= 2) {
    games <- games_2025
    format_2026 <- FALSE
  } else if (length(games_2026) > 0) {
    games <- games_2026
    format_2026 <- TRUE
  } else {
    return(NULL)
  }

  game_data <- list()
  if (format_2026) {
    for (game_link in games) {
      final_indicator <- game_link |>
        rvest::html_element("span.font-10.uppercase.clamp1.weight-700")

      if (is.null(final_indicator)) {
        next
      }

      final_text <- rvest::html_text(final_indicator)
      if (is.na(final_text) || trimws(final_text) != "Final") {
        next
      }

      scores <- game_link |>
        rvest::html_elements("span.font-11.weight-500") |>
        rvest::html_text() |>
        as.numeric()

      if (length(scores) < 2) {
        next
      }

      teams <- game_link |>
        rvest::html_elements("span.font-10.weight-500.uppercase") |>
        rvest::html_text()

      if (length(teams) < 2) {
        next
      }

      away_team <- teams[1]
      home_team <- teams[2]

      if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
        next
      }

      game_href <- rvest::html_attr(game_link, "href")
      game_id <- if (!is.null(game_href) && game_href != "") {
        id <- stringr::str_extract(game_href, "(?<=/game/)[a-z0-9]+")
        if (is.na(id)) {
          id <- stringr::str_extract(game_href, "[a-z0-9]+(?=/box-score$)")
        }
        id
      } else {
        NA_character_
      }

      game_data[[length(game_data) + 1]] <- tibble::tibble(
        game_id = game_id,
        date = game_date,
        away_team = away_team,
        away_team_score = scores[1],
        home_team = home_team,
        home_team_score = scores[2],
        season = season_year
      )
    }
  } else {
    if (length(games) >= 2) {
      for (i in seq(1, length(games), by = 2)) {
        if (i + 1 > length(games)) {
          break
        }

        away_game <- games[[i]]
        home_game <- games[[i + 1]]

        away_score <- away_game |>
          rvest::html_element("h3.weight-900") |>
          rvest::html_text() |>
          as.numeric()

        home_score <- home_game |>
          rvest::html_element("h3.weight-900") |>
          rvest::html_text() |>
          as.numeric()

        away_team <- away_game |>
          rvest::html_element("a.flex-row.items-center.col-12") |>
          rvest::html_element("div.color-blue.weight-500.font-14") |>
          rvest::html_text()

        home_team <- home_game |>
          rvest::html_element("a.flex-row.items-center.col-12") |>
          rvest::html_element("div.color-blue.weight-500.font-14") |>
          rvest::html_text()

        if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
          next
        }

        box_score_link <- day_node |>
          rvest::html_element("a[href*='/game/']") |>
          rvest::html_attr("href")

        game_id <- if (!is.null(box_score_link)) {
          stringr::str_extract(box_score_link, "[a-z0-9]+(?=/box-score$)")
        } else {
          NA_character_
        }

        game_data[[length(game_data) + 1]] <- tibble::tibble(
          game_id = game_id,
          date = game_date,
          away_team = away_team,
          away_team_score = away_score,
          home_team = home_team,
          home_team_score = home_score,
          season = season_year
        )
      }
    }
  }

  if (length(game_data) == 0) {
    return(NULL)
  }
  dplyr::bind_rows(game_data)
}

#' Parse a game from the main schedule layout (2026 format)
#'
#' Handles the main schedule card layout with div.flex.w-100.radius-8 containers.
#'
#' @param container HTML node containing game data
#' @param date_text The date text for this game day
#' @param season_year The season year
#' @param s_params Season parameters
#' @return tibble of game data or NULL if not a valid final game
parse_main_layout_game <- function(
  container,
  date_text,
  season_year,
  s_params
) {
  valid_teams <- s_params$valid_teams

  # Check for Final indicator (font-14 class)
  final_indicator <- container |>
    rvest::html_element("span.uppercase.weight-500.font-14")

  if (is.null(final_indicator)) {
    return(NULL)
  }

  final_text <- rvest::html_text(final_indicator)
  if (is.na(final_text) || trimws(final_text) != "Final") {
    return(NULL)
  }

  # Extract game ID from box-score link
  box_score_link <- container |>
    rvest::html_element("a[href*='/game/'][href*='/box-score']")

  if (is.null(box_score_link)) {
    return(NULL)
  }

  game_href <- rvest::html_attr(box_score_link, "href")
  game_id <- stringr::str_extract(game_href, "(?<=/game/)[a-z0-9]+")

  if (is.na(game_id)) {
    return(NULL)
  }

  # Extract scores (h3.weight-900 elements)
  scores <- container |>
    rvest::html_elements("h3.weight-900") |>
    rvest::html_text() |>
    as.numeric()

  if (length(scores) < 2) {
    return(NULL)
  }

  # Extract team names (div.color-blue.weight-500.font-14 elements)
  teams <- container |>
    rvest::html_elements("div.color-blue.weight-500.font-14") |>
    rvest::html_text()

  if (length(teams) < 2) {
    return(NULL)
  }

  away_team <- teams[1]
  home_team <- teams[2]

  if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
    return(NULL)
  }

  # Parse date
  game_date <- parse_date_text(date_text, season_year)
  if (is.na(game_date)) {
    return(NULL)
  }

  # Skip games in the specified date range
  if (game_date >= s_params$skip_start && game_date <= s_params$skip_end) {
    return(NULL)
  }

  tibble::tibble(
    game_id = game_id,
    date = game_date,
    away_team = away_team,
    away_team_score = scores[1],
    home_team = home_team,
    home_team_score = scores[2],
    season = season_year
  )
}

#' Parse date text to Date object
#'
#' @param date_text The date text string
#' @param season_year The season year for context
#' @return Date object or NA
parse_date_text <- function(date_text, season_year) {
  today <- as.Date(lubridate::now(tzone = "America/New_York"))

  if (stringr::str_detect(date_text, "^Today")) {
    return(today)
  } else if (stringr::str_detect(date_text, "^Tomorrow")) {
    return(today + 1)
  }

  # Try standard date formats
  d <- as.Date(date_text, format = "%A, %B %d, %Y")
  if (!is.na(d)) return(d)

  d <- as.Date(date_text, format = "%a, %b %d, %Y")
  if (!is.na(d)) return(d)

  # Try "Friday, January 17, 2025" format
  date_parts <- stringr::str_match(
    date_text,
    "([A-Za-z]+),\\s*([A-Za-z]+)\\s+([0-9]+),\\s*([0-9]+)"
  )
  if (!is.na(date_parts[1, 1])) {
    month <- date_parts[1, 3]
    day <- date_parts[1, 4]
    year <- date_parts[1, 5]
    date_str <- paste(month, day, year, sep = " ")
    d <- as.Date(date_str, format = "%B %d %Y")
    if (!is.na(d)) return(d)
  }

  # Try compact format "Jan17Fri" or similar
  date_parts <- stringr::str_match(
    date_text,
    "([A-Za-z]+)\\s*([0-9]+)\\s*([A-Za-z]+)"
  )
  if (!is.na(date_parts[1, 1])) {
    month_abbr <- date_parts[1, 2]
    day_num <- date_parts[1, 3]
    date_str <- paste(month_abbr, day_num, season_year, sep = " ")
    d <- as.Date(date_str, format = "%b %d %Y")
    if (!is.na(d)) return(d)
  }

  NA
}

#' Scrape games from main schedule layout
#'
#' Parses games from the main schedule view which uses div.flex.row-12.p-12
#' day containers with div.flex.w-100.radius-8 game cards.
#'
#' @param html The full HTML document
#' @param season_year The season year
#' @param s_params Season parameters
#' @return tibble of games
scrape_main_layout_games <- function(html, season_year, s_params) {
  # Find day containers (div.flex.row-12.p-12)
  day_containers <- html |>
    rvest::html_elements("div.flex.row-12.p-12")

  all_games <- list()

  for (day_container in day_containers) {
    # Extract date from the day header
    date_element <- day_container |>
      rvest::html_element("span.uppercase.weight-500")

    if (is.null(date_element)) {
      next
    }

    date_text <- rvest::html_text(date_element)
    if (is.na(date_text) || date_text == "") {
      next
    }

    # Find game cards within this day
    game_cards <- day_container |>
      rvest::html_elements("div.flex.w-100.radius-8")

    for (card in game_cards) {
      game_data <- parse_main_layout_game(
        card,
        date_text,
        season_year,
        s_params
      )
      if (!is.null(game_data)) {
        all_games[[length(all_games) + 1]] <- game_data
      }
    }
  }

  if (length(all_games) == 0) {
    return(tibble::tibble(
      game_id = character(),
      date = as.Date(character()),
      away_team = character(),
      away_team_score = numeric(),
      home_team = character(),
      home_team_score = numeric(),
      season = numeric()
    ))
  }

  dplyr::bind_rows(all_games)
}

#' Scrape all games for a season
#'
#' @param season_year The season year (e.g., 2025, 2026)
#' @return tibble of all games for the season
#' @export
scrape_unrivaled_games <- function(season_year = 2025) {
  s_params <- get_season_params(season_year)
  if (is.null(s_params)) {
    stop(glue::glue("Parameters for season {season_year} not found"))
  }

  if (!file.exists(s_params$schedule_file)) {
    warning(glue::glue("Schedule file {s_params$schedule_file} not found"))
    return(NULL)
  }

  html <- rvest::read_html(s_params$schedule_file)

  # For 2026, try main layout first, then compact layout
  if (season_year == 2026) {
    # Try main schedule layout (div.flex.row-12.p-12 with game cards)
    all_games <- scrape_main_layout_games(html, season_year, s_params)

    # If main layout didn't find enough games, try compact layout
    if (nrow(all_games) < 20) {
      game_days <- html |>
        rvest::html_elements("div.flex-row.pl-4")

      compact_games <- purrr::map(
        game_days,
        ~ parse_game_day(.x, season_year, s_params)
      ) |>
        purrr::compact() |>
        dplyr::bind_rows()

      if (nrow(compact_games) > 0) {
        all_games <- dplyr::bind_rows(all_games, compact_games) |>
          dplyr::distinct(game_id, .keep_all = TRUE)
      }
    }

    # Final fallback if still not enough games
    if (nrow(all_games) < 20) {
      tryCatch(
        {
          all_game_links <- html |>
            rvest::html_elements("a[href*='/game/']")

          fallback_games <- scrape_fallback_games(
            all_game_links,
            html,
            all_games,
            season_year,
            s_params
          )

          if (length(fallback_games) > 0) {
            fallback_df <- dplyr::bind_rows(fallback_games)
            all_games <- dplyr::bind_rows(all_games, fallback_df) |>
              dplyr::distinct(game_id, .keep_all = TRUE)
          }
        },
        error = function(e) {
          warning(glue::glue("Fallback method failed: {e$message}"))
        }
      )
    }
  } else {
    # 2025 season uses the original day-based parsing
    game_days <- html |>
      rvest::html_elements("div.flex.row-12.p-12")

    all_games <- purrr::map(
      game_days,
      ~ parse_game_day(.x, season_year, s_params)
    ) |>
      purrr::compact() |>
      dplyr::bind_rows()
  }

  if (nrow(all_games) == 0) {
    all_games <- tibble::tibble(
      game_id = character(),
      date = as.Date(character()),
      away_team = character(),
      away_team_score = numeric(),
      home_team = character(),
      home_team_score = numeric(),
      season = numeric(),
      season_type = character()
    )
    return(all_games)
  }

  all_games <- all_games |>
    dplyr::arrange(.data$date)

  # Add canceled game for 2025
  if (season_year == 2025) {
    canceled_game <- tibble::tibble(
      date = as.Date("2025-02-08"),
      away_team = "Laces",
      away_team_score = 0,
      home_team = "Vinyl",
      home_team_score = 11,
      season = 2025
    )
    all_games <- dplyr::bind_rows(all_games, canceled_game)
  }

  all_games <- all_games |>
    dplyr::arrange(.data$date) |>
    dplyr::mutate(
      season_type = dplyr::case_when(
        .data$date >= s_params$postseason_start ~ "POST",
        TRUE ~ "REG"
      )
    )

  return(all_games)
}

#' Scrape fallback games from all game links
#'
#' Helper function for scraping games that weren't captured by day structure.
#'
#' @param all_game_links List of game link HTML elements
#' @param html The full HTML document
#' @param all_games Existing games tibble
#' @param season_year The season year
#' @param s_params Season parameters
#' @return List of fallback game tibbles
scrape_fallback_games <- function(
  all_game_links,
  html,
  all_games,
  season_year,
  s_params
) {
  valid_teams <- s_params$valid_teams
  fallback_games <- list()

  for (game_link in all_game_links) {
    final_indicator <- game_link |>
      rvest::html_element("span.font-10.uppercase.clamp1.weight-700")

    if (
      is.null(final_indicator) ||
        rvest::html_text(final_indicator) != "Final"
    ) {
      next
    }

    game_href <- rvest::html_attr(game_link, "href")
    game_id <- stringr::str_extract(game_href, "(?<=/game/)[a-z0-9]+")
    if (is.na(game_id)) {
      next
    }

    if (nrow(all_games) > 0 && game_id %in% all_games$game_id) {
      next
    }

    scores <- game_link |>
      rvest::html_elements("span.font-11.weight-500") |>
      rvest::html_text() |>
      as.numeric()

    if (length(scores) < 2) {
      next
    }

    teams <- game_link |>
      rvest::html_elements("span.font-10.weight-500.uppercase") |>
      rvest::html_text()

    if (length(teams) < 2) {
      next
    }

    away_team <- teams[1]
    home_team <- teams[2]

    if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
      next
    }

    game_date <- find_game_date(game_id, html, season_year)

    if (is.na(game_date)) {
      warning(glue::glue("Skipping game {game_id} - could not determine date"))
      next
    }

    fallback_games[[length(fallback_games) + 1]] <- tibble::tibble(
      game_id = game_id,
      date = game_date,
      away_team = away_team,
      away_team_score = scores[1],
      home_team = home_team,
      home_team_score = scores[2],
      season = season_year
    )
  }

  fallback_games
}

#' Find game date from HTML structure
#'
#' @param game_id The game ID to find
#' @param html The full HTML document
#' @param season_year The season year
#' @return Date object or NA
find_game_date <- function(game_id, html, season_year) {
  day_nodes <- html |>
    rvest::html_elements("div.flex-row.pl-4")

  for (day_node in day_nodes) {
    games_in_day <- rvest::html_elements(day_node, "a[href*='/game/']")
    day_game_ids <- purrr::map_chr(
      games_in_day,
      ~ {
        href <- rvest::html_attr(.x, "href")
        if (is.na(href) || is.null(href)) {
          return(NA_character_)
        }
        id <- stringr::str_extract(href, "(?<=/game/)[a-z0-9]+")
        if (is.na(id)) {
          return(NA_character_)
        }
        id
      }
    )
    day_game_ids <- day_game_ids[!is.na(day_game_ids)]

    if (game_id %in% day_game_ids) {
      date_div <- rvest::html_element(
        day_node,
        "div.flex.justify-center.items-center.h-100.row-4.weight-500"
      )
      if (!is.null(date_div)) {
        date_text <- rvest::html_text(date_div)
        date_text <- stringr::str_replace(
          date_text,
          "([A-Za-z]+)([0-9]+)([A-Za-z]+)",
          "\\1 \\2 \\3"
        )
        date_parts <- stringr::str_match(
          date_text,
          "([A-Za-z]+)\\s*([0-9]+)\\s*([A-Za-z]+)"
        )
        if (!is.na(date_parts[1, 1])) {
          month_abbr <- date_parts[1, 2]
          day_num <- date_parts[1, 3]
          date_str <- paste(month_abbr, day_num, season_year, sep = " ")
          return(as.Date(date_str, format = "%b %d %Y"))
        }
      }
    }
  }

  NA
}
