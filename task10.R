# Task 10: Calculate various basketball metrics from play-by-play
# and box score data. This script calculates free throw attempts,
# possession changes, points per possession,
# and shooting percentages for players using both
# play-by-play and box score data.

library(tidyverse)
library(feather)
library(gghighcontrast)


# Load data
pbp_data <- read_feather("unrivaled_play_by_play.feather")
box_scores <- read_feather("unrivaled_box_scores.feather")

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
    fg_attempts = sum(fg_attempts, na.rm = TRUE),
    fg_pct = fg_made / fg_attempts * 100
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
    fg_attempts = sum(fg_attempts, na.rm = TRUE), # Already includes 2pt and 3pt attempts
    ft_attempts = sum(ft_attempts, na.rm = TRUE),
    ts_pct = points / (2 * (fg_attempts + 0.44 * ft_attempts)) * 100
  )

# Create and save density plots with InputMono font
fg_density_plot <- ggplot(player_fg_pct, aes(x = fg_pct)) +
  geom_density(fill = "#0077CC", alpha = 0.3) +
  theme_high_contrast() +
  theme(text = element_text(family = "InputMono")) +
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

ts_density_plot <- ggplot(player_ts_pct, aes(x = ts_pct)) +
  geom_density(fill = "#0077CC", alpha = 0.3) +
  theme_high_contrast() +
  theme(text = element_text(family = "InputMono")) +
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

# Print results in markdown format
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
cat("### Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
cat("| Player | FG% | FGM/FGA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(fg_attempts >= 10) |>
  arrange(desc(fg_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$fg_pct[i],
          x$fg_made[i],
          x$fg_attempts[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n")
cat("| Player | TS% | PTS | FGA | FTA |\n")
cat("|--------|-----|-----|-----|-----|\n")
player_ts_pct |>
  filter(fg_attempts >= 10) |>
  arrange(desc(ts_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d | %d | %d |\n",
          x$player_name[i],
          x$ts_pct[i],
          x$points[i],
          x$fg_attempts[i],
          x$ft_attempts[i]
        ))
      }
    }
  }()
