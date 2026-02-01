# Purpose: Creates separate win probability models for quarters 1-3 and
# quarter 4 using XGBoost and visualizes them with ggplot.

# Load required libraries
library(tidyverse)
library(xgboost)
library(feather)
library(gghighcontrast)
library(fs)

# Get season from command line argument or default to 2026
args <- commandArgs(trailingOnly = TRUE)
season_year <- if (length(args) > 0) as.numeric(args[1]) else 2026

message(sprintf("Processing season %d...", season_year))

# Create plots directory if it doesn't exist
plots_dir <- file.path("plots", season_year)
message(sprintf("Creating plots directory if it doesn't exist: %s", plots_dir))
dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(
  file.path(plots_dir, "train"),
  showWarnings = FALSE,
  recursive = TRUE
)
dir.create(file.path(plots_dir, "test"), showWarnings = FALSE, recursive = TRUE)

# Source calibration functions
source("R/calibration.R")
# Source visualization functions
source("R/render_wp_plots.R")

# Read play by play data from season-specific directory
message(sprintf("Reading play by play data for season %d...", season_year))
play_by_play_file <- path("data", season_year, "unrivaled_play_by_play.csv")
if (!file_exists(play_by_play_file)) {
  stop(sprintf("Play by play file not found: %s", play_by_play_file))
}
play_by_play <- read_csv(play_by_play_file)

# Read ELO rankings data from season-specific directory (if it exists)
elo_rankings_file <- path("data", season_year, "unrivaled_elo_rankings.csv")
if (file_exists(elo_rankings_file)) {
  message(sprintf("Reading ELO rankings for season %d...", season_year))
  elo_rankings <- read_csv(elo_rankings_file) |>
    select(game_id, home_team_elo_prev, away_team_elo_prev) |>
    distinct()
} else {
  message(sprintf(
    "ELO rankings file not found for season %d, using NA values",
    season_year
  ))
  elo_rankings <- play_by_play |>
    select(game_id) |>
    distinct() |>
    mutate(
      home_team_elo_prev = NA_real_,
      away_team_elo_prev = NA_real_
    )
}

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
      (minute * 60 * quarter + second),
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

# Write full play by play with extra fields to season-specific directory
data_dir <- path("data", season_year)
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)
enhanced_file <- path(data_dir, "unrivaled_play_by_play_enhanced.csv")
message(sprintf("Writing enhanced play by play data to %s...", enhanced_file))
write_csv(model_data, enhanced_file)
write_feather(
  model_data,
  path(data_dir, "unrivaled_play_by_play_enhanced.feather")
)

# Split data into quarters 1-3 and quarter 4
message("Splitting data into quarters 1-3 and quarter 4...")
data_q1q3 <- model_data |>
  filter(quarter <= 3)

data_q4 <- model_data |>
  filter(quarter == 4)

# Split data into training and testing sets
message("Splitting data into training and testing sets...")
# Set seed for reproducibility
set.seed(5150)

# Get unique game IDs
unique_games <- unique(model_data$game_id)

# Split games into training (80%) and testing (20%) sets
train_game_ids <- sample(unique_games, size = floor(0.8 * length(unique_games)))
test_game_ids <- setdiff(unique_games, train_game_ids)

# Split Q1-Q3 data
data_q1q3_train <- data_q1q3 |>
  filter(game_id %in% train_game_ids)

data_q1q3_test <- data_q1q3 |>
  filter(game_id %in% test_game_ids)

# Split Q4 data
data_q4_train <- data_q4 |>
  filter(game_id %in% train_game_ids)

data_q4_test <- data_q4 |>
  filter(game_id %in% test_game_ids)

# Prepare training data for quarters 1-3
message("Preparing training data for quarters 1-3...")
X_q1q3_train <- data_q1q3_train |>
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

y_q1q3_train <- data_q1q3_train$away_win

# Prepare testing data for quarters 1-3
X_q1q3_test <- data_q1q3_test |>
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

y_q1q3_test <- data_q1q3_test$away_win

# Prepare training data for quarter 4
message("Preparing training data for quarter 4...")
X_q4_train <- data_q4_train |>
  select(
    quarter,
    point_diff,
    away_points_needed,
    home_points_needed,
    estimated_plays_remaining,
    elo_diff
  ) |>
  as.matrix()

y_q4_train <- data_q4_train$away_win

# Prepare testing data for quarter 4
X_q4_test <- data_q4_test |>
  select(
    quarter,
    point_diff,
    away_points_needed,
    home_points_needed,
    estimated_plays_remaining,
    elo_diff
  ) |>
  as.matrix()

y_q4_test <- data_q4_test$away_win

# Train XGBoost model for quarters 1-3
message("Training XGBoost model for quarters 1-3...")
model_q1q3 <- xgboost(
  data = X_q1q3_train,
  label = y_q1q3_train,
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
  data = X_q4_train,
  label = y_q4_train,
  nrounds = 100,
  objective = "binary:logistic",
  eval_metric = "logloss",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8
)

# Generate predictions for training data (quarters 1-3)
message(
  "Generating win probability predictions for training data (quarters 1-3)..."
)
data_q1q3_train$win_prob <- predict(model_q1q3, X_q1q3_train)

# Generate predictions for testing data (quarters 1-3)
message(
  "Generating win probability predictions for testing data (quarters 1-3)..."
)
data_q1q3_test$win_prob <- predict(model_q1q3, X_q1q3_test)

# Generate predictions for training data (quarter 4)
message(
  "Generating win probability predictions for training data (quarter 4)..."
)
data_q4_train$win_prob <- predict(model_q4, X_q4_train)

# Generate predictions for testing data (quarter 4)
message(
  "Generating win probability predictions for testing data (quarter 4)..."
)
data_q4_test$win_prob <- predict(model_q4, X_q4_test)

# Combine the predictions for training data
message("Combining predictions for training data...")
model_data_train <- bind_rows(data_q1q3_train, data_q4_train) |>
  arrange(game_id, play_count)

# Combine the predictions for testing data
message("Combining predictions for testing data...")
model_data_test <- bind_rows(data_q1q3_test, data_q4_test) |>
  arrange(game_id, play_count)

# Save the data with win probabilities
message("Saving data with win probabilities...")
write_feather(model_data_train, "unrivaled_play_by_play_wp_train.feather")
write_feather(model_data_test, "unrivaled_play_by_play_wp_test.feather")

# Create calibration plots
message("Creating calibration plots...")
p_calibration_train <- create_calibration_plot(
  model_data_train,
  "Training Data"
)
p_calibration_test <- create_calibration_plot(model_data_test, "Testing Data")

# Save calibration plots
ggsave(
  file.path(plots_dir, "calibration_train.png"),
  p_calibration_train,
  width = 10,
  height = 6,
  dpi = 300
)
ggsave(
  file.path(plots_dir, "calibration_test.png"),
  p_calibration_test,
  width = 10,
  height = 6,
  dpi = 300
)

# Generate win probability visualizations for training games
generate_win_probability_plots(
  model_data_train,
  output_dir = file.path(plots_dir, "train")
)

# Generate win probability visualizations for testing games
generate_win_probability_plots(
  model_data_test,
  output_dir = file.path(plots_dir, "test")
)

# Calculate and print model performance metrics
message("Calculating model performance metrics...")

# Function to calculate metrics
calculate_metrics <- function(data, model_name) {
  # Calculate log loss
  log_loss <- -mean(
    data$away_win *
      log(data$win_prob) +
      (1 - data$away_win) * log(1 - data$win_prob)
  )

  # Calculate accuracy (using 0.5 as threshold)
  accuracy <- mean((data$win_prob > 0.5) == data$away_win)

  # Calculate AUC
  # For simplicity, we'll use a basic implementation
  # In practice, you might want to use a package like pROC
  n_pos <- sum(data$away_win == 1)
  n_neg <- sum(data$away_win == 0)

  # Sort by probability
  sorted_data <- data[order(data$win_prob, decreasing = TRUE), ]

  # Calculate TPR and FPR at each threshold
  tpr <- cumsum(sorted_data$away_win == 1) / n_pos
  fpr <- cumsum(sorted_data$away_win == 0) / n_neg

  # Calculate AUC using trapezoidal rule
  auc <- sum(diff(fpr) * (tpr[-1] + tpr[-length(tpr)]) / 2)

  # Print metrics
  message(sprintf("%s Model Metrics:", model_name))
  message(sprintf("  Log Loss: %.4f", log_loss))
  message(sprintf("  Accuracy: %.4f", accuracy))
  message(sprintf("  AUC: %.4f", auc))

  return(list(
    log_loss = log_loss,
    accuracy = accuracy,
    auc = auc
  ))
}

# Calculate metrics for Q1-Q3 model
q1q3_train_metrics <- calculate_metrics(data_q1q3_train, "Q1-Q3 Training")
q1q3_test_metrics <- calculate_metrics(data_q1q3_test, "Q1-Q3 Testing")

# Calculate metrics for Q4 model
q4_train_metrics <- calculate_metrics(data_q4_train, "Q4 Training")
q4_test_metrics <- calculate_metrics(data_q4_test, "Q4 Testing")

message("All processing complete!")
