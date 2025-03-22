# Load required libraries
library(tidyverse)
library(lubridate)

# Read the rankings data
rankings <- read_feather("unrivaled_rankings_3.feather")

# ELO parameters
K_FACTOR <- 32  # Standard K-factor for ELO calculations
INITIAL_RATING <- 1500  # Standard starting ELO rating

# Initialize ratings for all teams
team_ratings <- rankings |>
  distinct(team) |>
  mutate(rating = INITIAL_RATING)

# Calculate ELO ratings game by game
elo_rankings <- rankings |>
  arrange(date) |>
  # Process each game
  group_by(date) |>
  group_modify(function(data, group) {
    # Get current ratings for both teams
    home_rating <- team_ratings$rating[team_ratings$team == data$team[1]]
    away_rating <- team_ratings$rating[team_ratings$team == data$opponent[1]]

    # Calculate expected scores
    home_expected <- 1 / (1 + 10^((away_rating - home_rating) / 400))
    away_expected <- 1 - home_expected

    # Calculate actual scores
    home_actual <- case_when(
      data$result[1] == "W" ~ 1,
      data$result[1] == "L" ~ 0,
      TRUE ~ 0.5
    )
    away_actual <- 1 - home_actual

    # Calculate rating changes
    home_change <- K_FACTOR * (home_actual - home_expected)
    away_change <- K_FACTOR * (away_actual - away_expected)

    # Update ratings
    team_ratings$rating[team_ratings$team == data$team[1]] <<- home_rating + home_change
    team_ratings$rating[team_ratings$team == data$opponent[1]] <<- away_rating + away_change

    # Add ratings to the data
    data |>
      mutate(
        elo_rating = home_rating + home_change,
        opponent_elo = away_rating + away_change
      )
  }) |>
  ungroup()

# Print final ELO ratings
print("Final ELO Ratings:")
elo_rankings |>
  group_by(team) |>
  slice_max(date, n = 1) |>
  select(team, elo_rating) |>
  arrange(desc(elo_rating)) |>
  print()

# Save the ELO rankings
write_feather(elo_rankings, "unrivaled_elo_rankings.feather")