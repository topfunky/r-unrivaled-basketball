# Purpose: Creates a markdown table of final regular season standings including
# team name, record, point differential, and ELO score.

# Load required libraries
library(tidyverse)
library(feather)

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
cat("\n| Team | Record | Point Differential | ELO Rating |\n")
cat("|------|---------|-------------------|------------|\n")
final_stats |>
  {
    \(x)
      walk(
        seq_len(nrow(x)),
        \(i)
          cat(sprintf(
            "| %s | %s | %s | %d |\n",
            x$team[i],
            x$record[i],
            x$point_differential[i],
            x$elo_rating[i]
          ))
      )
  }()

# Save the data
write_feather(final_stats, "unrivaled_final_stats.feather")
