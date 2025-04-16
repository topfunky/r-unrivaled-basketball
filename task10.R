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
scatter_point_color <- "#6A0DAD"
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

# Create and save density plots with InputMono font
fg_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct,
    aes(x = ubb_fg_pct, fill = "Unrivaled"),
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
    title = "Unrivaled vs WNBA: Distribution of Field Goal Shot Accuracy",
    subtitle = "Per player across the entire season",
    x = "Field Goal Percentage",
    y = "Density"
  )

ggsave(
  "plots/fg_density.png",
  plot = fg_density_plot,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create two-point percentage density plot
two_pt_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct,
    aes(x = ubb_two_pt_pct, fill = "Unrivaled"),
    alpha = 0.7,
    color = NA
  ) +
  geom_density(
    data = player_comparison,
    aes(x = wnba_two_pt_pct, fill = "WNBA"),
    alpha = 0.7,
    color = NA
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Unrivaled" = "#6A0DAD", "WNBA" = "#FF8C00")
  ) +
  scale_x_continuous(labels = scales::label_percent()) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Unrivaled vs WNBA: Two-Point Shot Accuracy",
    subtitle = "Per player across the entire season",
    x = "Two-Point Percentage",
    y = "Density"
  )

ggsave(
  "plots/two_pt_density.png",
  plot = two_pt_density_plot,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create three-point percentage density plot
three_pt_density_plot <- ggplot() +
  geom_density(
    data = player_fg_pct |> filter(player_name != "Aaliyah Edwards"),
    aes(x = ubb_three_pt_pct, fill = "Unrivaled"),
    alpha = 0.7,
    color = NA
  ) +
  geom_density(
    data = player_comparison |> filter(player_name != "Aaliyah Edwards"),
    aes(x = three_point_pct, fill = "WNBA"),
    alpha = 0.7,
    color = NA
  ) +
  scale_fill_manual(
    name = "Data Source",
    values = c("Unrivaled" = "#6A0DAD", "WNBA" = "#FF8C00")
  ) +
  scale_x_continuous(labels = scales::label_percent()) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Unrivaled vs WNBA: Three-Point Shot Accuracy",
    subtitle = "Per player across the entire season",
    x = "Three-Point Percentage",
    y = "Density"
  )

ggsave(
  "plots/three_pt_density.png",
  plot = three_pt_density_plot,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Render 2pt and 3pt density plots side by side

# Create a combined plot with both density plots side by side
combined_shooting_plot <- (two_pt_density_plot) +
  (three_pt_density_plot) +
  plot_layout(ncol = 2) +
  plot_annotation(theme = theme(plot.margin = margin(0, 0, 0, 0)))

ggsave(
  "plots/combined_shooting.png",
  plot = combined_shooting_plot,
  width = chart_width_double,
  height = chart_height,
  dpi = 300
)


ts_density_plot <- ggplot() +
  geom_density(
    data = player_ts_pct,
    aes(x = ubb_ts_pct, fill = "Unrivaled"),
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
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create a function to generate barbell plots
create_barbell_plot <- function(
  data,
  y_var,
  x1_var,
  x2_var,
  x1_label,
  x2_label,
  title,
  subtitle = NULL
) {
  # Create a data frame with interpolated points for the gradient
  gradient_data <- data |>
    mutate(
      # Create a sequence of points between x1 and x2 for each player
      gradient_points = map2(
        {{ x1_var }},
        {{ x2_var }},
        ~ seq(.x, .y, length.out = 100)
      ),
      # Calculate the position along the gradient (0 to 1) for each player
      min_val = {{ x1_var }},
      max_val = {{ x2_var }}
    ) |>
    unnest(gradient_points) |>
    mutate(
      # Calculate the position along the gradient (0 to 1) for each point
      gradient_position = (gradient_points - min_val) / (max_val - min_val)
    )

  ggplot() +
    # Add gradient lines between points with rounded ends
    geom_path(
      data = gradient_data,
      aes(
        x = gradient_points,
        y = reorder({{ y_var }}, {{ x2_var }}),
        group = {{ y_var }},
        color = gradient_position
      ),
      linewidth = 5.5,
      lineend = "round"
    ) +
    # Set colors for the gradient
    scale_color_gradient(
      low = "#FF8C00", # WNBA color
      high = "#6A0DAD", # Unrivaled color
      guide = "none" # Hide the gradient legend
    ) +
    # Format x-axis as percentages
    scale_x_continuous(
      labels = scales::label_percent(scale = 1)
    ) +
    # Apply high contrast theme
    theme_high_contrast() +
    theme(
      text = element_text(family = "InputMono"),
      legend.position = "bottom",
      axis.title.y = element_blank(),
      axis.title.x = element_blank()
    ) +
    labs(
      title = title,
      subtitle = subtitle
    )
}

# Create barbell plot for two-point shooting percentage differences
# Get top 10 players with biggest improvement in 2P%
two_pt_diff_data <- player_comparison |>
  filter(ubb_two_pt_attempted >= 40) |> # Filter by shot attempts
  mutate(
    two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100
  ) |>
  arrange(desc(two_pt_diff)) |>
  head(10) |>
  arrange(desc(ubb_two_pt_pct))


# Create the barbell plot using the new function
two_pt_barbell_plot <- create_barbell_plot(
  data = two_pt_diff_data,
  y_var = player_name,
  x1_var = wnba_two_pt_pct * 100,
  x2_var = ubb_two_pt_pct * 100,
  x1_label = "WNBA",
  x2_label = "Unrivaled",
  title = "Two-Point Shooting Percentage: WNBA vs Unrivaled",
  subtitle = "Players with biggest improvement in Unrivaled (purple)"
)

# Save the barbell plot
ggsave(
  "plots/two_pt_barbell_positive.png",
  plot = two_pt_barbell_plot,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create a second barbell plot for players with the greatest negative differences
two_pt_negative_diff_data <- player_comparison |>
  filter(ubb_two_pt_attempted >= 40) |> # Filter by shot attempts
  mutate(
    two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100
  ) |>
  arrange(two_pt_diff) |>
  head(10) |>
  arrange(desc(ubb_two_pt_pct))


# Create the negative difference barbell plot
two_pt_negative_barbell_plot <- create_barbell_plot(
  data = two_pt_negative_diff_data,
  y_var = player_name,
  x1_var = wnba_two_pt_pct * 100,
  x2_var = ubb_two_pt_pct * 100,
  x1_label = "WNBA",
  x2_label = "Unrivaled",
  title = "Two-Point Shooting Percentage: WNBA vs Unrivaled",
  subtitle = "Players with biggest decrease in Unrivaled (purple)"
)

# Save the negative difference barbell plot
ggsave(
  "plots/two_pt_barbell_negative.png",
  plot = two_pt_negative_barbell_plot,
  width = chart_width,
  height = chart_height,
  dpi = 300
)


# Create a scatter plot comparing 2-point and 3-point shooting percentage improvements
# Calculate the improvement in shooting percentages
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

# Create the scatter plot
improvement_scatter <- ggplot(
  shooting_improvement,
  aes(x = two_pt_improvement, y = three_pt_improvement)
) +
  # Add trend line
  geom_smooth(
    method = "lm",
    se = TRUE,
    color = "black",
    alpha = 0.2,
    linewidth = 1
  ) +
  # Add reference lines at 0
  geom_hline(
    yintercept = 0,
    linetype = "solid",
    color = scatter_reference_line_color
  ) +
  geom_vline(
    xintercept = 0,
    linetype = "solid",
    color = scatter_reference_line_color
  ) +
  # Add points
  geom_point(
    aes(size = ubb_fg_attempted),
    color = scatter_point_color
  ) +
  # Add player labels only for players with at least scatter_min_attempts field goal attempts
  geom_text_repel(
    data = shooting_improvement |>
      filter(ubb_fg_attempted >= scatter_min_attempts),
    aes(label = player_name),
    size = scatter_label_size,
    family = "InputMono",
    box.padding = 0.5,
    color = scatter_label_color
  ) +
  # Add quadrant labels with appropriate alignment
  annotate(
    "text",
    x = max(shooting_improvement$two_pt_improvement) *
      scatter_quadrant_position_factor,
    y = max(shooting_improvement$three_pt_improvement) *
      scatter_quadrant_position_factor,
    label = "Improved in both",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 1 # Right align for NE quadrant
  ) +
  annotate(
    "text",
    x = min(shooting_improvement$two_pt_improvement) *
      scatter_quadrant_position_factor,
    y = max(shooting_improvement$three_pt_improvement) *
      scatter_quadrant_position_factor,
    label = "Better 3PT",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 0 # Left align for NW quadrant
  ) +
  annotate(
    "text",
    x = max(shooting_improvement$two_pt_improvement) *
      scatter_quadrant_position_factor,
    y = min(shooting_improvement$three_pt_improvement) *
      scatter_quadrant_position_factor,
    label = "Better 2PT",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 1 # Right align for SE quadrant
  ) +
  annotate(
    "text",
    x = min(shooting_improvement$two_pt_improvement) *
      scatter_quadrant_position_factor,
    y = min(shooting_improvement$three_pt_improvement) *
      scatter_quadrant_position_factor,
    label = "Worse in both",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 0 # Left align for SW quadrant
  ) +
  # Customize the plot
  scale_size_continuous(
    name = "Field Goal Attempts",
    range = c(3, scatter_point_size),
    guide = "none" # Hide the size legend
  ) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Shooting Improvement: Unrivaled vs WNBA",
    subtitle = "Comparing 2P and 3P shooting",
    x = "2P (percentage points)",
    y = "3P (percentage points)"
  )

# Save the plot
ggsave(
  "plots/shooting_improvement_scatter.png",
  plot = improvement_scatter,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create a second version with relative improvements
relative_improvement_scatter <- ggplot(
  shooting_improvement,
  aes(x = two_pt_relative_improvement, y = three_pt_relative_improvement)
) +
  # Add reference lines at 0
  geom_hline(
    yintercept = 0,
    linetype = "solid",
    color = scatter_reference_line_color
  ) +
  geom_vline(
    xintercept = 0,
    linetype = "solid",
    color = scatter_reference_line_color
  ) +
  # Add points
  geom_point(
    aes(size = ubb_fg_attempted),
    color = scatter_point_color
  ) +
  # Add player labels only for players with at least scatter_min_attempts field goal attempts
  geom_text_repel(
    data = shooting_improvement |>
      filter(ubb_fg_attempted >= scatter_min_attempts),
    aes(label = player_name),
    size = scatter_label_size,
    family = "InputMono",
    box.padding = 0.5,
    color = scatter_label_color
  ) +
  # Add quadrant labels with appropriate alignment
  annotate(
    "text",
    x = max(shooting_improvement$two_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    y = max(shooting_improvement$three_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    label = "Improved in both",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 1 # Right align for NE quadrant
  ) +
  annotate(
    "text",
    x = min(shooting_improvement$two_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    y = max(shooting_improvement$three_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    label = "Better 3PT, worse 2PT",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 0 # Left align for NW quadrant
  ) +
  annotate(
    "text",
    x = max(shooting_improvement$two_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    y = min(shooting_improvement$three_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    label = "Better 2PT, worse 3PT",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 1 # Right align for SE quadrant
  ) +
  annotate(
    "text",
    x = min(shooting_improvement$two_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    y = min(shooting_improvement$three_pt_relative_improvement) *
      scatter_quadrant_position_factor,
    label = "Worse in both",
    color = scatter_quadrant_label_color,
    family = "InputMono",
    size = scatter_quadrant_label_size,
    hjust = 0 # Left align for SW quadrant
  ) +
  # Customize the plot
  scale_size_continuous(
    name = "Field Goal Attempts",
    range = c(3, scatter_point_size),
    guide = "none" # Hide the size legend
  ) +
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono"),
    legend.position = "bottom"
  ) +
  labs(
    title = "Relative Shooting Improvement: Unrivaled vs WNBA",
    subtitle = "Comparing relative improvements in 2-point and 3-point shooting",
    x = "2-Point Shooting Improvement (%)",
    y = "3-Point Shooting Improvement (%)"
  )

# Save the relative improvement plot
ggsave(
  "plots/relative_shooting_improvement_scatter.png",
  plot = relative_improvement_scatter,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Add a table of shooting improvements to the markdown output
cat("\n### Shooting Percentage Improvements: Unrivaled vs WNBA\n")
cat(
  "| Player | 2PT% Improvement | 3PT% Improvement | 2PT% Relative | 3PT% Relative |\n"
)
cat(
  "|--------|------------------|------------------|---------------|---------------|\n"
)
shooting_improvement |>
  arrange(desc(two_pt_improvement + three_pt_improvement)) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %+.1f%% | %+.1f%% | %+.1f%% | %+.1f%% |\n",
          x$player_name[i],
          x$two_pt_improvement[i],
          x$three_pt_improvement[i],
          x$two_pt_relative_improvement[i],
          x$three_pt_relative_improvement[i]
        ))
      }
    }
  }()

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
  "| Player | UBB FG% | WNBA FG% | UBB 2P% | WNBA 2P% | UBB 3P% | WNBA 3P% | UBB TS% | WNBA TS% |\n"
)
cat(
  "|--------|----------|----------|----------|----------|----------|----------|----------|----------|\n"
)
player_comparison |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.1f%% |\n",
          x$player_name[i],
          x$ubb_fg_pct[i] * 100,
          x$field_goal_pct[i] * 100,
          x$ubb_two_pt_pct[i] * 100,
          x$wnba_two_pt_pct[i] * 100,
          x$ubb_three_pt_pct[i] * 100,
          x$three_point_pct[i] * 100,
          x$ubb_ts_pct[i] * 100,
          x$wnba_ts_pct[i] * 100
        ))
      }
    }
  }()

cat("\n### Shooting Percentage Differences (UBB - WNBA)\n")
cat(
  "| Player | UBB FGA | FG% Diff | 2P% Diff | 3P% Diff | TS% Diff |\n"
)
cat(
  "|--------|----------|----------|----------|----------|----------|\n"
)
player_comparison |>
  mutate(
    fg_diff = (ubb_fg_pct - field_goal_pct) * 100,
    two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100,
    three_pt_diff = (ubb_three_pt_pct - three_point_pct) * 100,
    ts_diff = (ubb_ts_pct - wnba_ts_pct) * 100
  ) |>
  arrange(desc(fg_diff)) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %d | %+.1f%% | %+.1f%% | %+.1f%% | %+.1f%% |\n",
          x$player_name[i],
          x$ubb_fg_attempted[i],
          x$fg_diff[i],
          x$two_pt_diff[i],
          x$three_pt_diff[i],
          x$ts_diff[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
cat("| Player | FG% | FGM/FGA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(ubb_fg_attempted >= 10) |>
  arrange(desc(ubb_fg_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$ubb_fg_pct[i] * 100,
          x$ubb_fg_made[i],
          x$ubb_fg_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Two-Point Percentage (minimum 10 attempts)\n")
cat("| Player | 2P% | 2PM/2PA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(ubb_two_pt_attempted >= 10) |>
  arrange(desc(ubb_two_pt_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$ubb_two_pt_pct[i] * 100,
          x$ubb_two_pt_made[i],
          x$ubb_two_pt_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by Three-Point Percentage (minimum 5 attempts)\n")
cat("| Player | 3P% | 3PM/3PA |\n")
cat("|--------|-----|----------|\n")
player_fg_pct |>
  filter(ubb_three_pt_attempted >= 5) |>
  arrange(desc(ubb_three_pt_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d/%d |\n",
          x$player_name[i],
          x$ubb_three_pt_pct[i] * 100,
          x$ubb_three_pt_made[i],
          x$ubb_three_pt_attempted[i]
        ))
      }
    }
  }()

cat("\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n")
cat("| Player | TS% | PTS | FGA | FTA |\n")
cat("|--------|-----|-----|-----|-----|\n")
player_ts_pct |>
  filter(ubb_fg_attempted >= 10) |>
  arrange(desc(ubb_ts_pct)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %.1f%% | %d | %d | %d |\n",
          x$player_name[i],
          x$ubb_ts_pct[i] * 100,
          x$ubb_pts[i],
          x$ubb_fg_attempted[i],
          x$ubb_ft_attempted[i]
        ))
      }
    }
  }()

# Create histogram of field goal attempts by player
# First, get the total field goal attempts for each player
player_fga <- player_fg_pct |>
  mutate(
    total_fga = ubb_fg_attempted
  ) |>
  arrange(desc(total_fga))

# Create base histogram plot
base_histogram <- ggplot(player_fga, aes(x = total_fga)) +
  geom_histogram(
    bins = 15,
    fill = "#6A0DAD",
    alpha = 0.8
  )

# Get the histogram data for y-axis scaling
hist_data <- ggplot_build(base_histogram)$data[[1]]
max_count <- max(hist_data$count)

# Create the final histogram with annotations
fga_histogram <- base_histogram +
  # Add vertical lines for mean and median
  geom_vline(
    aes(xintercept = mean(total_fga)),
    color = "#FF8C00",
    linetype = "dashed",
    linewidth = 1
  ) +
  geom_vline(
    aes(xintercept = median(total_fga)),
    color = "#00CED1",
    linetype = "dashed",
    linewidth = 1
  ) +
  # Add labels for mean and median
  annotate(
    "text",
    x = mean(player_fga$total_fga),
    y = max_count * 0.9,
    label = sprintf("Mean: %.1f", mean(player_fga$total_fga)),
    color = "#FF8C00",
    hjust = -0.1,
    family = "InputMono",
    fontface = "bold"
  ) +
  annotate(
    "text",
    x = median(player_fga$total_fga),
    y = max_count * 0.8,
    label = sprintf("Median: %.1f", median(player_fga$total_fga)),
    color = "#00CED1",
    hjust = -0.1,
    family = "InputMono",
    fontface = "bold"
  ) +
  # Apply high contrast theme
  theme_high_contrast() +
  theme(
    text = element_text(family = "InputMono")
  ) +
  labs(
    title = "Distribution of Field Goal Attempts by Player",
    subtitle = "Unrivaled Season",
    x = "Total Field Goal Attempts",
    y = "Number of Players"
  )

# Save the histogram
ggsave(
  "plots/fga_histogram.png",
  plot = fga_histogram,
  width = chart_width,
  height = chart_height,
  dpi = 300
)

# Create a table of top 10 players by field goal attempts
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

cat("\n### Top 10 Players by Field Goal Attempts\n")
cat("| Player | FGA | FGM | FGA Total | FG% |\n")
cat("|--------|-----|-----|-----------|-----|\n")
player_fg_pct |>
  arrange(desc(ubb_fg_attempted)) |>
  head(10) |>
  {
    function(x) {
      for (i in 1:nrow(x)) {
        cat(sprintf(
          "| %s | %d | %d | %d | %.1f%% |\n",
          x$player_name[i],
          x$ubb_fg_attempted[i],
          x$ubb_fg_made[i],
          x$ubb_fg_attempted[i],
          x$ubb_fg_pct[i] * 100
        ))
      }
    }
  }()


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


sink()
