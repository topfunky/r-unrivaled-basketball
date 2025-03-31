# Purpose: Downloads all box scores for each game from the Unrivaled Basketball League website.

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(httr)

# Create games directory if it doesn't exist
if (!dir_exists("games")) {
  dir_create("games")
}

# Read the schedule HTML file
schedule_html <- read_html("fixtures/schedule.html")

# Get all game links
game_links <- schedule_html |>
  html_nodes("a") |>
  html_attr("href") |>
  str_subset("^/game/") |>
  str_extract("^/game/([^/]+)", group = 1) |>
  unique()

# Base URL for the website
base_url <- "https://www.unrivaled.basketball"

# Function to download a file if it doesn't exist
download_if_missing <- function(url, filepath) {
  if (!file_exists(filepath)) {
    message(sprintf("Downloading %s...", url))
    response <- GET(url)
    if (status_code(response) == 200) {
      writeBin(content(response, "raw"), filepath)
      message(sprintf("Saved to %s", filepath))
    } else {
      warning(sprintf(
        "Failed to download %s: status code %d",
        url,
        status_code(response)
      ))
    }
  } else {
    message(sprintf("File already exists: %s", filepath))
  }
}

# Download files for each game
for (game_id in game_links) {
  # Create game-specific directory
  game_dir <- path("games", game_id)
  if (!dir_exists(game_dir)) {
    dir_create(game_dir)
  }

  # Download summary
  summary_url <- sprintf("%s/game/%s", base_url, game_id)
  summary_file <- path(game_dir, "summary.html")
  download_if_missing(summary_url, summary_file)

  # Download box score
  box_score_url <- sprintf("%s/game/%s/box-score", base_url, game_id)
  box_score_file <- path(game_dir, "box-score.html")
  download_if_missing(box_score_url, box_score_file)

  # Download play by play
  play_by_play_url <- sprintf("%s/game/%s/play-by-play", base_url, game_id)
  play_by_play_file <- path(game_dir, "play-by-play.html")
  download_if_missing(play_by_play_url, play_by_play_file)

  # Add a small delay to be nice to the server
  Sys.sleep(1)
}

message("All game files downloaded successfully!")
