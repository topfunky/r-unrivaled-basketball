# Purpose:
# Calculates and visualizes Elo ratings for each team throughout the season,
# using the scraped game data. Implements the Elo rating system using
# standard Elo defaults of a K-factor of 32
# and initial rating of 1500.
# Creates a line chart showing rating progression with
# custom Unrivaled colors and high contrast theme.
# Outputs include a PNG chart and
# a feather file with the Elo ratings data.
# Processes 2025 and 2026 seasons separately.

# Load required libraries
library(tidyverse)
library(lubridate)
library(elo) # For Elo calculations
library(ggplot2)
library(gghighcontrast)
library(ggrepel) # For non-overlapping labels
library(feather) # For saving data in feather format

# Import team colors
source("team_colors.R")

# Read the CSV data
all_games <- read_csv("fixtures/unrivaled_scores.csv")

# Process each season separately
seasons <- c(2025, 2026)

for (season_year in seasons) {
  print(paste0("Processing season ", season_year, "..."))

  # Filter games for this season
  games <- all_games |>
    filter(season == season_year) |>
    # Calculate results (1 for home win, 0 for away win, 0.5 for tie)
    mutate(
      result = case_when(
        home_team_score > away_team_score ~ 1, # Home win
        home_team_score < away_team_score ~ 0, # Away win
        TRUE ~ 0.5 # Tie
      )
    ) |>
    arrange(date)

  # Skip if no games for this season
  if (nrow(games) == 0) {
    print(paste0("No games found for season ", season_year, ". Skipping..."))
    next
  }

  # Initialize Elo ratings
  elo_ratings <- elo.run(
    formula = result ~ home_team + away_team,
    data = games,
    k = 32, # Standard K-factor
    initial.ratings = 1500 # Standard starting rating
  )

  # Get ratings after each game
  ratings_history <- as.data.frame(elo_ratings) |>
    mutate(
      date = games$date,
      game_id = games$game_id,
      home_team = games$home_team,
      away_team = games$away_team,
      result = games$result,
      season = season_year
    ) |>
    rename(
      home_team_elo = elo.A,
      away_team_elo = elo.B
    ) |>
    # Add previous Elo ratings for each team
    group_by(home_team) |>
    mutate(
      home_team_elo_prev = lag(home_team_elo, default = 1500)
    ) |>
    ungroup() |>
    group_by(away_team) |>
    mutate(
      away_team_elo_prev = lag(away_team_elo, default = 1500)
    ) |>
    ungroup()

  # Print ratings after each game
  print(paste0("Elo Ratings After Each Game (", season_year, "):"))
  ratings_history |>
    select(
      date,
      game_id,
      home_team,
      away_team,
      result,
      home_team_elo_prev,
      away_team_elo_prev,
      home_team_elo,
      away_team_elo
    ) |>
    print()

  # Print final Elo ratings
  # Combine home and away ratings for each team
  final_ratings <- bind_rows(
    # Home team ratings
    ratings_history |>
      group_by(team = home_team) |>
      arrange(desc(date)) |>
      slice(1) |>
      select(date, team, elo_rating = home_team_elo),
    # Away team ratings
    ratings_history |>
      group_by(team = away_team) |>
      arrange(desc(date)) |>
      slice(1) |>
      select(date, team, elo_rating = away_team_elo)
  ) |>
    # Get the most recent rating for each team
    group_by(team) |>
    arrange(desc(date)) |>
    slice(1) |>
    # Select only team and rating
    select(team, elo_rating) |>
    arrange(desc(elo_rating))

  print(paste0("🏀 Final Regular Season Elo Ratings (", season_year, "):"))
  print(final_ratings)

  # Create output directory if it doesn't exist
  output_dir <- paste0("data/", season_year)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Save final regular season ratings
  write_feather(
    final_ratings,
    paste0(output_dir, "/unrivaled_final_elo_ratings.feather")
  )
  write_csv(
    final_ratings,
    paste0(output_dir, "/unrivaled_final_elo_ratings.csv")
  )

  # Create a long format dataset for plotting
  plot_data <- bind_rows(
    # Home team ratings
    ratings_history |>
      select(
        date,
        game_id,
        team = home_team,
        elo_rating = home_team_elo,
        result
      ),
    # Away team ratings
    ratings_history |>
      select(
        date,
        game_id,
        team = away_team,
        elo_rating = away_team_elo,
        result
      )
  ) |>
    arrange(date) |>
    group_by(team) |>
    mutate(
      games_played = cumsum(!is.na(result)) # Count cumulative games played
    ) |>
    ungroup()

  # Calculate final Elo ratings to determine drawing order
  team_order <- plot_data |>
    group_by(team) |>
    slice_max(games_played, n = 1) |>
    ungroup() |>
    arrange(elo_rating) |>
    pull(team)

  # Sort teams by final Elo rating (ascending)
  # so higher-rated teams are drawn on top
  plot_data <- plot_data |>
    mutate(
      team = factor(team, levels = team_order)
    )

  # Define plot parameters
  linewidth <- 4
  dot_size <- 6
  label_size <- 3

  # Determine max games played for playoff line positioning
  max_games <- max(plot_data$games_played, na.rm = TRUE)
  # Adjust for different season lengths
  playoff_line <- if (season_year == 2025) 14 else max_games

  # Create the Elo ratings chart
  p <- plot_data |>
    ggplot(aes(x = games_played, y = elo_rating, color = team)) +
    geom_line(linewidth = linewidth, show.legend = FALSE) +
    # Use team colors from imported palette
    scale_color_manual(values = TEAM_COLORS) +
    # Add team labels at the end of each line using ggrepel
    geom_text_repel(
      data = plot_data |>
        group_by(team) |>
        slice_max(games_played, n = 1),
      aes(
        label = team,
        x = games_played,
        y = elo_rating
      ),
      direction = "y",
      hjust = 0,
      nudge_x = 0.5,
      size = 3,
      family = "InputMono",
      show.legend = FALSE,
      fontface = "bold",
      segment.color = NA
    ) +
    # Use gghighcontrast theme with white text on black background
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    ) +
    # Style grid lines
    theme(
      panel.grid.major = element_line(color = "white", linewidth = 0.5),
      panel.grid.minor = element_line(color = "white", linewidth = 0.25)
    ) +
    # Add labels
    labs(
      title = paste0("Unrivaled Basketball League Elo Ratings ", season_year),
      subtitle = "Team ratings after each game",
      x = "Games Played",
      y = "Elo Rating",
      caption = "Game data from unrivaled.basketball"
    )

  # Add playoff line and label for 2025 season if applicable
  if (season_year == 2025 && max_games >= 14) {
    p <- p +
      geom_vline(
        xintercept = 14,
        linetype = "dotted",
        color = "white",
        alpha = 0.5
      ) +
      annotate(
        "text",
        x = 14.2,
        y = 1410,
        label = "Playoffs",
        color = "#606060",
        family = "InputMono",
        size = 2,
        hjust = 0,
        vjust = 0.5
      )
  }

  # Create plots directory if it doesn't exist
  plots_dir <- file.path("plots", season_year)
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

  # Save the plot
  ggsave(
    file.path(plots_dir, "unrivaled_elo_ratings.png"),
    p,
    width = 6,
    height = 4,
    dpi = 300
  )

  # Save the Elo rankings
  write_feather(
    ratings_history,
    paste0(output_dir, "/unrivaled_elo_rankings.feather")
  )
  write_csv(ratings_history, paste0(output_dir, "/unrivaled_elo_rankings.csv"))

  print(paste0("✅ Completed processing season ", season_year))
}
