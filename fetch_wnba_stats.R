# Purpose: Downloads player shooting percentages
# (free throws, 2pt, and 3pt shots)
# for the most recent WNBA season and saves them to a feather file.

# Load required libraries
library(tidyverse)
library(wehoop)
library(feather)
library(glue)
library(gghighcontrast)
library(knitr)

source("team_colors.R")

# Set seed for reproducibility
set.seed(5150)

# Create data directory if it doesn't exist
message("Creating data directory if it doesn't exist...")
dir.create("data", showWarnings = FALSE, recursive = TRUE)

# Helper function for percentage formatting
format_pct <- function(value, digits = 1) {
  sprintf(paste0("%.", digits, "f%%"), value * 100)
}

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
      season = season,
      # Calculate true shooting percentage
      ts_pct = PTS / (2 * (FGA + 0.44 * FTA))
    ) |>
    # Rename columns for clarity
    rename(
      player_name = PLAYER_NAME,
      team = TEAM_ABBREVIATION,
      games_played = GP,
      minutes_played = MIN,
      field_goals_made = FGM,
      field_goals_attempted = FGA,
      field_goal_pct = FG_PCT,
      three_point_field_goals_made = FG3M,
      three_point_field_goals_attempted = FG3A,
      three_point_pct = FG3_PCT,
      free_throws_made = FTM,
      free_throws_attempted = FTA,
      free_throw_pct = FT_PCT,
      points = PTS
    ) |>
    # Select relevant columns
    select(
      player_name,
      team,
      season,
      games_played,
      minutes_played,
      field_goals_made,
      field_goals_attempted,
      field_goal_pct,
      three_point_field_goals_made,
      three_point_field_goals_attempted,
      three_point_pct,
      free_throws_made,
      free_throws_attempted,
      free_throw_pct,
      points,
      ts_pct
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
output_file <- glue("data/wnba_shooting_stats_{season}.feather")
message(glue("Saving shooting stats to {output_file}..."))
write_feather(wnba_shooting_stats, output_file)

# Print summary of the data
message("Summary of WNBA shooting stats:")
summary(wnba_shooting_stats)

# Print top 10 players by true shooting percentage (minimum 100 attempts)
message("Top 10 players by true shooting percentage (minimum 100 attempts):")
wnba_shooting_stats |>
  filter(field_goals_attempted >= 100) |>
  arrange(desc(ts_pct)) |>
  select(
    player_name,
    team,
    ts_pct,
    field_goal_pct,
    three_point_pct,
    free_throw_pct
  ) |>
  head(10) |>
  print()

# Create and save density plots with InputMono font
fg_pct_plot <- ggplot(wnba_shooting_stats, aes(x = field_goal_pct)) +
  geom_density(fill = wnba_color, alpha = 0.3) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "none"
  ) +
  labs(
    title = "Distribution of Field Goal Percentages",
    x = "Field Goal Percentage",
    y = "Density"
  )

ggsave(
  "plots/fg_pct_density.png",
  plot = fg_pct_plot,
  width = 8,
  height = 6,
  dpi = 300
)

ts_pct_plot <- ggplot(wnba_shooting_stats, aes(x = ts_pct)) +
  geom_density(fill = wnba_color, alpha = 0.3) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "none"
  ) +
  labs(
    title = "Distribution of True Shooting Percentages",
    x = "True Shooting Percentage",
    y = "Density"
  )

ggsave(
  "plots/ts_pct_density.png",
  plot = ts_pct_plot,
  width = 8,
  height = 6,
  dpi = 300
)

# Write results to markdown file
sink("plots/wnba_shooting_stats.md")

cat("# WNBA Shooting Statistics\n\n")

cat("\n## Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
wnba_shooting_stats |>
  filter(field_goals_attempted >= 10) |>
  arrange(desc(field_goal_pct)) |>
  head(10) |>
  mutate(
    `FG%` = format_pct(field_goal_pct),
    `FGM/FGA` = paste0(field_goals_made, "/", field_goals_attempted)
  ) |>
  select(Player = player_name, Team = team, `FG%`, `FGM/FGA`) |>
  kable(format = "markdown") |>
  print()

cat("\n## Top 10 Players by Three-Point Percentage (minimum 10 attempts)\n")
wnba_shooting_stats |>
  filter(three_point_field_goals_attempted >= 10) |>
  arrange(desc(three_point_pct)) |>
  head(10) |>
  mutate(
    `3P%` = format_pct(three_point_pct),
    `3PM/3PA` = paste0(
      three_point_field_goals_made,
      "/",
      three_point_field_goals_attempted
    )
  ) |>
  select(Player = player_name, Team = team, `3P%`, `3PM/3PA`) |>
  kable(format = "markdown") |>
  print()

cat("\n## Top 10 Players by Free Throw Percentage (minimum 10 attempts)\n")
wnba_shooting_stats |>
  filter(free_throws_attempted >= 10) |>
  arrange(desc(free_throw_pct)) |>
  head(10) |>
  mutate(
    `FT%` = format_pct(free_throw_pct),
    `FTM/FTA` = paste0(free_throws_made, "/", free_throws_attempted)
  ) |>
  select(Player = player_name, Team = team, `FT%`, `FTM/FTA`) |>
  kable(format = "markdown") |>
  print()

cat("\n## Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n")
wnba_shooting_stats |>
  filter(field_goals_attempted >= 10) |>
  arrange(desc(ts_pct)) |>
  head(10) |>
  mutate(`TS%` = format_pct(ts_pct)) |>
  select(
    Player = player_name,
    Team = team,
    `TS%`,
    PTS = points,
    FGA = field_goals_attempted,
    FTA = free_throws_attempted
  ) |>
  kable(format = "markdown") |>
  print()

sink()

message("Task completed successfully!")
