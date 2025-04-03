# Purpose: Creates separate win probability models for quarters 1-3 and
# quarter 4 using XGBoost and visualizes them with ggplot.

# Load required libraries
library(tidyverse)
library(xgboost)
library(feather)
library(gghighcontrast)

# Create plots directory if it doesn't exist
message("Creating plots directory if it doesn't exist...")
dir.create("plots", showWarnings = FALSE, recursive = TRUE)

# Source calibration functions
source("calibration.R")

# Read play by play data
message("Reading play by play data...")
play_by_play <- read_feather("unrivaled_play_by_play.feather")

# Read ELO rankings data
elo_rankings <- read_feather("unrivaled_elo_rankings.feather") |>
  select(game_id, home_team_elo_prev, away_team_elo_prev) |>
  distinct()

# Calculate average points per possession for quarter 4 estimation
points_per_possession <- play_by_play |>
  group_by(game_id) |>
  mutate(
    # Detect possession changes, ignoring personal fouls
    is_personal_foul = str_detect(tolower(play), "personal foul"),
    possession_change = !is_personal_foul &
      pos_team != lead(pos_team, default = first(pos_team))
  ) |>
  summarise(
    # Get final scores for total points
    final_home_score = max(home_score, na.rm = TRUE),
    final_away_score = max(away_score, na.rm = TRUE),
    total_points = final_home_score + final_away_score,
    # Add 1 for first possession
    total_possessions = sum(possession_change, na.rm = TRUE) + 1
  ) |>
  summarise(
    points_per_possession = sum(total_points) / sum(total_possessions)
  ) |>
  pull(points_per_possession)

# Prepare features for the model
message("Preparing features for the model...")
model_data <- play_by_play |>
  # Join with ELO rankings to get ELO ratings
  left_join(elo_rankings, by = "game_id", relationship = "many-to-many") |>
  # Group by game to calculate game-level features
  group_by(game_id) |>
  mutate(
    # Play number within game
    play_count = row_number(),
    # Time remaining in seconds (only up to end of 3rd quarter)
    time_remaining = if_else(
      quarter <= 3,
      (minute * 60 + second),
      NA_real_ # 4th quarter is untimed
    ),
    # Point differential
    point_diff = away_score - home_score,
    # Quarter weight (later quarters are more important)
    quarter_weight = quarter / 4,
    # Time weight (less time remaining is more important)
    time_weight = 1 - (time_remaining / (7 * 60)), # 7 minutes per quarter
    # ELO differential (positive means home team is stronger)
    elo_diff = home_team_elo_prev - away_team_elo_prev,
    # Projected winning score (highest score at end of 3rd quarter + 11)
    projected_winning_score = if_else(
      quarter <= 3,
      max(away_score[quarter <= 3], home_score[quarter <= 3]) + 11,
      max(away_score[quarter <= 3], home_score[quarter <= 3]) + 11
    ),
    # Points needed for each team
    away_points_needed = projected_winning_score - away_score,
    home_points_needed = projected_winning_score - home_score,
    # Estimated plays remaining (only in quarter 4)
    estimated_plays_remaining = if_else(
      quarter == 4,
      pmin(away_points_needed, home_points_needed) / points_per_possession,
      NA_real_
    ),
    # Final result (1 if away team won, 0 if home team won)
    away_win = if_else(last(away_score) > last(home_score), 1, 0)
  ) |>
  ungroup()

# Split data into quarters 1-3 and quarter 4
message("Splitting data into quarters 1-3 and quarter 4...")
data_q1q3 <- model_data |>
  filter(quarter <= 3)

data_q4 <- model_data |>
  filter(quarter == 4)

# Prepare training data for quarters 1-3
message("Preparing training data for quarters 1-3...")
X_q1q3 <- data_q1q3 |>
  select(
    quarter,
    time_remaining,
    point_diff,
    quarter_weight,
    time_weight,
    play_count,
    elo_diff
  ) |>
  as.matrix()

y_q1q3 <- data_q1q3$away_win

# Prepare training data for quarter 4
message("Preparing training data for quarter 4...")
X_q4 <- data_q4 |>
  select(
    quarter,
    point_diff,
    quarter_weight,
    play_count,
    away_points_needed,
    home_points_needed,
    estimated_plays_remaining,
    elo_diff
  ) |>
  as.matrix()

y_q4 <- data_q4$away_win

# Set seed for reproducibility
set.seed(5150)

# Train XGBoost model for quarters 1-3
message("Training XGBoost model for quarters 1-3...")
model_q1q3 <- xgboost(
  data = X_q1q3,
  label = y_q1q3,
  nrounds = 100,
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8
)

# Train XGBoost model for quarter 4
message("Training XGBoost model for quarter 4...")
model_q4 <- xgboost(
  data = X_q4,
  label = y_q4,
  nrounds = 100,
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8
)

# Generate predictions for quarters 1-3
message("Generating win probability predictions for quarters 1-3...")
data_q1q3$win_prob <- predict(model_q1q3, X_q1q3)

# Generate predictions for quarter 4
message("Generating win probability predictions for quarter 4...")
data_q4$win_prob <- predict(model_q4, X_q4)

# Combine the predictions
message("Combining predictions...")
model_data <- bind_rows(data_q1q3, data_q4) |>
  arrange(game_id, play_count)

# Save the data with win probabilities
message("Saving data with win probabilities...")
write_feather(model_data, "unrivaled_play_by_play_wp.feather")

# Create calibration plot
message("Creating calibration plot...")
p_calibration <- create_calibration_plot(model_data)

# Create visualization for each game
message("Creating win probability visualizations...")
for (game in unique(model_data$game_id)) {
  game_data <- model_data |>
    filter(game_id == game)

  # Get first row for ELO annotation
  first_row <- game_data |>
    head(1)

  # Create win probability visualization
  p <- ggplot(game_data, aes(x = play_count)) +
    # Add vertical line at halftime
    geom_vline(
      data = game_data |>
        filter(quarter == 2) |>
        slice_max(play_count),
      aes(xintercept = play_count),
      color = "white",
      linetype = "dotted",
      linewidth = 1
    ) +
    # Point differential bars
    geom_bar(
      aes(y = point_diff, fill = point_diff > 0),
      stat = "identity",
      alpha = 0.3,
      width = 1
    ) +
    # Win probability line (on top of point differential bars)
    geom_line(
      aes(y = win_prob * 100, color = "Win Probability"),
      linewidth = 1
    ) +
    # Add ELO difference annotation
    annotate(
      "text",
      x = 0,
      y = max(100, max(game_data$point_diff)),
      label = paste0(
        "Home ELO: ",
        round(first_row$home_team_elo_prev),
        "\nAway ELO: ",
        round(first_row$away_team_elo_prev),
        "\nELO Diff: ",
        round(first_row$elo_diff)
      ),
      hjust = 0,
      vjust = 1,
      size = 3,
      color = "white"
    ) +
    # Set up the plot
    scale_fill_manual(
      values = c("TRUE" = "green", "FALSE" = "red"),
      guide = "none"
    ) +
    scale_color_manual(
      values = c("Win Probability" = "blue"),
      name = ""
    ) +
    coord_cartesian(
      ylim = c(
        min(game_data$point_diff),
        max(100, max(game_data$point_diff))
      )
    ) +
    labs(
      title = paste0("Win Probability and Point Differential - ", game),
      x = "Play Number",
      color = "Metric"
    ) +
    theme_minimal() +
    theme(
      plot.background = element_rect(fill = "black"),
      panel.background = element_rect(fill = "black"),
      text = element_text(color = "white"),
      axis.text = element_text(color = "white"),
      axis.line = element_line(color = "white"),
      panel.grid = element_line(color = "gray20")
    )

  # Save the plot
  ggsave(
    paste0("plots/win_probability_", game, ".png"),
    p,
    width = 10,
    height = 6,
    dpi = 300
  )
}

message("All visualizations saved to plots/ directory!")
