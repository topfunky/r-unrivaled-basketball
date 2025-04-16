# Purpose: Exploratory analysis of the Unrivaled Basketball League data from sample fixture data. Creates a bump chart
# visualization of team rankings throughout the 14-week season using fixture data from a CSV file.
# The chart shows weekly rankings (1-6) with custom Unrivaled purple colors and high contrast theme.
# Outputs include a PNG chart and a feather file with the rankings data.
#
# Note: This task is exploratory and is not used in the final analysis.

# Load required libraries
library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)
library(feather)

# Create plots directory if it doesn't exist
message("Creating plots directory if it doesn't exist...")
dir.create("plots", showWarnings = FALSE, recursive = TRUE)

# Read fixture data from CSV file in fixtures subdirectory
fixtures <- read_csv("fixtures/fixtures.csv") |>
  mutate(date = as.Date(date))

# Create long format data for each team's games
team_games <- bind_rows(
  # Home games
  fixtures |>
    select(
      week_number,
      date,
      team = home_team,
      team_score = home_team_score,
      opponent = away_team,
      opponent_score = away_team_score
    ),
  # Away games
  fixtures |>
    select(
      week_number,
      date,
      team = away_team,
      team_score = away_team_score,
      opponent = home_team,
      opponent_score = home_team_score
    )
) |>
  arrange(week_number, date)

# Calculate wins and losses for each team by week
team_records <- team_games |>
  group_by(team) |>
  mutate(
    game_result = ifelse(team_score > opponent_score, 1, 0),
    wins = cumsum(game_result),
    losses = cumsum(1 - game_result),
    point_differential = team_score - opponent_score
  ) |>
  ungroup()

# Calculate weekly rankings (1 to 6)
weekly_rankings <- team_records |>
  group_by(week_number) |>
  # First sort by wins (descending), then by point differential (descending)
  arrange(desc(wins), desc(point_differential)) |>
  # Assign ranks from 1 to 6
  mutate(rank = row_number()) |>
  # Ensure rank is between 1 and 6
  mutate(rank = pmin(pmax(rank, 1), 6)) |>
  ungroup()

# Create bump chart with high contrast theme and Unrivaled purple colors
p <- ggplot(weekly_rankings, aes(x = week_number, y = rank, group = team)) +
  geom_line(aes(color = team), linewidth = 1.2) +
  geom_point(aes(color = team), size = 3) +
  scale_y_reverse(breaks = 1:6) +
  scale_x_continuous(breaks = 1:14) +
  scale_color_manual(
    values = c(
      "Lunar Owls" = "#6B4E71", # Darkest purple
      "Laces" = "#8B6B8F", # Dark purple
      "Vinyl" = "#A88AAD", # Medium purple
      "Phantom" = "#C5A9CB", # Light purple
      "Mist" = "#E2C8E9", # Very light purple
      "Rose" = "#FFE7FF" # Lightest purple
    )
  ) +
  labs(
    title = "Unrivaled Basketball League Rankings",
    subtitle = "Weekly Team Rankings (1-6) Throughout the 14-Week Season",
    x = "Week",
    y = "Rank (1 = Best)",
    color = "Team"
  ) +
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  ) +
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )


# Save the plot to a PNG file
ggsave("plots/unrivaled_rankings_1.png", p, width = 12, height = 8, dpi = 300)

# Save the data to a feather file
write_feather(weekly_rankings, "unrivaled_rankings_1.feather")
