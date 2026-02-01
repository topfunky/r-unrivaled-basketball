# Calculate various basketball metrics from play-by-play
# and box score data. This script calculates free throw attempts,
# possession changes, points per possession,
# and shooting percentages for players using both
# play-by-play and box score data.
#
# Also uses WNBA stats from fetch_wnba_stats.R to compare against.

library(tidyverse)
library(feather)
library(gghighcontrast)
library(patchwork)
library(ggrepel)
library(knitr)

# Source rendering functions
# team_colors.R must be sourced first as render_fg_plots.R depends on it
source("R/team_colors.R")
source("R/render_stats.R")
source("R/render_fg_plots.R")

# Get season from command line argument or default to 2026
args <- commandArgs(trailingOnly = TRUE)
season_year <- if (length(args) > 0) as.numeric(args[1]) else 2026

message(sprintf("Processing season %d...", season_year))

# Create plots directory if it doesn't exist
plots_dir <- file.path("plots", season_year)
dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

# Load data from season-specific directory
data_dir <- file.path("data", season_year)
pbp_data <- read_feather(file.path(data_dir, "unrivaled_play_by_play.feather"))
box_scores <- read_feather(file.path(data_dir, "unrivaled_box_scores.feather"))
wnba_stats <- read_feather("data/wnba_shooting_stats_2025.feather")

# Join WNBA stats with box scores
player_comparison <- box_scores |>
  group_by(player_name) |>
  summarise(
    ubb_fg_made = sum(field_goals_made, na.rm = TRUE),
    ubb_fg_attempted = sum(field_goals_attempted, na.rm = TRUE),
    ubb_pts = sum(PTS, na.rm = TRUE),
    ubb_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) |>
  # Calculate derived stats safely
  mutate(
    ubb_fg_pct = if_else(
      ubb_fg_attempted > 0,
      ubb_fg_made / ubb_fg_attempted,
      NA_real_
    ),
    ubb_ts_denominator = 2 * (ubb_fg_attempted + 0.44 * ubb_ft_attempted),
    ubb_ts_pct = if_else(
      ubb_ts_denominator > 0,
      ubb_pts / ubb_ts_denominator,
      NA_real_
    ),
    ubb_three_pt_pct = if_else(
      ubb_three_pt_attempted > 0,
      ubb_three_pt_made / ubb_three_pt_attempted,
      NA_real_
    ),
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = if_else(
      ubb_two_pt_attempted > 0,
      ubb_two_pt_made / ubb_two_pt_attempted,
      NA_real_
    )
  ) |>
  inner_join(wnba_stats, by = "player_name") |>
  mutate(
    # Calculate true shooting percentage for WNBA stats safely
    wnba_ts_denominator = 2 *
      (field_goals_attempted + 0.44 * free_throws_attempted),
    wnba_ts_pct = if_else(
      wnba_ts_denominator > 0,
      points / wnba_ts_denominator,
      NA_real_
    ),
    # Calculate WNBA two-point statistics safely
    wnba_two_pt_made = field_goals_made - three_point_field_goals_made,
    wnba_two_pt_attempted = field_goals_attempted -
      three_point_field_goals_attempted,
    wnba_two_pt_pct = if_else(
      wnba_two_pt_attempted > 0,
      wnba_two_pt_made / wnba_two_pt_attempted,
      NA_real_
    )
  ) |>
  select(
    player_name,
    team,
    # Box score stats
    ubb_fg_made,
    ubb_fg_attempted,
    ubb_fg_pct,
    ubb_pts,
    ubb_ft_attempted,
    ubb_ts_pct,
    ubb_three_pt_made,
    ubb_three_pt_attempted,
    ubb_three_pt_pct,
    ubb_two_pt_made,
    ubb_two_pt_attempted,
    ubb_two_pt_pct,
    # WNBA stats
    field_goals_made,
    field_goals_attempted,
    field_goal_pct,
    points,
    free_throws_attempted,
    three_point_field_goals_made,
    three_point_field_goals_attempted,
    three_point_pct,
    wnba_ts_pct,
    wnba_two_pt_made,
    wnba_two_pt_attempted,
    wnba_two_pt_pct
  ) |>
  arrange(desc(ubb_pts))

# Count total free throw attempts (using box score data for accuracy)
total_ft_attempts <- box_scores |>
  summarise(
    total_fta = sum(free_throws_attempted, na.rm = TRUE)
  ) |>
  pull(total_fta)

# Calculate average points per possession using pos_team column
# A possession ends when the team with the ball changes
points_per_possession <- pbp_data |>
  group_by(game_id) |>
  mutate(
    # Calculate points scored on this possession
    points_scored = case_when(
      # Home team scores
      pos_team == lead(pos_team, default = first(pos_team)) &
        home_score > lag(home_score, default = first(home_score)) ~
        home_score - lag(home_score, default = first(home_score)),
      # Away team scores
      pos_team == lead(pos_team, default = first(pos_team)) &
        away_score > lag(away_score, default = first(away_score)) ~
        away_score - lag(away_score, default = first(away_score)),
      TRUE ~ 0
    ),
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
    total_points = sum(total_points),
    total_possessions = sum(total_possessions),
    avg_points = mean(total_points),
    avg_possessions = mean(total_possessions),
    points_per_possession = total_points / total_possessions
  )

# Calculate field goal percentage for each player (using box score data)
player_fg_pct <- box_scores |>
  group_by(player_name) |>
  summarise(
    ubb_fg_made = sum(field_goals_made, na.rm = TRUE),
    ubb_fg_attempted = sum(field_goals_attempted, na.rm = TRUE),
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) |>
  mutate(
    ubb_fg_pct = if_else(
      ubb_fg_attempted > 0,
      ubb_fg_made / ubb_fg_attempted,
      NA_real_
    ),
    ubb_three_pt_pct = if_else(
      ubb_three_pt_attempted > 0,
      ubb_three_pt_made / ubb_three_pt_attempted,
      NA_real_
    ),
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = if_else(
      ubb_two_pt_attempted > 0,
      ubb_two_pt_made / ubb_two_pt_attempted,
      NA_real_
    )
  ) |>
  # Filter out players with no attempts for density plots if needed
  filter(ubb_fg_attempted > 0)

# Calculate true shooting percentage for each player (using box score data)
# TS% = PTS / (2 * (FGA + 0.44 * FTA))
player_ts_pct <- box_scores |>
  group_by(player_name) |>
  summarise(
    ubb_pts = sum(PTS, na.rm = TRUE),
    ubb_fg_made = sum(field_goals_made, na.rm = TRUE),
    ubb_fg_attempted = sum(field_goals_attempted, na.rm = TRUE), # Already includes 2pt and 3pt attempts
    ubb_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    # Also summarize 3pt stats here needed for later mutate
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) |>
  mutate(
    ubb_ts_denominator = 2 * (ubb_fg_attempted + 0.44 * ubb_ft_attempted),
    ubb_ts_pct = if_else(
      ubb_ts_denominator > 0,
      ubb_pts / ubb_ts_denominator,
      NA_real_
    ),
    # Calculate three-point statistics safely using summarized values
    ubb_three_pt_pct = if_else(
      ubb_three_pt_attempted > 0,
      ubb_three_pt_made / ubb_three_pt_attempted,
      NA_real_
    ),
    # Calculate two-point statistics safely using summarized values
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = if_else(
      ubb_two_pt_attempted > 0,
      ubb_two_pt_made / ubb_two_pt_attempted,
      NA_real_
    )
  ) |>
  # Filter out players with no attempts/denominator for density plots
  filter(ubb_ts_denominator > 0)

# Render density plots
render_fg_density_plot(
  player_fg_pct,
  player_comparison,
  output_dir = plots_dir
)

two_pt_plot <- render_two_pt_density_plot(
  player_fg_pct,
  player_comparison,
  output_dir = plots_dir
)

three_pt_plot <- render_three_pt_density_plot(
  player_fg_pct,
  player_comparison,
  output_dir = plots_dir
)

# Render combined shooting plot
render_combined_shooting_plot(
  two_pt_plot,
  three_pt_plot,
  output_dir = plots_dir
)

# Render TS density plot
render_ts_density_plot(
  player_ts_pct,
  player_comparison,
  output_dir = plots_dir
)


# Create data for barbell plots

# Get top 10 players with biggest improvement in 2P%
two_pt_diff_data <- player_comparison |>
  filter(ubb_two_pt_attempted >= 40) |> # Filter by shot attempts
  mutate(
    two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100
  ) |>
  arrange(desc(two_pt_diff)) |>
  head(10) |>
  arrange(desc(ubb_two_pt_pct))

# Get top 10 players with biggest decrease in 2P%
two_pt_negative_diff_data <- player_comparison |>
  filter(ubb_two_pt_attempted >= 40) |> # Filter by shot attempts
  mutate(
    two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100
  ) |>
  arrange(two_pt_diff) |>
  head(10) |>
  arrange(desc(ubb_two_pt_pct))

# Render barbell plots
render_barbell_plot(
  data = two_pt_diff_data,
  y_var = player_name,
  x1_var = wnba_two_pt_pct * 100,
  x2_var = ubb_two_pt_pct * 100,
  x1_label = "WNBA",
  x2_label = "Unrivaled",
  title = "Two-Point Shooting Percentage: WNBA vs Unrivaled",
  subtitle = "Players with biggest improvement in Unrivaled (purple)",
  file_path = file.path(plots_dir, "two_pt_barbell_positive.png")
)

render_barbell_plot(
  data = two_pt_negative_diff_data,
  y_var = player_name,
  x1_var = wnba_two_pt_pct * 100,
  x2_var = ubb_two_pt_pct * 100,
  x1_label = "WNBA",
  x2_label = "Unrivaled",
  title = "Two-Point Shooting Percentage: WNBA vs Unrivaled",
  subtitle = "Players with biggest decrease in Unrivaled (purple)",
  file_path = file.path(plots_dir, "two_pt_barbell_negative.png")
)

# Calculate shooting improvement data
shooting_improvement <- player_comparison |>
  mutate(
    # Calculate percentage point improvements (in percentage points)
    two_pt_improvement = (ubb_two_pt_pct - wnba_two_pt_pct) * 100,
    three_pt_improvement = (ubb_three_pt_pct - three_point_pct) * 100,
    # Calculate relative improvements (as percentages)
    two_pt_relative_improvement = (ubb_two_pt_pct / wnba_two_pt_pct - 1) * 100,
    three_pt_relative_improvement = (ubb_three_pt_pct / three_point_pct - 1) *
      100
  ) |>
  # Replace Inf generated by division by zero (e.g., WNBA pct = 0) with NA
  mutate(
    two_pt_relative_improvement = if_else(
      is.infinite(two_pt_relative_improvement),
      NA_real_,
      two_pt_relative_improvement
    ),
    three_pt_relative_improvement = if_else(
      is.infinite(three_pt_relative_improvement),
      NA_real_,
      three_pt_relative_improvement
    )
  ) |>
  # Filter out players with too few attempts or NA/NaN/Inf values
  filter(
    ubb_two_pt_attempted >= 20,
    ubb_three_pt_attempted >= 10
  )

# Render scatter plots
render_improvement_scatter(
  shooting_improvement = shooting_improvement,
  x_var = two_pt_improvement,
  y_var = three_pt_improvement,
  x_lab = "2P (percentage points)",
  y_lab = "3P (percentage points)",
  title = "Shooting Improvement: Unrivaled vs WNBA",
  subtitle = "Comparing 2P and 3P shooting",
  file_path = file.path(plots_dir, "shooting_improvement_scatter.png"),
  add_trendline = TRUE
)

render_improvement_scatter(
  shooting_improvement = shooting_improvement,
  x_var = two_pt_relative_improvement,
  y_var = three_pt_relative_improvement,
  x_lab = "2-Point Shooting Improvement (%)",
  y_lab = "3-Point Shooting Improvement (%)",
  title = "Relative Shooting Improvement: Unrivaled vs WNBA",
  subtitle = "Comparing relative improvements in 2-point and 3-point shooting",
  file_path = file.path(plots_dir, "relative_shooting_improvement_scatter.png")
)

# Calculate data for FGA histogram
player_fga <- player_fg_pct |>
  mutate(
    total_fga = ubb_fg_attempted
  ) |>
  arrange(desc(total_fga))

# Render FGA histogram
render_fga_histogram(player_fga, output_dir = plots_dir)

# Create a list of all statistics for rendering
stats <- list(
  total_ft_attempts = total_ft_attempts,
  points_per_possession = points_per_possession,
  player_comparison = player_comparison,
  shooting_improvement = shooting_improvement,
  player_fg_pct = player_fg_pct,
  player_ts_pct = player_ts_pct
)

# Render all statistics to markdown file
render_all_stats(file.path(plots_dir, "player_stats.md"), stats)
