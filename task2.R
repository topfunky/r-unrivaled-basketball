# Load required libraries
library(tidyverse)
library(rvest)
library(lubridate)
library(glue)

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

  # Find all games in this day with correct selector
  games <- day_node |>
    html_elements("div.flex-row.w-100.items-center.col-12")

  print(paste("Found", length(games), "team scores for this day"))

  # Process each game with error handling
  game_data <- map(games, function(game) {
    # Debug: Print game text
    print("Processing game:")
    print(html_text(game))

    # Extract scores with error handling
    scores <- game |>
      html_elements("h3.weight-900") |>
      html_text() |>
      as.numeric()

    print(glue("scores: {scores[1]}"))

    # Extract team names with error handling
    team_links <- game |>
      html_elements("a.flex-row.items-center.col-12")

    teams <- team_links |>
      html_element("div.color-blue.weight-500.font-14") |>
      html_text()

    print(glue("teams: {teams[1]}"))

    # Create a row of game data
    tibble(
      date = game_date,
      away_team = teams[1],
      away_team_score = scores[1],
      home_team = teams[2],
      home_team_score = scores[2]
    )
  }) |>
    # Remove any NULL results from failed parsing
    compact() |>
    bind_rows()

  # Print tibble
  print(game_data)

  return(game_data)
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
    mutate(week_number = row_number()) |>
    ungroup() |>
    # Ensure week numbers are sequential
    mutate(week_number = dense_rank(week_number))

  return(all_games)
}

# Scrape the games
games <- scrape_unrivaled_games()

# Save to CSV
write_csv(games, "fixtures/unrivaled_scores.csv")

