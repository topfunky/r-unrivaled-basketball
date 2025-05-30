# Purpose: Scrapes live game data from Unrivaled website HTML file (local copy),
# processes game results, and saves to CSV. Includes team name validation and
# skips games during mid-season 1v1 tournament (Feb 10-15, 2025). Adds canceled
# game from Feb 8, 2025 (Laces at Vinyl) as it counts in standings.
# Outputs to fixtures/unrivaled_scores.csv.

# Load required libraries
library(tidyverse)
library(rvest)
library(lubridate)
library(glue)

# Define valid team names
VALID_TEAMS <- c("Lunar Owls", "Mist", "Rose", "Laces", "Phantom", "Vinyl")

# Define date range to skip (mid-season 1v1 games)
SKIP_START <- as.Date("2025-02-10")
SKIP_END <- as.Date("2025-02-15")

# Define postseason start date
POSTSEASON_START <- as.Date("2025-03-16")

# Function to parse a single game day
parse_game_day <- function(day_node) {
  # Debug: Print the day node text
  print("Processing day node:")
  print(html_text(day_node))

  # Extract date from the day header with error handling
  date_element <- day_node |>
    html_element("span.uppercase.weight-500")

  if (is.null(date_element)) {
    warning("Could not find date element in day node")
    return(NULL)
  }

  date_text <- html_text(date_element)
  print(paste("Found date:", date_text))

  # Convert date text to Date object with correct format
  game_date <- as.Date(date_text, format = "%A, %B %d, %Y")
  # Print game_date
  print(game_date)

  # Skip games in the specified date range
  if (game_date >= SKIP_START && game_date <= SKIP_END) {
    warning(glue("Skipping games on {game_date} (within skip date range)"))
    return(NULL)
  }

  # Find all games in this day with correct selector
  games <- day_node |>
    html_elements("div.flex-row.w-100.items-center.col-12")

  print(paste("Found", length(games), "team scores for this day"))

  # Process games in pairs (away team then home team)
  game_data <- list()
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
    if (!away_team %in% VALID_TEAMS || !home_team %in% VALID_TEAMS) {
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
      home_team_score = home_score
    )
  }

  # Combine all games for this day
  day_data <- bind_rows(game_data)
  print(day_data)
  return(day_data)
}

# Function to scrape all games
scrape_unrivaled_games <- function() {
  # Read the HTML file
  html <- read_html("fixtures/schedule.html")

  # Debug: Print the overall HTML text
  print("Overall HTML content:")
  print(html_text(html))

  # Find all game days
  game_days <- html |>
    html_elements("div.flex.row-12.p-12")

  print(paste("Found", length(game_days), "game days"))

  # Process each day and combine results
  all_games <- map(game_days, parse_game_day) |>
    # Remove any NULL results from failed parsing
    compact() |>
    bind_rows() |>
    # Add week number based on date
    arrange(date) |>
    group_by(date) |>
    ungroup()

  return(all_games)
}

# Scrape the games
games <- scrape_unrivaled_games()

# Add the canceled game that counts against team records
canceled_game <- tibble(
  date = as.Date("2025-02-08"),
  away_team = "Laces",
  away_team_score = 0,
  home_team = "Vinyl",
  home_team_score = 11
)

# Combine scraped games with canceled game and sort by date
games <- bind_rows(games, canceled_game) |>
  arrange(date) |>
  # Add season type (REG or POST) based on date
  mutate(
    season_type = case_when(
      date >= POSTSEASON_START ~ "POST",
      TRUE ~ "REG"
    )
  )

# Save to CSV
write_csv(games, "fixtures/unrivaled_scores.csv")
