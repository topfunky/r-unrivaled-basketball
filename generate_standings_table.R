# Purpose: Creates a markdown table of final regular season standings including
# team name, record, point differential, and ELO score.

# Load required libraries
library(tidyverse)
library(feather)
library(knitr)

# Process each season separately
seasons <- c(2025, 2026)

for (season_year in seasons) {
  message(sprintf("Processing season %d...", season_year))

  # Read the data files from season-specific directory
  data_dir <- file.path("data", season_year)
  standings_file <- file.path(
    data_dir,
    "unrivaled_regular_season_standings.feather"
  )
  elo_file <- file.path(data_dir, "unrivaled_final_elo_ratings.feather")

  # Skip if required files don't exist
  if (!file.exists(standings_file)) {
    message(sprintf(
      "Standings file not found for season %d: %s\nSkipping season %d...",
      season_year,
      standings_file,
      season_year
    ))
    next
  }
  if (!file.exists(elo_file)) {
    message(sprintf(
      "ELO ratings file not found for season %d: %s\nSkipping season %d...",
      season_year,
      elo_file,
      season_year
    ))
    next
  }

  rankings <- read_feather(standings_file)
  elo_rankings <- read_feather(elo_file)

  # Combine the data and format for display
  final_stats <- rankings |>
    left_join(elo_rankings, by = "team") |>
    mutate(
      record = paste0(wins, "-", losses),
      elo_rating = round(elo_rating)
    ) |>
    select(team, record, point_differential, elo_rating) |>
    arrange(desc(elo_rating))

  # Print in markdown format
  cat(sprintf("\n## Season %d Final Standings\n\n", season_year))
  final_stats |>
    select(
      Team = team,
      Record = record,
      `Point Differential` = point_differential,
      `ELO Rating` = elo_rating
    ) |>
    kable(format = "markdown") |>
    print()

  # Save the data
  write_feather(
    final_stats,
    file.path(data_dir, "unrivaled_final_stats.feather")
  )

  message(sprintf("✅ Completed processing season %d", season_year))
}
