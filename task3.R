# Load required libraries
library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)
library(ggbump)  # For smooth bump charts

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
# Define plot parameters
line_width <- 6
dot_size <- 8
label_size <- 4

p <- game_rankings |>
  ggplot(aes(x = games_played, y = rank, color = team)) +
  # Use geom_bump for smooth lines and points
  geom_bump(
    linewidth = line_width,
    size = dot_size,
    show.legend = FALSE    # Don't show in legend
  ) +
  # Use bright purple for Rose, shades of grey for others
  scale_color_manual(
    values = c(
      "Rose" = "#9B30FF",        # Bright purple
      "Lunar Owls" = "#808080",  # Medium grey
      "Mist" = "#A9A9A9",        # Dark grey
      "Laces" = "#C0C0C0",       # Silver
      "Phantom" = "#D3D3D3",     # Light grey
      "Vinyl" = "#E6E6E6"        # Very light grey
    )
  ) +
  # Reverse y-axis so rank 1 is at the top
  scale_y_reverse(breaks = 1:6) +
  # Add team labels at the end of each line
  geom_text(
    data = game_rankings |>
      group_by(team) |>
      slice_max(games_played, n = 1),
    aes(label = team),
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
    subtitle = "Team Rankings After Equal Number of Games",
    x = "Games Played",
    y = "Rank",
    color = "Team"
  )

# Save the plot
ggsave("unrivaled_rankings_3.png", p, width = 12, height = 8, dpi = 300)

# Save the data
write_feather(game_rankings, "unrivaled_rankings_3.feather")
