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
      NA_real_ # 4th quarter is untimed
    ),
    # Point differential
    point_diff = away_score - home_score,
    # Quarter weight (later quarters are more important)
    quarter_weight = quarter / 4,
    # Time weight (less time remaining is more important)
    time_weight = 1 - (time_remaining / (7 * 60)), # 7 minutes per quarter
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

# Create calibration plot
message("Creating calibration plot...")
calibration_data <- model_data |>
  # Group predictions into 10 bins
  mutate(
    pred_bin = cut(win_prob, breaks = seq(0, 1, 0.1), include.lowest = TRUE)
  ) |>
  # Calculate actual win rate for each bin
  group_by(pred_bin) |>
  summarize(
    n = n(),
    actual_win_rate = mean(away_win),
    pred_win_rate = mean(win_prob)
  ) |>
  # Calculate bin centers for plotting
  mutate(
    bin_center = as.numeric(pred_bin) - 0.05
  )

# Calculate Brier score
brier_score <- mean((model_data$win_prob - model_data$away_win)^2)

# Create calibration plot
p_calibration <- ggplot(
  calibration_data,
  aes(x = pred_win_rate, y = actual_win_rate)
) +
  # Add perfect calibration line
  geom_abline(intercept = 0, slope = 1, color = "white", alpha = 0.5) +
  # Add points with size based on number of predictions
  geom_point(aes(size = n), color = "#FF6B6B") +
  # Add error bars (Wilson confidence intervals)
  geom_errorbar(
    aes(
      ymin = actual_win_rate -
        1.96 * sqrt(actual_win_rate * (1 - actual_win_rate) / n),
      ymax = actual_win_rate +
        1.96 * sqrt(actual_win_rate * (1 - actual_win_rate) / n)
    ),
    width = 0.02,
    color = "#FF6B6B",
    alpha = 0.5
  ) +
  # Add labels
  scale_x_continuous(
    name = "Predicted Win Probability",
    labels = scales::percent,
    limits = c(0, 1)
  ) +
  scale_y_continuous(
    name = "Actual Win Rate",
    labels = scales::percent,
    limits = c(0, 1)
  ) +
  scale_size_continuous(
    name = "Number of Predictions",
    range = c(2, 8)
  ) +
  labs(
    title = "Model Calibration: Predicted vs Actual Win Probabilities",
    subtitle = sprintf(
      "Points show actual win rate for each prediction bin\nBrier Score: %.4f (lower is better)",
      brier_score
    )
  ) +
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  )

# Save calibration plot
ggsave(
  filename = file.path(
    "plots",
    sprintf("model_calibration_%s.png", format(Sys.time(), "%Y%m%d_%H%M%S"))
  ),
  plot = p_calibration,
  width = 10,
  height = 6,
  dpi = 300
)

# Create visualization for each game
message("Creating win probability visualizations...")
for (game in unique(model_data$game_id)) {
  game_data <- model_data |>
    filter(game_id == game)

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
      alpha = 0.2
    ) +
    # Add horizontal line at even win probability (below data representation)
    geom_hline(yintercept = 50, linetype = "solid", color = "white") +

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
    # Add win probability labels
    annotate(
      "text",
      x = -Inf,
      y = 95,
      label = "Away Team Win",
      hjust = 0,
      vjust = 1,
      color = "darkgray",
      size = 3,
      family = "InputMono"
    ) +
    annotate(
      "text",
      x = -Inf,
      y = 5,
      label = "Home Team Win",
      hjust = 0,
      vjust = 0,
      color = "darkgray",
      size = 3,
      family = "InputMono"
    ) +
    scale_y_continuous(
      name = "Point Differential",
      sec.axis = sec_axis(
        ~ . / 100,
        name = "Win Probability",
        labels = scales::percent
      )
    ) +
    coord_cartesian(
      ylim = c(
        min(game_data$point_diff),
        max(100, max(game_data$point_diff))
      )
    ) +
    scale_color_manual(
      name = "Metric",
      values = c("Win Probability" = "#FF6B6B")
    ) +
    scale_fill_manual(
      name = "Point Differential",
      values = c("TRUE" = "#4ECDC4", "FALSE" = "#FF6B6B"),
      labels = c("TRUE" = "Away Team Ahead", "FALSE" = "Home Team Ahead")
    ) +
    labs(
      title = paste0("Win Probability and Point Differential - ", game),
      x = "Play Number",
      color = "Metric"
    ) +
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    ) +
    theme(
      axis.title.y.right = element_text(
        vjust = 0,
        margin = margin(t = 0, r = 0, b = 10, l = 0)
      )
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
