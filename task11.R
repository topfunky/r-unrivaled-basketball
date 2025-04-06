# Purpose: Downloads player shooting percentages
# (free throws, 2pt, and 3pt shots)
# for the most recent WNBA season and saves them to a feather file.

# Load required libraries
library(tidyverse)
library(wehoop)
library(feather)
library(glue)

# Set seed for reproducibility
set.seed(5150)

# Create fixtures directory if it doesn't exist
message("Creating fixtures directory if it doesn't exist...")
dir.create("fixtures", showWarnings = FALSE, recursive = TRUE)

# Function to get WNBA player shooting stats
get_wnba_shooting_stats <- function(season = NULL) {
  message(glue("Getting WNBA player shooting stats for {season} season..."))

  # Get the most recent season if not specified
  if (is.null(season)) {
    season <- most_recent_wnba_season() - 1
  }

  # Get player stats from WNBA Stats API
  player_stats <- wnba_leaguedashplayerstats(
    season = season,
    measure_type = "Base",
    per_mode = "Totals"
  )

  # Extract the data frame from the list
  shooting_stats <- player_stats$LeagueDashPlayerStats |>
    # Convert character columns to numeric where appropriate
    mutate(
      across(
        c(GP, MIN, FGM, FGA, FG3M, FG3A, FTM, FTA, PTS),
        ~ as.numeric(.)
      ),
      across(
        c(FG_PCT, FG3_PCT, FT_PCT),
        ~ as.numeric(.)
      ),
      # Add season column
      season = season
    ) |>
    # Rename columns for clarity
    rename(
      player_name = PLAYER_NAME,
      team = TEAM_ABBREVIATION,
      games_played = GP,
      minutes_played = MIN,
      fg_made = FGM,
      fg_attempted = FGA,
      fg_pct = FG_PCT,
      fg3_made = FG3M,
      fg3_attempted = FG3A,
      fg3_pct = FG3_PCT,
      ft_made = FTM,
      ft_attempted = FTA,
      ft_pct = FT_PCT,
      points = PTS
    ) |>
    # Select relevant columns
    select(
      player_name,
      team,
      season,
      games_played,
      minutes_played,
      fg_made,
      fg_attempted,
      fg_pct,
      fg3_made,
      fg3_attempted,
      fg3_pct,
      ft_made,
      ft_attempted,
      ft_pct,
      points
    )

  return(shooting_stats)
}

# Get the most recent season
current_month <- as.numeric(format(Sys.Date(), "%m"))
current_year <- as.numeric(format(Sys.Date(), "%Y"))

# WNBA season typically runs from May to September
# If current month is before May, use previous year's season
# If current month is after September, use current year's season
# Otherwise, check if we're in the middle of the season
if (current_month < 5) {
  season <- current_year - 1
} else if (current_month > 9) {
  season <- current_year
} else {
  # We're in the middle of the season, use current year
  season <- current_year
}

# Get the shooting stats
wnba_shooting_stats <- get_wnba_shooting_stats(season)

# Save to feather file
output_file <- glue("fixtures/wnba_shooting_stats_{season}.feather")
message(glue("Saving shooting stats to {output_file}..."))
write_feather(wnba_shooting_stats, output_file)

# Print summary of the data
message("Summary of WNBA shooting stats:")
summary(wnba_shooting_stats)

# Print top 10 players by field goal percentage (minimum 100 attempts)
message("Top 10 players by field goal percentage (minimum 100 attempts):")
wnba_shooting_stats |>
  filter(fg_attempted >= 100) |>
  arrange(desc(fg_pct)) |>
  select(player_name, team, fg_pct, fg3_pct, ft_pct) |>
  head(10) |>
  print()

message("Task completed successfully!")
