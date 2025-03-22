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
    )
  )

# Calculate cumulative wins and losses for each team
team_records <- games_long |>
  group_by(team) |>
  arrange(date) |>
  mutate(
    wins = cumsum(result == "W"),
    losses = cumsum(result == "L")
  )

# Create weekly rankings
weekly_rankings <- team_records |>
  group_by(date) |>
  mutate(
    rank = rank(-wins + losses, ties.method = "min")
  ) |>
  ungroup()

# Create the bump chart
p <- weekly_rankings |>
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
    data = weekly_rankings |>
      group_by(team) |>
      slice_max(date, n = 1),
    aes(label = team),
    hjust = -0.2,
    size = 4,
    show.legend = FALSE
  ) +
  # Use gghighcontrast theme
  theme_high_contrast() +
  # Customize theme
  theme(
    plot.title = element_text(size = 16, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    legend.title = element_text(size = 12),
    legend.text = element_text(size = 10),
    panel.grid.major = element_line(color = "gray30"),
    panel.grid.minor = element_line(color = "gray20")
  ) +
  # Add labels
  labs(
    title = "Unrivaled Basketball League Rankings",
    x = "Date",
    y = "Rank",
    color = "Team"
  )

# Save the plot
ggsave("unrivaled_rankings_3.png", p, width = 12, height = 8, dpi = 300)

# Save the data
write_feather(weekly_rankings, "unrivaled_rankings_3.feather")