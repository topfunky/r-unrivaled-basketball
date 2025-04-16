# Task 10: Calculate various basketball metrics from play-by-play
# and box score data. This script calculates free throw attempts,
# possession changes, points per possession,
# and shooting percentages for players using both
# play-by-play and box score data.
#
# Also uses WNBA stats from task11.R to compare against.

library(tidyverse)
library(feather)
library(gghighcontrast)
library(patchwork)
library(ggrepel)

# Source rendering functions
source("render_stats.R")
source("render_fg_plots.R")
source("team_colors.R")

# Define plot parameters
line_width <- 4
dot_size <- 8
label_size <- 3
chart_width <- 6
chart_width_double <- chart_width * 2
chart_height <- 4

# Define scatter plot parameters
scatter_point_size <- 6
scatter_label_size <- 2.5
scatter_quadrant_label_size <- 2
scatter_min_attempts <- 80 # Minimum attempts for showing player labels
scatter_point_color <- ubb_color
scatter_label_color <- "white"
scatter_quadrant_label_color <- "grey"
scatter_reference_line_color <- "white"
scatter_quadrant_position_factor <- 0.99 # Factor for positioning quadrant labels

# Load data
pbp_data <- read_feather("unrivaled_play_by_play.feather")
box_scores <- read_feather("unrivaled_box_scores.feather")
wnba_stats <- read_feather("fixtures/wnba_shooting_stats_2024.feather")

# Join WNBA stats with box scores
player_comparison <- box_scores |>
  group_by(player_name) |>
  summarise(
    # Box score stats
    ubb_fg_made = sum(field_goals_made, na.rm = TRUE),
    ubb_fg_attempted = sum(field_goals_attempted, na.rm = TRUE),
    ubb_fg_pct = ubb_fg_made / ubb_fg_attempted,
    ubb_pts = sum(PTS, na.rm = TRUE),
    ubb_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    ubb_ts_pct = ubb_pts / (2 * (ubb_fg_attempted + 0.44 * ubb_ft_attempted)),
    # Add three-point statistics
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    ubb_three_pt_pct = ubb_three_pt_made / ubb_three_pt_attempted,
    # Add two-point statistics
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = ubb_two_pt_made / ubb_two_pt_attempted
  ) |>
  inner_join(wnba_stats, by = "player_name") |>
  mutate(
    # Calculate true shooting percentage for WNBA stats
    wnba_ts_pct = points /
      (2 * (field_goals_attempted + 0.44 * free_throws_attempted)),
    # Calculate WNBA two-point statistics
    wnba_two_pt_made = field_goals_made - three_point_field_goals_made,
    wnba_two_pt_attempted = field_goals_attempted -
      three_point_field_goals_attempted,
    wnba_two_pt_pct = wnba_two_pt_made / wnba_two_pt_attempted
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
    ubb_fg_pct = ubb_fg_made / ubb_fg_attempted,
    # Add three-point statistics
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    ubb_three_pt_pct = ubb_three_pt_made / ubb_three_pt_attempted,
    # Add two-point statistics
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = ubb_two_pt_made / ubb_two_pt_attempted
  )

# Calculate true shooting percentage for each player (using box score data)
# TS% = PTS / (2 * (FGA + 0.44 * FTA))
# FGA includes both 2-point and 3-point attempts
player_ts_pct <- box_scores |>
  group_by(player_name) |>
  summarise(
    ubb_pts = sum(PTS, na.rm = TRUE),
    ubb_fg_made = sum(field_goals_made, na.rm = TRUE),
    ubb_fg_attempted = sum(field_goals_attempted, na.rm = TRUE), # Already includes 2pt and 3pt attempts
    ubb_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    ubb_ts_pct = ubb_pts / (2 * (ubb_fg_attempted + 0.44 * ubb_ft_attempted)),
    # Add three-point statistics
    ubb_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    ubb_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    ubb_three_pt_pct = ubb_three_pt_made / ubb_three_pt_attempted,
    # Add two-point statistics
    ubb_two_pt_made = ubb_fg_made - ubb_three_pt_made,
    ubb_two_pt_attempted = ubb_fg_attempted - ubb_three_pt_attempted,
    ubb_two_pt_pct = ubb_two_pt_made / ubb_two_pt_attempted
  )

# Render density plots
render_fg_density_plot(
  player_fg_pct,
  player_comparison,
  chart_width,
  chart_height
)

two_pt_plot <- render_two_pt_density_plot(
  player_fg_pct,
  player_comparison,
  chart_width,
  chart_height
)

three_pt_plot <- render_three_pt_density_plot(
  player_fg_pct,
  player_comparison,
  chart_width,
  chart_height
)

# Render combined shooting plot
render_combined_shooting_plot(
  two_pt_plot,
  three_pt_plot,
  chart_width_double,
  chart_height
)

# Render TS density plot
render_ts_density_plot(
  player_ts_pct,
  player_comparison,
  chart_width,
  chart_height
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
  file_path = "plots/two_pt_barbell_positive.png",
  chart_width = chart_width,
  chart_height = chart_height
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
  file_path = "plots/two_pt_barbell_negative.png",
  chart_width = chart_width,
  chart_height = chart_height
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
  # Filter out players with too few attempts to be meaningful
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
  file_path = "plots/shooting_improvement_scatter.png",
  chart_width = chart_width,
  chart_height = chart_height,
  scatter_point_size = scatter_point_size,
  scatter_label_size = scatter_label_size,
  scatter_min_attempts = scatter_min_attempts,
  scatter_point_color = scatter_point_color,
  scatter_label_color = scatter_label_color,
  scatter_quadrant_label_color = scatter_quadrant_label_color,
  scatter_quadrant_label_size = scatter_quadrant_label_size,
  scatter_reference_line_color = scatter_reference_line_color,
  scatter_quadrant_position_factor = scatter_quadrant_position_factor,
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
  file_path = "plots/relative_shooting_improvement_scatter.png",
  chart_width = chart_width,
  chart_height = chart_height,
  scatter_point_size = scatter_point_size,
  scatter_label_size = scatter_label_size,
  scatter_min_attempts = scatter_min_attempts,
  scatter_point_color = scatter_point_color,
  scatter_label_color = scatter_label_color,
  scatter_quadrant_label_color = scatter_quadrant_label_color,
  scatter_quadrant_label_size = scatter_quadrant_label_size,
  scatter_reference_line_color = scatter_reference_line_color,
  scatter_quadrant_position_factor = scatter_quadrant_position_factor
)

# Calculate data for FGA histogram
player_fga <- player_fg_pct |>
  mutate(
    total_fga = ubb_fg_attempted
  ) |>
  arrange(desc(total_fga))

# Render FGA histogram
render_fga_histogram(player_fga, chart_width, chart_height)

# Prepare data for markdown tables (These remain here as they are data prep)
top_fga_table <- player_fga |>
  select(player_name, total_fga, ubb_fg_made, ubb_fg_attempted, ubb_fg_pct) |>
  head(10) |>
  mutate(
    ubb_fg_pct = sprintf("%.1f%%", ubb_fg_pct * 100)
  ) |>
  rename(
    "Player" = player_name,
    "FGA" = total_fga,
    "FGM" = ubb_fg_made,
    "FGA Total" = ubb_fg_attempted,
    "FG%" = ubb_fg_pct
  )

# Create a Markdown table for two_pt_diff_data
cat("\n### Two-Point Shooting Percentage Differences (Top 10 Improvements)\n")
cat("| Player | UBB 2P% | WNBA 2P% | Difference | UBB 2PA |\n")
cat("|--------|---------------|----------|------------|---------------|\n")
two_pt_diff_data |>
  select(
    player_name,
    ubb_two_pt_pct,
    wnba_two_pt_pct,
    two_pt_diff,
    ubb_two_pt_attempted
  ) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.0f%% | %.0f%% | %+.0f%% | %d |\n",
          x$player_name[i],
          x$ubb_two_pt_pct[i] * 100,
          x$wnba_two_pt_pct[i] * 100,
          x$two_pt_diff[i],
          x$ubb_two_pt_attempted[i]
        ))
      }
    }
  }()

# Calculate and display a Markdown table with each player's percentage of 2pt shots vs 3pt shots taken in Unrivaled vs WNBA
cat("\n### Shot Distribution: 2-Point vs 3-Point Attempts\n")
cat(
  "| Player | UBB 2P% | UBB 3P% | WNBA 2P% | WNBA 3P% | UBB 2PA | UBB 3PA | WNBA 2PA | WNBA 3PA |\n"
)
cat(
  "|--------|---------|---------|----------|----------|---------|---------|----------|----------|\n"
)

player_comparison |>
  filter(ubb_fg_attempted >= 10) |> # Filter players with at least 10 field goal attempts
  mutate(
    # Calculate percentages of 2pt and 3pt attempts
    ubb_2pt_pct = ubb_two_pt_attempted / ubb_fg_attempted,
    ubb_3pt_pct = ubb_three_pt_attempted / ubb_fg_attempted,
    wnba_2pt_pct = wnba_two_pt_attempted / field_goals_attempted,
    wnba_3pt_pct = three_point_field_goals_attempted / field_goals_attempted
  ) |>
  arrange(desc(ubb_fg_attempted)) |> # Sort by most field goal attempts
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %d | %d | %d | %d |\n",
          x$player_name[i],
          x$ubb_2pt_pct[i] * 100,
          x$ubb_3pt_pct[i] * 100,
          x$wnba_2pt_pct[i] * 100,
          x$wnba_3pt_pct[i] * 100,
          x$ubb_two_pt_attempted[i],
          x$ubb_three_pt_attempted[i],
          x$wnba_two_pt_attempted[i],
          x$three_point_field_goals_attempted[i]
        ))
      }
    }
  }()

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
render_all_stats("plots/player_stats.md", stats)
