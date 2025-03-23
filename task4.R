# Purpose: Calculates and visualizes ELO ratings for each team throughout the season,
# using the scraped game data. Implements the ELO rating system using standard ELO defaults of a K-factor of 32
# and initial rating of 1500. Creates a line chart showing rating progression with
# custom Unrivaled colors and high contrast theme. Outputs include a PNG chart and
# a feather file with the ELO ratings data.

# Load required libraries
library(tidyverse)
library(lubridate)
library(elo)  # For ELO calculations
library(ggplot2)
library(gghighcontrast)

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


# Create a long format dataset for plotting
plot_data <- bind_rows(
  # Home team ratings
  ratings_history |>
    select(date, team = home_team, elo_rating = elo.A, result),
  # Away team ratings
  ratings_history |>
    select(date, team = away_team, elo_rating = elo.B, result)
) |>
  arrange(date) |>
    group_by(team) |>
  mutate(
    games_played = cumsum(!is.na(result))  # Count cumulative games played
  ) |>
  ungroup() |>
  # Add offset columns for label positioning
  mutate(
    x_offset = case_when(
      team == "Rose" ~ -1.75,
      team == "Lunar Owls" ~ -5.5,
      team == "Mist" ~ 1.15,
      team == "Laces" ~ 1.25,
      team == "Phantom" ~ 0.75,
      team == "Vinyl" ~ 1
    ),
    y_offset = case_when(
      team == "Rose" ~ 0,
      team == "Lunar Owls" ~ 10,
      team == "Mist" ~ 0,
      team == "Laces" ~ 0,
      team == "Phantom" ~ -15,
      team == "Vinyl" ~ 0
    )
  ) |>
  # Reorder data so Rose appears last (on top)
  arrange(team != "Rose")

# Define plot parameters
linewidth <- 4
dot_size <- 6
label_size <- 3

# Create the ELO ratings chart
p <- plot_data |>
  ggplot(aes(x = games_played, y = elo_rating, color = team)) +
  geom_line(linewidth = linewidth, show.legend = FALSE) +
  # Add points only at the end of each line
  geom_point(
    data = plot_data |>
      group_by(team) |>
      slice_max(games_played, n = 1),
    size = dot_size,
    show.legend = FALSE
  ) +
  # Use custom Unrivaled purple colors for each team
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
  # Add team labels at the end of each line
  geom_text(
    data = plot_data |>
      group_by(team) |>
      slice_max(games_played, n = 1),
    aes(
      label = team,
      x = games_played + x_offset,
      y = elo_rating + y_offset
    ),
    hjust = 0.5,  # Center text horizontally
    size = 3,
    family = "InputMono",
    show.legend = FALSE
  ) +
  # Use gghighcontrast theme with white text on black background
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  ) +
  # Style grid lines in dark grey
  theme(
    panel.grid.major = element_line(color = "#1A1A1A", linewidth = 0.5),
    panel.grid.minor = element_line(color = "#1A1A1A", linewidth = 0.25)
  ) +
  # Add labels
  labs(
    title = "Unrivaled Basketball League ELO Ratings 2025",
    subtitle = "Team ratings throughout the season",
    x = "Games Played",
    y = "ELO Rating",
    caption = "Game data from unrivaled.basketball",
  )

# Save the plot
ggsave("unrivaled_elo_ratings.png", p, width = 6, height = 4, dpi = 300)

# Save the ELO rankings
write_feather(ratings_history, "unrivaled_elo_rankings.feather")
