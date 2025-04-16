# Purpose: Identify the last scoring play for each game in the Unrivaled season.
# Definition: The "winning play" is defined here as the chronologically last play
# recorded in the dataset for each game that resulted in points being scored
# (via a made 2-pt, 3-pt, or free throw).

library(tidyverse)
library(feather)

# Load play-by-play data
pbp_data <- read_feather("unrivaled_play_by_play.feather")

# Load schedule data to get team names
schedule_data <- read_csv(
  "fixtures/unrivaled_scores.csv",
  show_col_types = FALSE
)
schedule_teams <- schedule_data |>
  select(game_id, home_team, away_team)

pbp_data <- pbp_data |>
  left_join(schedule_teams, by = "game_id") |>
  filter(play != "End of Game", !str_detect(play, "assist")) # Irrelevant end of game plays

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
print(winning_plays)

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

# Print the table of play type counts
print(play_type_counts)
