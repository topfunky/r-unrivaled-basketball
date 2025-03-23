# Purpose: Creates a bump chart visualization of team rankings based on games played,
# using data from the scraped scores CSV. Calculates rankings after each game and
# displays them with custom Unrivaled colors and high contrast theme. Outputs include
# a PNG chart and a feather file with the rankings data.

# Load required libraries
library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)
library(ggbump)  # For smooth bump charts

# Import team colors
source("team_colors.R")

# Read the CSV data
games <- read_csv("fixtures/unrivaled_scores.csv")

# Transform data into long format for analysis
games_long <- games |>
  # Create away team rows
  mutate(
    team = away_team,
    score = away_team_score,
    opponent = home_team,
    opponent_score = home_team_score,
    is_home = FALSE
  ) |>
  # Add home team rows
  bind_rows(
    games |>
      mutate(
        team = home_team,
        score = home_team_score,
        opponent = away_team,
        opponent_score = away_team_score,
        is_home = TRUE
      )
  ) |>
  # Calculate wins and losses
  mutate(
    result = case_when(
      score > opponent_score ~ "W",
      score < opponent_score ~ "L",
      TRUE ~ "T"
    ),
    point_differential = score - opponent_score
  )

print(games_long)

# Calculate cumulative wins and losses for each team
team_records <- games_long |>
  select(date, team, score, opponent, opponent_score, is_home, result, point_differential, season_type) |>
  group_by(team) |>
  arrange(date) |>
  mutate(
    wins = cumsum(result == "W"),
    losses = cumsum(result == "L"),
    games_played = cumsum(!is.na(result)),  # Count cumulative games played
    point_differential = cumsum(score - opponent_score)  # Cumulative point differential
  )

print(team_records)

# Create rankings based on games played
game_rankings <- team_records |>
  # Group by games_played to compare teams with same number of games
  group_by(games_played) |>
  mutate(
    # Calculate rankings for each games_played group
    rank = rank(
      -wins,  # Negative wins so highest wins gets lowest rank number
      ties.method = "min"  # Teams with same record get same rank
    )
  ) |>
  # Fill in the ranks for the rest of the week
  group_by(team) |>
  fill(rank, .direction = "down") |>
  ungroup()

print(game_rankings)

# Print final standings with point differential
print("\nFinal Standings with Point Differential:")
final_standings <- team_records |>
  group_by(team) |>
  slice_max(games_played, n = 1) |>
  select(team, wins, losses, point_differential) |>
  arrange(desc(wins), desc(point_differential))
print(final_standings)

# Create the bump chart
# Define plot parameters
line_width <- 4
dot_size <- 8
label_size <- 3

p <- game_rankings |>
  ggplot(aes(x = games_played, y = rank, color = team)) +
  # Use geom_bump for smooth lines and points
  geom_bump(
    linewidth = line_width,
    size = dot_size,
    show.legend = FALSE    # Don't show in legend
  ) +
  # Use team colors from imported palette
  scale_color_manual(values = TEAM_COLORS) +
  # Reverse y-axis so rank 1 is at the top
  scale_y_reverse(breaks = 1:6) +
  # Add team labels at the end of each line
  geom_text(
    data = game_rankings |>
      group_by(team) |>
      slice_max(games_played, n = 1) |>
    mutate(
      x_offset = case_when(
        team == "Rose" ~ -1,
        team == "Lunar Owls" ~ -3,
        team == "Mist" ~ 0.75,
        team == "Laces" ~ -1.5,
        team == "Phantom" ~ 0,
        team == "Vinyl" ~ 0
      ),
      y_offset = case_when(
        team == "Rose" ~ -0.4,
        team == "Lunar Owls" ~ 0.35,
        team == "Mist" ~ 0,
        team == "Laces" ~ 0.35,
        team == "Phantom" ~ 0,
        team == "Vinyl" ~ 0
      )
    ),
    aes(
      label = team,
      x = games_played + x_offset,
      y = rank + y_offset
    ),
    hjust = -0.2,
    size = label_size,
    family = "InputMono",  # Use InputMono font for team labels
    show.legend = FALSE    # Don't show in legend
  ) +
  # Use gghighcontrast theme with white text on black background
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  ) +
  # Style grid lines in dark grey
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  # Add labels
  labs(
    title = "Unrivaled Basketball League Rankings 2025",
    subtitle = "Team rankings throughout the season",
    x = "Games Played",
    y = "Rank",
    color = "Team",
    caption = "Game data from unrivaled.basketball",
  )

# Save the plot
ggsave("unrivaled_rankings_3.png", p, width = 6, height = 4, dpi = 300)

# Save the data
write_feather(game_rankings, "unrivaled_rankings_3.feather")
