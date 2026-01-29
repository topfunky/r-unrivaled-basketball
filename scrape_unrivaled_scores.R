# Purpose: Scrapes live game data from Unrivaled website HTML file (local copy),
# processes game results, and saves to CSV. Includes team name validation and
# skips games during mid-season 1v1 tournament (Feb 10-15, 2025). Adds canceled
# game from Feb 8, 2025 (Laces at Vinyl) as it counts in standings.
# Outputs to data/unrivaled_scores.csv.

# Load required libraries
library(tidyverse)
library(rvest)
library(lubridate)
library(glue)

# Function to extract game IDs from schedule HTML file
extract_game_ids <- function(schedule_file, season_year = 2026) {
  # Check that file exists
  if (!file.exists(schedule_file)) {
    stop(glue("Schedule file {schedule_file} not found"))
  }

  # Read the HTML file
  html <- read_html(schedule_file)

  # Find all game links
  game_links <- html |>
    html_elements("a[href*='/game/']")

  # Extract game IDs from href attributes
  game_ids <- map_chr(
    game_links,
    ~ {
      href <- html_attr(.x, "href")
      if (is.na(href) || is.null(href)) {
        return(NA_character_)
      }
      # Extract ID from /game/{id} pattern
      id <- str_extract(href, "(?<=/game/)[a-z0-9]+")
      if (is.na(id)) {
        return(NA_character_)
      }
      id
    }
  )

  # Remove NA values and return unique IDs
  game_ids <- game_ids[!is.na(game_ids)]
  unique(game_ids)
}

# Function to scrape all games
scrape_unrivaled_games <- function(season_year = 2025) {
  # Season-specific parameters
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

  s_params <- params[[as.character(season_year)]]
  if (is.null(s_params)) {
    stop(glue("Parameters for season {season_year} not found"))
  }

  valid_teams <- s_params$valid_teams

  # Function to parse a single game day
  parse_game_day <- function(day_node) {
    # Debug: Print the day node text
    print("Processing day node:")
    print(html_text(day_node))

    # Extract date from the day header with error handling
    # Use different selectors based on season format
    if (season_year == 2026) {
      # 2026 format: use div with date
      date_div <- day_node |>
        html_element(
          "div.flex.justify-center.items-center.h-100.row-4.weight-500"
        )
      if (is.null(date_div)) {
        warning("Could not find date element in day node (2026 format)")
        return(NULL)
      }
      date_text <- html_text(date_div)
      # Parse 2026 format: "Jan19Mon" -> "Jan 19 Mon"
      # Extract month abbreviation, day number, and day name using str_replace
      date_text <- str_replace(
        date_text,
        "([A-Za-z]+)([0-9]+)([A-Za-z]+)",
        "\\1 \\2 \\3"
      )
    } else {
      # 2025 format: use span
      date_element <- day_node |>
        html_element("span.uppercase.weight-500")
      if (is.null(date_element)) {
        warning("Could not find date element in day node (2025 format)")
        return(NULL)
      }
      date_text <- html_text(date_element)
    }

    # Check if date_text is valid
    if (is.na(date_text) || date_text == "" || is.null(date_text)) {
      warning("Date text is empty or NA")
      return(NULL)
    }

    print(paste("Found date text:", date_text))

    # Convert date text to Date object
    # Use US East timezone since that's where games are played
    today <- as.Date(now(tzone = "America/New_York"))
    game_date <- if (str_detect(date_text, "^Today")) {
      today
    } else if (str_detect(date_text, "^Tomorrow")) {
      today + 1
    } else {
      # Try multiple formats
      # 2025 format: "Friday, January 17, 2025" or "Fri, Jan 17, 2025"
      d <- as.Date(date_text, format = "%A, %B %d, %Y")
      if (is.na(d)) {
        d <- as.Date(date_text, format = "%a, %b %d, %Y")
      }
      # 2026 format: "Jan 19 Mon" (need to add year)
      if (is.na(d)) {
        # Try parsing "Jan 19 Mon" or "Jan19Mon" format
        date_parts <- str_match(
          date_text,
          "([A-Za-z]+)\\s*([0-9]+)\\s*([A-Za-z]+)"
        )
        if (!is.na(date_parts[1, 1])) {
          month_abbr <- date_parts[1, 2]
          day_num <- date_parts[1, 3]
          # Construct date string with year
          date_str <- paste(month_abbr, day_num, season_year, sep = " ")
          d <- as.Date(date_str, format = "%b %d %Y")
        }
      }
      d
    }

    # Print game_date
    print(paste("Parsed game date:", game_date))

    # If date is still NA, skip this node
    if (is.na(game_date)) {
      warning(glue("Could not parse date from text: {date_text}"))
      return(NULL)
    }

    # Skip games in the specified date range
    if (game_date >= s_params$skip_start && game_date <= s_params$skip_end) {
      warning(glue("Skipping games on {game_date} (within skip date range)"))
      return(NULL)
    }

    # Don't skip based on date - we'll check if the game is final instead
    # This allows us to include games from today that have already completed

    # Find all games in this day - try 2025 format first
    games_2025 <- day_node |>
      html_elements("div.flex-row.w-100.items-center.col-12")

    # Try 2026 format (game links)
    games_2026 <- day_node |>
      html_elements("a[href*='/game/']")

    # Determine which format we're using
    if (length(games_2025) >= 2) {
      # 2025 format: process games in pairs
      print(paste(
        "Found",
        length(games_2025),
        "team scores for this day (2025 format)"
      ))
      games <- games_2025
      format_2026 <- FALSE
    } else if (length(games_2026) > 0) {
      # 2026 format: each link is a game
      print(paste(
        "Found",
        length(games_2026),
        "games for this day (2026 format)"
      ))
      games <- games_2026
      format_2026 <- TRUE
    } else {
      print("No games found for this day")
      return(NULL)
    }

    # Process games
    game_data <- list()
    if (format_2026) {
      # 2026 format: each game link contains both teams
      for (game_link in games) {
        # Check if game is final (has scores)
        final_indicator <- game_link |>
          html_element("span.font-10.uppercase.clamp1.weight-700")

        if (is.null(final_indicator)) {
          next
        }

        final_text <- html_text(final_indicator)
        if (is.na(final_text) || trimws(final_text) != "Final") {
          # Skip games that aren't final
          next
        }

        # Extract scores
        scores <- game_link |>
          html_elements("span.font-11.weight-500") |>
          html_text() |>
          as.numeric()

        if (length(scores) < 2) {
          warning("Could not find both scores for game")
          next
        }

        away_score <- scores[1]
        home_score <- scores[2]

        # Extract team names
        teams <- game_link |>
          html_elements("span.font-10.weight-500.uppercase") |>
          html_text()

        if (length(teams) < 2) {
          warning("Could not find both teams for game")
          next
        }

        away_team <- teams[1]
        home_team <- teams[2]

        # Validate team names
        if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
          warning(glue(
            "Skipping game with invalid team names: {away_team} at {home_team}"
          ))
          next
        }

        # Extract game ID from link
        game_href <- html_attr(game_link, "href")
        game_id <- if (!is.null(game_href) && game_href != "") {
          # Extract ID from /game/{id} or /game/{id}/box-score
          id <- str_extract(game_href, "(?<=/game/)[a-z0-9]+")
          if (is.na(id)) {
            id <- str_extract(game_href, "[a-z0-9]+(?=/box-score$)")
          }
          id
        } else {
          NA_character_
        }

        print(glue(
          "Game: id:{game_id} {away_team} ({away_score}) at {home_team} ({home_score})"
        ))

        # Create a row of game data
        game_data[[length(game_data) + 1]] <- tibble(
          game_id = game_id,
          date = game_date,
          away_team = away_team,
          away_team_score = away_score,
          home_team = home_team,
          home_team_score = home_score,
          season = season_year
        )
      }
    } else {
      # 2025 format: process games in pairs (away team then home team)
      if (length(games) >= 2) {
        for (i in seq(1, length(games), by = 2)) {
          if (i + 1 > length(games)) {
            warning("Odd number of teams found, skipping last team")
            break
          }

          away_game <- games[[i]]
          home_game <- games[[i + 1]]

          # Extract scores
          away_score <- away_game |>
            html_element("h3.weight-900") |>
            html_text() |>
            as.numeric()

          home_score <- home_game |>
            html_element("h3.weight-900") |>
            html_text() |>
            as.numeric()

          # Extract team names
          away_team <- away_game |>
            html_element("a.flex-row.items-center.col-12") |>
            html_element("div.color-blue.weight-500.font-14") |>
            html_text()

          home_team <- home_game |>
            html_element("a.flex-row.items-center.col-12") |>
            html_element("div.color-blue.weight-500.font-14") |>
            html_text()

          # Validate team names
          if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
            warning(glue(
              "Skipping game with invalid team names: {away_team} at {home_team}"
            ))
            next
          }

          # Extract game ID from box score link
          box_score_link <- day_node |>
            html_element("a[href*='/game/']") |>
            html_attr("href")

          print(glue("Box score link: {box_score_link}"))

          game_id <- if (!is.null(box_score_link)) {
            id <- str_extract(box_score_link, "[a-z0-9]+(?=/box-score$)")
            print(glue("Extracted game ID: {id}"))
            id
          } else {
            print("No box score link found")
            NA_character_
          }

          print(glue(
            "Game: id:{game_id} {away_team} ({away_score}) at {home_team} ({home_score})"
          ))

          # Create a row of game data
          game_data[[length(game_data) + 1]] <- tibble(
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

    # Combine all games for this day
    if (length(game_data) == 0) {
      # No games found for this day, return NULL
      return(NULL)
    }
    day_data <- bind_rows(game_data)
    print(day_data)
    return(day_data)
  }

  # Read the HTML file
  if (!file.exists(s_params$schedule_file)) {
    warning(glue("Schedule file {s_params$schedule_file} not found"))
    return(NULL)
  }
  html <- read_html(s_params$schedule_file)

  # Debug: Print the overall HTML text
  # print("Overall HTML content:")
  # print(html_text(html))

  # Find all game days - use season-specific selector
  if (season_year == 2026) {
    game_days <- html |>
      html_elements("div.flex-row.pl-4")
  } else {
    game_days <- html |>
      html_elements("div.flex.row-12.p-12")
  }

  print(paste("Found", length(game_days), "game days"))

  # Process each day and combine results
  all_games <- map(game_days, parse_game_day) |>
    # Remove any NULL results from failed parsing
    compact() |>
    bind_rows()

  # Fallback for 2026: also extract all final games directly from the schedule
  # This catches games that might not be in the day structure
  if (season_year == 2026 && (nrow(all_games) == 0 || nrow(all_games) < 20)) {
    print("Using fallback method to find all final games...")
    tryCatch(
      {
        all_game_links <- html |>
          html_elements("a[href*='/game/']")

        fallback_games <- list()
        for (game_link in all_game_links) {
          # Check if game is final
          final_indicator <- game_link |>
            html_element("span.font-10.uppercase.clamp1.weight-700")

          if (
            is.null(final_indicator) || html_text(final_indicator) != "Final"
          ) {
            next
          }

          # Extract game ID
          game_href <- html_attr(game_link, "href")
          game_id <- str_extract(game_href, "(?<=/game/)[a-z0-9]+")
          if (is.na(game_id)) {
            next
          }

          # Skip if we already have this game
          if (nrow(all_games) > 0 && game_id %in% all_games$game_id) {
            next
          }

          # Extract scores
          scores <- game_link |>
            html_elements("span.font-11.weight-500") |>
            html_text() |>
            as.numeric()

          if (length(scores) < 2) {
            next
          }

          # Extract teams
          teams <- game_link |>
            html_elements("span.font-10.weight-500.uppercase") |>
            html_text()

          if (length(teams) < 2) {
            next
          }

          away_team <- teams[1]
          home_team <- teams[2]

          # Validate team names
          if (!away_team %in% valid_teams || !home_team %in% valid_teams) {
            next
          }

          # Find date by checking which day node contains this game
          game_date <- NA
          day_nodes <- html |>
            html_elements("div.flex-row.pl-4")

          for (day_node in day_nodes) {
            games_in_day <- html_elements(day_node, "a[href*='/game/']")
            day_game_ids <- map_chr(
              games_in_day,
              ~ {
                href <- html_attr(.x, "href")
                if (is.na(href) || is.null(href)) {
                  return(NA_character_)
                }
                id <- str_extract(href, "(?<=/game/)[a-z0-9]+")
                if (is.na(id)) {
                  return(NA_character_)
                }
                id
              }
            )
            day_game_ids <- day_game_ids[!is.na(day_game_ids)]
            if (game_id %in% day_game_ids) {
              date_div <- html_element(
                day_node,
                "div.flex.justify-center.items-center.h-100.row-4.weight-500"
              )
              if (!is.null(date_div)) {
                date_text <- html_text(date_div)
                date_text <- str_replace(
                  date_text,
                  "([A-Za-z]+)([0-9]+)([A-Za-z]+)",
                  "\\1 \\2 \\3"
                )
                date_parts <- str_match(
                  date_text,
                  "([A-Za-z]+)\\s*([0-9]+)\\s*([A-Za-z]+)"
                )
                if (!is.na(date_parts[1, 1])) {
                  month_abbr <- date_parts[1, 2]
                  day_num <- date_parts[1, 3]
                  date_str <- paste(month_abbr, day_num, season_year, sep = " ")
                  game_date <- as.Date(date_str, format = "%b %d %Y")
                  break
                }
              }
            }
          }

          # If date still not found, skip this game
          if (is.na(game_date)) {
            warning(glue("Skipping game {game_id} - could not determine date"))
            next
          }

          fallback_games[[length(fallback_games) + 1]] <- tibble(
            game_id = game_id,
            date = game_date,
            away_team = away_team,
            away_team_score = scores[1],
            home_team = home_team,
            home_team_score = scores[2],
            season = season_year
          )
        }

        if (length(fallback_games) > 0) {
          fallback_df <- bind_rows(fallback_games)
          all_games <- bind_rows(all_games, fallback_df) |>
            distinct(game_id, .keep_all = TRUE)
          print(paste("Added", nrow(fallback_df), "games from fallback method"))
        }
      },
      error = function(e) {
        warning(glue("Fallback method failed: {e$message}"))
      }
    )
  }

  # If no games found, return empty tibble with correct structure
  if (nrow(all_games) == 0) {
    all_games <- tibble(
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

  # Add week number based on date
  all_games <- all_games |>
    arrange(.data$date)

  # Add the canceled game that counts against team records (2025 only)
  if (season_year == 2025) {
    canceled_game <- tibble(
      date = as.Date("2025-02-08"),
      away_team = "Laces",
      away_team_score = 0,
      home_team = "Vinyl",
      home_team_score = 11,
      season = 2025
    )
    all_games <- bind_rows(all_games, canceled_game)
  }

  # Final processing
  all_games <- all_games |>
    arrange(.data$date) |>
    # Add season type (REG or POST) based on date
    mutate(
      season_type = case_when(
        .data$date >= s_params$postseason_start ~ "POST",
        TRUE ~ "REG"
      )
    )

  return(all_games)
}

# Only run execution code if script is run directly (not sourced)
# Check command line arguments to see if script is being run via Rscript
cmd_args <- commandArgs(trailingOnly = FALSE)
is_script_run <- any(grepl("scrape_unrivaled_scores\\.R", cmd_args))
if (is_script_run) {
  # Scrape the games for all available seasons
  seasons <- c(2025, 2026)
  all_season_games <- map_dfr(seasons, scrape_unrivaled_games)

  # Save season-specific files to data/{year}/unrivaled_scores.csv
  for (season_year in seasons) {
    season_games <- all_season_games |>
      filter(season == season_year)

    # Create directory if it doesn't exist
    season_dir <- paste0("data/", season_year)
    if (!dir.exists(season_dir)) {
      dir.create(season_dir, recursive = TRUE)
    }

    # Write season-specific file
    write_csv(season_games, paste0(season_dir, "/unrivaled_scores.csv"))
    print(paste0(
      "✅ Saved ",
      nrow(season_games),
      " games for season ",
      season_year,
      " to ",
      season_dir,
      "/unrivaled_scores.csv"
    ))
  }

  # Also save combined file for backward compatibility
  write_csv(all_season_games, "data/unrivaled_scores.csv")
}
