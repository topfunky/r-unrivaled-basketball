# Load required libraries
library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)

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
  select(date, team, score, opponent, opponent_score, is_home, result, point_differential) |>
  group_by(team) |>
  arrange(date) |>
  mutate(
    wins = cumsum(result == "W"),
    losses = cumsum(result == "L"),
    games_played = cumsum(!is.na(result))  # Count cumulative games played
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

# Create the bump chart
p <- game_rankings |>
  ggplot(aes(x = date, y = rank, color = team)) +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  # Use custom Unrivaled purple colors for each team
  scale_color_manual(
    values = c(
      "Lunar Owls" = "#8A2BE2",  # Deep purple
      "Mist" = "#9370DB",        # Medium purple
      "Rose" = "#9B30FF",        # Bright purple
      "Laces" = "#A020F0",       # Electric purple
      "Phantom" = "#B19CD9",     # Light purple
      "Vinyl" = "#C8A2C8"        # Pastel purple
    )
  ) +
  # Reverse y-axis so rank 1 is at the top
  scale_y_reverse(breaks = 1:6) +
  # Add team labels at the end of each line
  geom_text(
    data = game_rankings |>
      group_by(team) |>
      slice_max(date, n = 1),
    aes(label = team),
    hjust = -0.2,
    size = 4,
    family = "InputMono"  # Use InputMono font for team labels
  ) +
  # Use gghighcontrast theme with white text on black background
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  ) +
  # Add labels
  labs(
    title = "Unrivaled Basketball League Rankings",
    subtitle = "Team Rankings (1-6) After Equal Number of Games",
    x = "Date",
    y = "Rank",
    color = "Team"
  )

# Save the plot
ggsave("unrivaled_rankings_3.png", p, width = 12, height = 8, dpi = 300)

# Save the data
write_feather(game_rankings, "unrivaled_rankings_3.feather")
