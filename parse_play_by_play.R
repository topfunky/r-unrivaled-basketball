# Purpose: Parses play by play data from downloaded game files.
# Outputs to data/{year}/ directories.

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(feather)

# Source utility functions
source("R/parse_utils.R")

# Process all seasons
seasons <- c(2025, 2026)
all_data <- map(seasons, process_season) |> compact()

# Create data subdirectories if they don't exist
for (season_year in seasons) {
  data_dir <- path("data", season_year)
  if (!dir_exists(data_dir)) {
    dir_create(data_dir)
  }
}

# Process and save each season separately
for (i in seq_along(all_data)) {
  season_year <- seasons[i]
  season_data <- all_data[[i]]

  data_dir <- path("data", season_year)

  write_feather(
    season_data$play_by_play,
    path(data_dir, "unrivaled_play_by_play.feather")
  )
  write_feather(
    season_data$box_score,
    path(data_dir, "unrivaled_box_scores.feather")
  )
  write_feather(
    season_data$summary,
    path(data_dir, "unrivaled_summaries.feather")
  )

  # Also save CSV versions in the same directory
  write_csv(
    season_data$play_by_play,
    path(data_dir, "unrivaled_play_by_play.csv")
  )
  write_csv(
    season_data$box_score,
    path(data_dir, "unrivaled_box_scores.csv")
  )
  write_csv(
    season_data$summary,
    path(data_dir, "unrivaled_summaries.csv")
  )
}

# Combine all seasons for global files (legacy support)
play_by_play_data <- map_dfr(all_data, ~ .x$play_by_play)
box_score_data <- map_dfr(all_data, ~ .x$box_score)
summary_data <- map_dfr(all_data, ~ .x$summary)

# Save the combined parsed data to root data directory (legacy support)
write_feather(play_by_play_data, "data/unrivaled_play_by_play.feather")
write_feather(box_score_data, "data/unrivaled_box_scores.feather")
write_feather(summary_data, "data/unrivaled_summaries.feather")

message("All game data parsed and saved successfully!")

# Display samples of each dataset
message("\nSample of play by play data:")
print(
  play_by_play_data |>
    filter(game_id == first(game_id)) |>
    slice_head(n = 5)
)

message("\nSample of box score data:")
print(
  box_score_data |>
    filter(game_id == first(game_id)) |>
    slice_head(n = 5)
)

message("\nSample of summary data:")
print(
  summary_data |>
    filter(game_id == first(game_id))
)
