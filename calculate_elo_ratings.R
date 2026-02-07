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
library(ggbump) # For smooth bump charts
library(feather) # For saving data in feather format
library(knitr) # For markdown table formatting

# Import team colors
source("R/team_colors.R")

# Full Unrivaled regular season length (games per team)
GAMES_IN_REGULAR_SEASON <- 14L

# Calculate game results (1 for home win, 0 for away win, 0.5 for tie)
calculate_game_results <- function(games) {
  games |>
    mutate(
      result = case_when(
        home_team_score > away_team_score ~ 1,
        home_team_score < away_team_score ~ 0,
        TRUE ~ 0.5
      )
    ) |>
    arrange(date)
}

# Calculate Elo ratings using elo package
calculate_elo_ratings <- function(games) {
  # Get all teams that should be included (from team colors)
  all_teams <- names(TEAM_COLORS)

  # Create initial ratings for all teams
  initial_ratings <- setNames(rep(1500, length(all_teams)), all_teams)

  elo.run(
    formula = result ~ home_team + away_team,
    data = games,
    k = 32,
    initial.ratings = initial_ratings
  )
}

# Get ratings history with previous ratings
get_ratings_history <- function(elo_ratings, games, season_year) {
  as.data.frame(elo_ratings) |>
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
}

# Get final Elo ratings for each team
get_final_ratings <- function(ratings_history, elo_ratings) {
  # Get all teams that should be included
  all_teams <- names(TEAM_COLORS)

  # Get final ratings from elo.run object (includes all teams that were initialized)
  final_elos <- final.elos(elo_ratings)

  # Create tibble with all teams
  final_ratings <- tibble(
    team = all_teams,
    elo_rating = ifelse(team %in% names(final_elos), final_elos[team], 1500)
  ) |>
    arrange(desc(elo_rating))

  return(final_ratings)
}

# Prepare plot data in long format
prepare_plot_data <- function(ratings_history) {
  plot_data <- bind_rows(
    ratings_history |>
      select(
        date,
        game_id,
        team = home_team,
        elo_rating = home_team_elo,
        result
      ),
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
      games_played = cumsum(!is.na(result))
    ) |>
    ungroup()

  team_order <- plot_data |>
    group_by(team) |>
    slice_max(games_played, n = 1) |>
    ungroup() |>
    arrange(elo_rating) |>
    pull(team)

  plot_data |>
    mutate(
      team = factor(team, levels = team_order)
    )
}

# Create Elo ratings plot
create_elo_plot <- function(plot_data, season_year) {
  linewidth <- 2
  label_size <- 3
  max_games <- max(plot_data$games_played, na.rm = TRUE)

  label_data <- plot_data |>
    group_by(team) |>
    slice_max(games_played, n = 1) |>
    ungroup()

  p <- plot_data |>
    ggplot(aes(x = games_played, y = elo_rating, color = team)) +
    geom_bump(
      linewidth = linewidth,
      show.legend = FALSE
    ) +
    scale_color_manual(values = TEAM_COLORS) +
    geom_text_repel(
      data = label_data,
      aes(
        label = team,
        x = max_games,
        y = elo_rating
      ),
      hjust = 0,
      direction = "y",
      size = label_size,
      family = "InputMono",
      show.legend = FALSE,
      color = "white",
      fontface = "bold",
      segment.color = NA,
      min.segment.length = Inf
    ) +
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    ) +
    theme(
      panel.grid.major = element_line(color = "white", linewidth = 0.5),
      panel.grid.minor = element_line(color = "white", linewidth = 0.25)
    ) +
    scale_x_continuous(breaks = seq_len(GAMES_IN_REGULAR_SEASON)) +
    coord_cartesian(clip = "off", xlim = c(1, GAMES_IN_REGULAR_SEASON + 2)) +
    labs(
      title = paste0("Unrivaled Basketball League Elo Ratings ", season_year),
      subtitle = "Team ratings after each game",
      x = "Games Played",
      y = "Elo Rating",
      caption = "Game data from unrivaled.basketball"
    )

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

  p
}

# Save ratings data files
save_ratings_data <- function(final_ratings, ratings_history, season_year) {
  output_dir <- paste0("data/", season_year)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  write_feather(
    final_ratings,
    paste0(output_dir, "/unrivaled_final_elo_ratings.feather")
  )
  write_csv(
    final_ratings,
    paste0(output_dir, "/unrivaled_final_elo_ratings.csv")
  )

  write_feather(
    ratings_history,
    paste0(output_dir, "/unrivaled_elo_rankings.feather")
  )
  write_csv(
    ratings_history,
    paste0(output_dir, "/unrivaled_elo_rankings.csv")
  )
}

# Save plot to file
save_elo_plot <- function(plot, season_year) {
  plots_dir <- file.path("plots", season_year)
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

  ggsave(
    file.path(plots_dir, "unrivaled_elo_ratings.png"),
    plot,
    width = 6,
    height = 4,
    dpi = 300
  )
}

# Print ratings information
print_ratings_info <- function(ratings_history, final_ratings, season_year) {
  cat("## Elo Ratings After Each Game (", season_year, ")\n\n", sep = "")

  ratings_table <- ratings_history |>
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
    knitr::kable(format = "markdown", digits = 1)

  cat(ratings_table, sep = "\n")
  cat("\n\n")

  cat(
    "## 🏀 Final Regular Season Elo Ratings (",
    season_year,
    ")\n\n",
    sep = ""
  )

  final_table <- final_ratings |>
    knitr::kable(format = "markdown", digits = 1)

  cat(final_table, sep = "\n")
  cat("\n\n")
}

# Process a single season
process_season <- function(all_games, season_year) {
  print(paste0("Processing season ", season_year, "..."))

  games <- all_games |>
    filter(season == season_year) |>
    calculate_game_results()

  if (nrow(games) == 0) {
    print(paste0("No games found for season ", season_year, ". Skipping..."))
    return(invisible(NULL))
  }

  elo_ratings <- calculate_elo_ratings(games)
  ratings_history <- get_ratings_history(elo_ratings, games, season_year)
  final_ratings <- get_final_ratings(ratings_history, elo_ratings)

  print_ratings_info(ratings_history, final_ratings, season_year)

  save_ratings_data(final_ratings, ratings_history, season_year)

  plot_data <- prepare_plot_data(ratings_history)
  plot <- create_elo_plot(plot_data, season_year)
  save_elo_plot(plot, season_year)

  print(paste0("✅ Completed processing season ", season_year))
}

# Main execution
all_games <- read_csv("data/unrivaled_scores.csv")
seasons <- c(2025, 2026)

for (season_year in seasons) {
  process_season(all_games, season_year)
}
