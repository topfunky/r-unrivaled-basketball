# Purpose: Downloads all box scores for each game from the Unrivaled Basketball League website.
# Only downloads games that are marked as "Final" in the schedule to avoid caching
# future games. Re-downloads cached files that contain "Game Not Found" content.

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(httr)

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
season_year <- if (length(args) > 0) args[1] else "2026"

# Create games directory if it doesn't exist
games_base_dir <- path("games", season_year)
if (!dir_exists(games_base_dir)) {
  dir_create(games_base_dir)
}

# Read the schedule HTML file
schedule_file <- path("fixtures", season_year, "schedule.html")
if (!file_exists(schedule_file)) {
  stop(sprintf("Schedule file %s not found", schedule_file))
}
schedule_html <- read_html(schedule_file)

# Base URL for the website
base_url <- "https://www.unrivaled.basketball"

# Function to parse schedule and extract final games with IDs
extract_final_games <- function(schedule_html) {
  # Find all game links
  game_links <- schedule_html |>
    html_elements("a[href*='/game/']")

  final_game_ids <- character()

  for (game_link in game_links) {
    # Check if game is final (has "Final" status indicator)
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

    # Extract game ID from href
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

    if (!is.na(game_id) && game_id != "") {
      final_game_ids <- c(final_game_ids, game_id)
    }
  }

  # Return unique game IDs
  unique(final_game_ids)
}

# Function to check if cached HTML file is empty/not-found
is_game_file_empty <- function(filepath) {
  if (!file_exists(filepath)) {
    return(TRUE)
  }

  tryCatch(
    {
      # Read and parse the HTML file
      html <- read_html(filepath)
      title_element <- html_element(html, "title")
      if (is.null(title_element)) {
        return(TRUE)
      }
      title_text <- html_text(title_element)
      # Check if title contains "Game Not Found"
      if (is.na(title_text) || str_detect(title_text, "Game Not Found")) {
        return(TRUE)
      }
      return(FALSE)
    },
    error = function(e) {
      # If we can't parse the file, treat it as empty
      return(TRUE)
    }
  )
}

# Function to download a file if it doesn't exist or is empty
download_if_missing <- function(url, filepath) {
  # Check if file exists and is not empty
  if (file_exists(filepath) && !is_game_file_empty(filepath)) {
    message(sprintf("File already exists and is valid: %s", filepath))
    return(invisible(NULL))
  }

  # File is missing or empty, download it
  if (file_exists(filepath) && is_game_file_empty(filepath)) {
    message(sprintf("File is empty (Game Not Found), re-downloading %s...", url))
  } else {
    message(sprintf("Downloading %s...", url))
  }

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
}

# Extract only games marked as "Final" from the schedule
final_game_ids <- extract_final_games(schedule_html)

message(sprintf(
  "Found %d final games in schedule (out of all game links)",
  length(final_game_ids)
))

if (length(final_game_ids) == 0) {
  message("No final games found in schedule. Nothing to download.")
} else {
  # Download files for each final game
  for (game_id in final_game_ids) {
    # Create game-specific directory
    game_dir <- path(games_base_dir, game_id)
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
}
