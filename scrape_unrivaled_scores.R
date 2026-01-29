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

# Source utility functions
source("R/scrape_utils.R")
source("R/extract_game_ids.R")

# Only run execution code if script is run directly (not sourced)
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
