# Purpose: Creates a markdown table of final regular season standings including
# team name, record, point differential, and ELO score.

# Load required libraries
library(tidyverse)
library(feather)
library(knitr)

# Read the data files
rankings <- read_feather("unrivaled_regular_season_standings.feather")
elo_rankings <- read_feather("unrivaled_final_elo_ratings.feather")

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
write_feather(final_stats, "unrivaled_final_stats.feather")
