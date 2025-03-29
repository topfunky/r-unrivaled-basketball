# Purpose: Creates a win probability model using XGBoost and visualizes it with ggplot.

# Load required libraries
library(tidyverse)
library(xgboost)
library(feather)
library(gghighcontrast)

# Read play by play data
message("Reading play by play data...")
play_by_play <- read_feather("unrivaled_play_by_play.feather")

# Prepare features for the model
message("Preparing features for the model...")
model_data <- play_by_play |>
  # Group by game to calculate game-level features
  group_by(game_id) |>
  # Calculate running features
  mutate(
    # Play number within game
    play_count = row_number(),
    # Time remaining in seconds (only up to end of 3rd quarter)
    time_remaining = if_else(
      quarter <= 3,
      (minute * 60 + second),
      0  # No time remaining in 4th quarter
    ),
    # Point differential
    point_diff = away_score - home_score,
    # Running total points
    total_points = away_score + home_score,
    # Quarter weight (later quarters are more important)
    quarter_weight = quarter / 4,
    # Time weight (less time remaining is more important)
    time_weight = 1 - (time_remaining / (7 * 60)),  # 7 minutes per quarter
    # Projected winning score (highest score at end of 3rd quarter + 11)
    projected_winning_score = if_else(
      quarter <= 3,
      max(away_score[quarter <= 3], home_score[quarter <= 3]) + 11,
      max(away_score[quarter <= 3], home_score[quarter <= 3]) + 11
    ),
    # Points needed for each team
    away_points_needed = projected_winning_score - away_score,
    home_points_needed = projected_winning_score - home_score,
    # Final result (1 if away team won, 0 if home team won)
    away_win = if_else(last(away_score) > last(home_score), 1, 0)
  ) |>
  ungroup()

# Prepare training data
message("Preparing training data...")
X <- model_data |>
  select(
    quarter,
    time_remaining,
    point_diff,
    total_points,
    quarter_weight,
    time_weight,
    play_count,
    away_points_needed,
    home_points_needed
  ) |>
  as.matrix()

y <- model_data$away_win

# Train XGBoost model
message("Training XGBoost model...")
model <- xgboost(
  data = X,
  label = y,
  nrounds = 100,
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8
)

# Generate predictions
message("Generating win probability predictions...")
model_data$win_prob <- predict(model, X)

# Save the data with win probabilities
message("Saving data with win probabilities...")
write_feather(model_data, "unrivaled_play_by_play_wp.feather")

# Create visualization for each game
message("Creating win probability visualizations...")
for (game in unique(model_data$game_id)) {
  game_data <- model_data |>
    filter(game_id == game)

  # Create win probability visualization
  p <- ggplot(game_data, aes(x = play_count)) +
    geom_line(aes(y = win_prob, color = "Win Probability"), linewidth = 1) +
    geom_line(aes(y = point_diff/100, color = "Point Differential"), linewidth = 1) +
    scale_y_continuous(
      name = "Win Probability",
      sec.axis = sec_axis(~.*100, name = "Point Differential")
    ) +
    scale_color_manual(
      name = "Metric",
      values = c("Win Probability" = "#FF6B6B", "Point Differential" = "#4ECDC4")
    ) +
    labs(
      title = paste0("Win Probability and Point Differential - ", game),
      x = "Play Number",
      color = "Metric"
    ) +
    theme_high_contrast() +
    theme(
      text = element_text(family = "InputMono"),
      plot.title = element_text(size = 14, hjust = 0.5),
      axis.title = element_text(size = 12),
      axis.text = element_text(size = 10),
      legend.title = element_text(size = 12),
      legend.text = element_text(size = 10),
      legend.position = "bottom"
    )

  # Save the plot
  ggsave(
    filename = file.path("plots", sprintf("win_prob_%s.png", game)),
    plot = p,
    width = 10,
    height = 6,
    dpi = 300
  )
}

message("All visualizations saved to plots/ directory!")