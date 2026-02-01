# Purpose: Downloads all box scores for each game from the Unrivaled Basketball
# League website. Only downloads games that are marked as "Final" in the
# schedule to avoid caching future games. Re-downloads cached files that contain
# "Game Not Found" content. Implements caching policy:
# - Always fetch schedule fresh
# - Skip download for completed games with valid cached content
# - Re-download games with "Game Not Found" content

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(httr)

# Source utility functions
source("R/download_game_data_utils.R")

# Constants
BASE_URL <- "https://www.unrivaled.basketball"
SCHEDULE_URL <- "https://www.unrivaled.basketball/schedule?games=All"
POLITE_DELAY_SECONDS <- 1

#' Download a file from URL to filepath
#'
#' @param url The URL to download from
#' @param filepath The local path to save to
#' @return TRUE if download succeeded, FALSE otherwise
download_file <- function(url, filepath) {
  message(sprintf("Downloading %s...", url))
  response <- GET(url)
  if (status_code(response) == 200) {
    writeBin(content(response, "raw"), filepath)
    message(sprintf("Saved to %s", filepath))
    return(TRUE)
  } else {
    warning(sprintf(
      "Failed to download %s: status code %d",
      url,
      status_code(response)
    ))
    return(FALSE)
  }
}

#' Download game files (summary, box-score, play-by-play) for a game
#'
#' @param game_id The game ID
#' @param game_dir The directory to save files to
download_game_files <- function(game_id, game_dir) {
  # Download summary
  summary_url <- sprintf("%s/game/%s", BASE_URL, game_id)
  summary_file <- path(game_dir, "summary.html")
  download_file(summary_url, summary_file)

  # Download box score
  box_score_url <- sprintf("%s/game/%s/box-score", BASE_URL, game_id)
  box_score_file <- path(game_dir, "box-score.html")
  download_file(box_score_url, box_score_file)

  # Download play by play
  play_by_play_url <- sprintf("%s/game/%s/play-by-play", BASE_URL, game_id)
  play_by_play_file <- path(game_dir, "play-by-play.html")
  download_file(play_by_play_url, play_by_play_file)
}

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
season_year <- if (length(args) > 0) args[1] else "2026"

# Create directories if they don't exist
games_base_dir <- path("games", season_year)
data_dir <- path("data", season_year)
if (!dir_exists(games_base_dir)) {
  dir_create(games_base_dir)
}
if (!dir_exists(data_dir)) {
  dir_create(data_dir)
}

# Always fetch schedule fresh
schedule_file <- path(data_dir, "schedule.html")
message(sprintf("Fetching fresh schedule from %s...", SCHEDULE_URL))
schedule_response <- GET(SCHEDULE_URL)
if (status_code(schedule_response) == 200) {
  writeBin(content(schedule_response, "raw"), schedule_file)
  message(sprintf("Schedule saved to %s", schedule_file))
} else {
  stop(sprintf(
    "Failed to fetch schedule: status code %d",
    status_code(schedule_response)
  ))
}

# Read the schedule HTML
schedule_html <- read_html(schedule_file)

# Extract only games marked as "Final" from the schedule
final_game_ids <- extract_final_games(schedule_html)

message(sprintf(
  "Found %d final games in schedule",
  length(final_game_ids)
))

if (length(final_game_ids) == 0) {
  message("No final games found in schedule. Nothing to download.")
} else {
  downloaded_count <- 0
  skipped_count <- 0

  # Download files for each final game
  for (game_id in final_game_ids) {
    # Create game-specific directory
    game_dir <- path(games_base_dir, game_id)
    if (!dir_exists(game_dir)) {
      dir_create(game_dir)
    }

    # Check if we should download this game (caching policy)
    if (should_download_game(game_id, game_dir, is_game_final = TRUE)) {
      download_game_files(game_id, game_dir)
      downloaded_count <- downloaded_count + 1

      # Polite delay between requests
      Sys.sleep(POLITE_DELAY_SECONDS)
    } else {
      message(sprintf("Skipping %s (valid cache exists)", game_id))
      skipped_count <- skipped_count + 1
    }
  }

  message(sprintf(
    "Download complete: %d downloaded, %d skipped (cached)",
    downloaded_count,
    skipped_count
  ))
}
