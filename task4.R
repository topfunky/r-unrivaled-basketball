# Load required libraries
library(tidyverse)
library(lubridate)
library(elo)  # For ELO calculations

# Read the CSV data
games <- read_csv("fixtures/unrivaled_scores.csv") |>
  # Calculate results (1 for home win, 0 for away win, 0.5 for tie)
  mutate(
    result = case_when(
      home_team_score > away_team_score ~ 1,  # Home win
      home_team_score < away_team_score ~ 0,  # Away win
      TRUE ~ 0.5                              # Tie
    )
  ) |>
  arrange(date)

# Initialize ELO ratings
elo_ratings <- elo.run(
  formula = result ~ home_team + away_team,
  data = games,
  k = 32,  # Standard K-factor
  initial.ratings = 1500  # Standard starting rating
)

# Get ratings after each game
ratings_history <- as.data.frame(elo_ratings) |>
  mutate(
    date = games$date,
    home_team = games$home_team,
    away_team = games$away_team,
    result = games$result
  )

# Print ratings after each game
print("ELO Ratings After Each Game:")
ratings_history |>
  select(date, home_team, away_team, result, elo.A, elo.B) |>
  print()

# Print final ELO ratings
print("\nFinal ELO Ratings:")
# Combine home and away ratings for each team
final_ratings <- bind_rows(
  # Home team ratings
  ratings_history |>
    group_by(team = home_team) |>
    arrange(desc(date)) |>
    slice(1) |>
    select(date, team, elo_rating = elo.A),
  # Away team ratings
  ratings_history |>
    group_by(team = away_team) |>
    arrange(desc(date)) |>
    slice(1) |>
    select(date, team, elo_rating = elo.B)
) |>
  # Get the most recent rating for each team
  group_by(team) |>
  arrange(desc(date)) |>
  slice(1) |>
  arrange(desc(elo_rating))

print(final_ratings)

# Save the ELO rankings
write_feather(ratings_history, "unrivaled_elo_rankings.feather")
