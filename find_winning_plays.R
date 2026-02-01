# Purpose: Identify the last scoring play for each game in the Unrivaled season.
# Definition: The "winning play" is defined here as the chronologically last play
# recorded in the dataset for each game that resulted in points being scored
# (via a made 2-pt, 3-pt, or free throw).

library(tidyverse)
library(feather)
library(knitr)

# Get season from command line argument or default to 2026
args <- commandArgs(trailingOnly = TRUE)
season_year <- if (length(args) > 0) as.numeric(args[1]) else 2026

message(sprintf("Processing season %d...", season_year))

# Load play-by-play data from season-specific directory
data_dir <- file.path("data", season_year)
pbp_data <- read_feather(file.path(data_dir, "unrivaled_play_by_play.feather"))

# Load schedule data to get team names
schedule_data <- read_csv(
  "data/unrivaled_scores.csv",
  show_col_types = FALSE
) |>
  filter(season == season_year)
schedule_teams <- schedule_data |>
  select(game_id, home_team, away_team)

pbp_data <- pbp_data |>
  left_join(schedule_teams, by = "game_id", relationship = "many-to-many") |>
  # Remove irrelevant end of game plays
  filter(play != "End of Game", !str_detect(play, "assist"))

# Find the last scoring play for each game
winning_plays <- pbp_data |>
  # Group by game
  group_by(game_id) |>
  # Find last play in each game
  slice_tail(n = 1) |>
  # Ungroup for further operations
  ungroup() |>
  # Identify the winning team (the team that scored the last points)
  mutate(winning_team = pos_team) |>
  # Select relevant columns
  select(
    game_id,
    play,
    pos_team
  )

# Print the list of winning plays
kable(winning_plays, format = "markdown")

# Count the types of winning plays
play_type_counts <- winning_plays |>
  mutate(
    play_type = case_when(
      str_detect(play, regex("two point", ignore_case = TRUE)) ~ "Two Point",
      str_detect(play, regex("three point", ignore_case = TRUE)) ~
        "Three Point",
      str_detect(play, regex("free throw", ignore_case = TRUE)) ~ "Free Throw",
      TRUE ~ "Other" # Catch any plays not matching the above
    )
  ) |>
  count(play_type)

# Extract player name and count winning plays per player
winning_player_counts <- winning_plays |>
  # Extract player name by splitting on ' made ' and taking the first part
  mutate(
    player_name = sapply(str_split(play, " makes "), `[`, 1),
    # Trim whitespace from extracted name
    player_name = str_trim(player_name)
  ) |>
  # Filter out rows where player name couldn't be extracted (e.g., team rebounds)
  filter(!is.na(player_name)) |>
  # Count winning plays per player
  count(player_name, sort = TRUE, name = "winning_plays_count")

# Print the table of winning player counts
kable(winning_player_counts, format = "markdown")

# Print the tibble as a Markdown table
kable(play_type_counts, format = "markdown")
