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


# Load data
pbp_data <- read_feather("unrivaled_play_by_play.feather")
box_scores <- read_feather("unrivaled_box_scores.feather")
wnba_stats <- read_feather("fixtures/wnba_shooting_stats_2024.feather")

# Join WNBA stats with box scores
player_comparison <- box_scores |>
  group_by(player_name) |>
  summarise(
    # Box score stats
    unrvld_fg_made = sum(field_goals_made, na.rm = TRUE),
    unrvld_fg_attempted = sum(field_goals_attempted, na.rm = TRUE),
    unrvld_fg_pct = unrvld_fg_made / unrvld_fg_attempted,
    unrvld_pts = sum(PTS, na.rm = TRUE),
    unrvld_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    unrvld_ts_pct = unrvld_pts /
      (2 * (unrvld_fg_attempted + 0.44 * unrvld_ft_attempted)),
    # Add three-point statistics
    unrvld_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    unrvld_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    unrvld_three_pt_pct = unrvld_three_pt_made / unrvld_three_pt_attempted
  ) |>
  inner_join(wnba_stats, by = "player_name") |>
  mutate(
    # Calculate true shooting percentage for WNBA stats
    wnba_ts_pct = points /
      (2 * (field_goals_attempted + 0.44 * free_throws_attempted))
  ) |>
  select(
    player_name,
    team,
    # Box score stats
    unrvld_fg_made,
    unrvld_fg_attempted,
    unrvld_fg_pct,
    unrvld_pts,
    unrvld_ft_attempted,
    unrvld_ts_pct,
    unrvld_three_pt_made,
    unrvld_three_pt_attempted,
    unrvld_three_pt_pct,
    # WNBA stats
    field_goals_made,
    field_goals_attempted,
    field_goal_pct,
    points,
    free_throws_attempted,
    three_point_field_goals_made,
    three_point_field_goals_attempted,
    three_point_pct,
    wnba_ts_pct
  ) |>
  arrange(desc(unrvld_pts))

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
    unrvld_fg_made = sum(field_goals_made, na.rm = TRUE),
    unrvld_fg_attempted = sum(field_goals_attempted, na.rm = TRUE),
    unrvld_fg_pct = unrvld_fg_made / unrvld_fg_attempted,
    # Add three-point statistics
    unrvld_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    unrvld_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    unrvld_three_pt_pct = unrvld_three_pt_made / unrvld_three_pt_attempted
  )

# Calculate true shooting percentage for each player (using box score data)
# TS% = PTS / (2 * (FGA + 0.44 * FTA))
# FGA includes both 2-point and 3-point attempts
player_ts_pct <- box_scores |>
  group_by(player_name) |>
  summarise(
    unrvld_pts = sum(PTS, na.rm = TRUE),
    unrvld_fg_attempted = sum(field_goals_attempted, na.rm = TRUE), # Already includes 2pt and 3pt attempts
    unrvld_ft_attempted = sum(free_throws_attempted, na.rm = TRUE),
    unrvld_ts_pct = unrvld_pts /
      (2 * (unrvld_fg_attempted + 0.44 * unrvld_ft_attempted)),
    # Add three-point statistics
    unrvld_three_pt_made = sum(three_point_field_goals_made, na.rm = TRUE),
    unrvld_three_pt_attempted = sum(
      three_point_field_goals_attempted,
      na.rm = TRUE
    ),
    unrvld_three_pt_pct = unrvld_three_pt_made / unrvld_three_pt_attempted
  )

# Create and save density plots with InputMono font
fg_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct,
    aes(x = unrvld_fg_pct, fill = "Unrivaled"),
    alpha = 0.7,
    color = NA
  ) +
  geom_density(
    data = player_comparison,
    aes(x = field_goal_pct, fill = "WNBA"),
    alpha = 0.7,
    color = NA
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Unrivaled" = "#6A0DAD", "WNBA" = "#FF8C00")
  ) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Distribution of Field Goal Percentages",
    x = "Field Goal Percentage",
    y = "Density"
  )

ggsave(
  "plots/fg_density.png",
  plot = fg_density_plot,
  width = 8,
  height = 6,
  dpi = 300
)

# Create three-point percentage density plot
three_pt_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct,
    aes(x = unrvld_three_pt_pct, fill = "Unrivaled"),
    alpha = 0.7,
    color = NA
  ) +
  geom_density(
    data = player_comparison,
    aes(x = three_point_pct, fill = "WNBA"),
    alpha = 0.7,
    color = NA
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Unrivaled" = "#6A0DAD", "WNBA" = "#FF8C00")
  ) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Distribution of Three-Point Percentages",
    x = "Three-Point Percentage",
    y = "Density"
  )

ggsave(
  "plots/three_pt_density.png",
  plot = three_pt_density_plot,
  width = 8,
  height = 6,
  dpi = 300
)

ts_density_plot <- ggplot() +
  geom_density(
    data = player_ts_pct,
    aes(x = unrvld_ts_pct, fill = "Unrivaled"),
    alpha = 0.7,
    color = NA
  ) +
  geom_density(
    data = player_comparison,
    aes(x = wnba_ts_pct, fill = "WNBA"),
    alpha = 0.7,
    color = NA
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Unrivaled" = "#6A0DAD", "WNBA" = "#FF8C00")
  ) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Distribution of True Shooting Percentages",
    x = "True Shooting Percentage",
    y = "Density"
  )

ggsave(
  "plots/ts_density.png",
  plot = ts_density_plot,
  width = 8,
  height = 6,
  dpi = 300
)

# Write results to markdown file
sink("plots/player_stats.md")

cat("# Basketball Metrics Summary\n\n")

cat("## Free Throw Statistics\n")
cat("- Total Free Throw Attempts:", total_ft_attempts, "\n\n")

cat("## Points Per Possession\n")
cat(
  "- Total Points:",
  round(points_per_possession$total_points, 0),
  "\n"
)
cat(
  "- Total Possessions:",
  round(points_per_possession$total_possessions, 0),
  "\n"
)
cat(
  "- Average Points per Game:",
  round(points_per_possession$avg_points, 1),
  "\n"
)
cat(
  "- Average Possessions per Game:",
  round(points_per_possession$avg_possessions, 1),
  "\n"
)
cat(
  "- Average Points per Possession:",
  round(points_per_possession$points_per_possession, 3),
  "\n\n"
)

cat("## Player Shooting Statistics\n")

cat("### Player Comparison: Unrivaled vs WNBA Stats\n")
cat(
  "| Player | Team | Unrivaled FG% | WNBA FG% | Unrivaled 3P% | WNBA 3P% | Unrivaled TS% | Unrivaled PTS | WNBA PTS |\n"
)
cat(
  "|--------|------|---------------|----------|---------------|----------|---------------|---------------|----------|\n"
)
player_comparison |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %s | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %d | %d |\n",
          x$player_name[i],
          x$team[i],
          x$unrvld_fg_pct[i] * 100,
          x$field_goal_pct[i] * 100,
          x$unrvld_three_pt_pct[i] * 100,
          x$three_point_pct[i] * 100,
          x$unrvld_ts_pct[i] * 100,
          x$unrvld_pts[i],
          x$points[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
cat("| Player | FG% | FGM/FGA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(unrvld_fg_attempted >= 10) |>
  arrange(desc(unrvld_fg_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$unrvld_fg_pct[i] * 100,
          x$unrvld_fg_made[i],
          x$unrvld_fg_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Three-Point Percentage (minimum 5 attempts)\n")
cat("| Player | 3P% | 3PM/3PA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(unrvld_three_pt_attempted >= 5) |>
  arrange(desc(unrvld_three_pt_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$unrvld_three_pt_pct[i] * 100,
          x$unrvld_three_pt_made[i],
          x$unrvld_three_pt_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n")
cat("| Player | TS% | PTS | FGA | FTA |\n")
cat("|--------|-----|-----|-----|-----|\n")
player_ts_pct |>
  filter(unrvld_fg_attempted >= 10) |>
  arrange(desc(unrvld_ts_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d | %d | %d |\n",
          x$player_name[i],
          x$unrvld_ts_pct[i] * 100,
          x$unrvld_pts[i],
          x$unrvld_fg_attempted[i],
          x$unrvld_ft_attempted[i]
        ))
      }
    }
  }()

sink()
