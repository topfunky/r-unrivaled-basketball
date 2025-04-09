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
    box_fg_made = sum(fg, na.rm = TRUE),
    box_fg_attempted = sum(fg_attempts, na.rm = TRUE),
    box_fg_pct = box_fg_made / box_fg_attempted,
    box_pts = sum(PTS, na.rm = TRUE),
    box_ft_attempted = sum(ft_attempts, na.rm = TRUE),
    box_ts_pct = box_pts / (2 * (box_fg_attempted + 0.44 * box_ft_attempted))
  ) |>
  inner_join(wnba_stats, by = "player_name") |>
  mutate(
    # Calculate true shooting percentage for WNBA stats
    wnba_ts_pct = points / (2 * (fg_attempted + 0.44 * ft_attempted))
  ) |>
  select(
    player_name,
    team,
    # Box score stats
    box_fg_made,
    box_fg_attempted,
    box_fg_pct,
    box_pts,
    box_ft_attempted,
    box_ts_pct,
    # WNBA stats
    fg_made,
    fg_attempted,
    fg_pct,
    points,
    ft_attempted,
    fg3_made,
    fg3_attempted,
    fg3_pct,
    wnba_ts_pct
  ) |>
  arrange(desc(box_pts))

# Count total free throw attempts (using box score data for accuracy)
total_ft_attempts <- box_scores |>
  summarise(
    total_fta = sum(ft_attempts, na.rm = TRUE)
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
    fg_made = sum(fg, na.rm = TRUE),
    fg_attempted = sum(fg_attempts, na.rm = TRUE),
    fg_pct = fg_made / fg_attempted
  )

# Calculate true shooting percentage for each player (using box score data)
# TS% = PTS / (2 * (FGA + 0.44 * FTA))
# FGA includes both 2-point and 3-point attempts
#
# TODO: Needs to use 3-point attempts from pbp_data
player_ts_pct <- box_scores |>
  group_by(player_name) |>
  summarise(
    points = sum(PTS, na.rm = TRUE),
    fg_attempted = sum(fg_attempts, na.rm = TRUE), # Already includes 2pt and 3pt attempts
    ft_attempted = sum(ft_attempts, na.rm = TRUE),
    ts_pct = points / (2 * (fg_attempted + 0.44 * ft_attempted))
  )

# Create and save density plots with InputMono font
fg_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct,
    aes(x = fg_pct, fill = "Box Scores"),
    alpha = 0.3
  ) +
  geom_density(
    data = player_comparison,
    aes(x = fg_pct, fill = "WNBA Stats"),
    alpha = 0.3
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Box Scores" = "#0077CC", "WNBA Stats" = "#CC7700")
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

ts_density_plot <- ggplot() +
  geom_density(
    data = player_ts_pct,
    aes(x = ts_pct, fill = "Box Scores"),
    alpha = 0.3
  ) +
  geom_density(
    data = player_comparison,
    aes(x = wnba_ts_pct, fill = "WNBA Stats"),
    alpha = 0.3
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Box Scores" = "#0077CC", "WNBA Stats" = "#CC7700")
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

cat("### Player Comparison: Box Scores vs WNBA Stats\n")
cat(
  "| Player | Team | Box FG% | WNBA FG% | Box TS% | WNBA 3P% | Box PTS | WNBA PTS |\n"
)
cat(
  "|--------|------|---------|----------|---------|----------|---------|----------|\n"
)
player_comparison |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %s | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %d | %d |\n",
          x$player_name[i],
          x$team[i],
          x$box_fg_pct[i] * 100,
          x$fg_pct[i] * 100,
          x$box_ts_pct[i] * 100,
          x$fg3_pct[i] * 100,
          x$box_pts[i],
          x$points[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
cat("| Player | FG% | FGM/FGA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(fg_attempted >= 10) |>
  arrange(desc(fg_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$fg_pct[i] * 100,
          x$fg_made[i],
          x$fg_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n")
cat("| Player | TS% | PTS | FGA | FTA |\n")
cat("|--------|-----|-----|-----|-----|\n")
player_ts_pct |>
  filter(fg_attempted >= 10) |>
  arrange(desc(ts_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d | %d | %d |\n",
          x$player_name[i],
          x$ts_pct[i] * 100,
          x$points[i],
          x$fg_attempted[i],
          x$ft_attempted[i]
        ))
      }
    }
  }()

sink()
