# Functions for rendering basketball statistics plots
# This file contains functions that take aggregated data and render plots

library(tidyverse)
library(gghighcontrast)
library(patchwork)
library(ggrepel)

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

#' Render and save field goal density plot
#' @param player_fg_pct Data frame with player FG%
#' @param player_comparison Data frame with player comparison stats
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_fg_density_plot <- function(
  player_fg_pct,
  player_comparison
) {
  fg_density_plot <- ggplot() +
    geom_density(
      data = player_fg_pct,
      aes(x = ubb_fg_pct, fill = "Unrivaled"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    geom_density(
      data = player_comparison,
      aes(x = field_goal_pct, fill = "WNBA"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    scale_fill_manual(
      name = "Data Source",
      values = c("Unrivaled" = ubb_color, "WNBA" = wnba_color)
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
  invisible(fg_density_plot)
}

#' Render and save two-point density plot
#' @param player_fg_pct Data frame with player FG%
#' @param player_comparison Data frame with player comparison stats
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_two_pt_density_plot <- function(
  player_fg_pct,
  player_comparison
) {
  two_pt_density_plot <- ggplot() +
    geom_density(
      data = player_fg_pct,
      aes(x = ubb_two_pt_pct, fill = "Unrivaled"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    geom_density(
      data = player_comparison,
      aes(x = wnba_two_pt_pct, fill = "WNBA"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    scale_fill_manual(
      name = "Data Source",
      values = c("Unrivaled" = ubb_color, "WNBA" = wnba_color)
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
  invisible(two_pt_density_plot)
}

#' Render and save three-point density plot
#' @param player_fg_pct Data frame with player FG%
#' @param player_comparison Data frame with player comparison stats
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_three_pt_density_plot <- function(
  player_fg_pct,
  player_comparison
) {
  three_pt_density_plot <- ggplot() +
    geom_density(
      data = player_fg_pct |> filter(player_name != "Aaliyah Edwards"),
      aes(x = ubb_three_pt_pct, fill = "Unrivaled"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    geom_density(
      data = player_comparison |> filter(player_name != "Aaliyah Edwards"),
      aes(x = three_point_pct, fill = "WNBA"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    scale_fill_manual(
      name = "Data Source",
      values = c("Unrivaled" = ubb_color, "WNBA" = wnba_color)
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
  invisible(three_pt_density_plot)
}

#' Render and save combined 2pt and 3pt density plots
#' @param two_pt_plot ggplot object for 2pt density
#' @param three_pt_plot ggplot object for 3pt density
#' @param chart_width_double Width for the combined chart
#' @param chart_height Height for the combined chart
render_combined_shooting_plot <- function(
  two_pt_plot,
  three_pt_plot
) {
  combined_shooting_plot <- (two_pt_plot) +
    (three_pt_plot) +
    plot_layout(ncol = 2) +
    plot_annotation(theme = theme(plot.margin = margin(0, 0, 0, 0)))

  ggsave(
    "plots/combined_shooting.png",
    plot = combined_shooting_plot,
    width = chart_width_double,
    height = chart_height,
    dpi = 300
  )
  invisible(combined_shooting_plot)
}

#' Render and save true shooting percentage density plot
#' @param player_ts_pct Data frame with player TS%
#' @param player_comparison Data frame with player comparison stats
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_ts_density_plot <- function(
  player_ts_pct,
  player_comparison
) {
  ts_density_plot <- ggplot() +
    geom_density(
      data = player_ts_pct,
      aes(x = ubb_ts_pct, fill = "Unrivaled"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    geom_density(
      data = player_comparison,
      aes(x = wnba_ts_pct, fill = "WNBA"),
      alpha = 0.7,
      color = NA,
      na.rm = TRUE
    ) +
    scale_fill_manual(
      name = "Data Source",
      values = c("Unrivaled" = ubb_color, "WNBA" = wnba_color)
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
  invisible(ts_density_plot)
}

#' Render and save barbell plot
#' @param data Data frame for the plot
#' @param y_var Y-axis variable (usually player name)
#' @param x1_var X-axis variable for the first point
#' @param x2_var X-axis variable for the second point
#' @param x1_label Label for the first point set
#' @param x2_label Label for the second point set
#' @param title Plot title
#' @param subtitle Plot subtitle
#' @param file_path Path to save the plot
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_barbell_plot <- function(
  data,
  y_var,
  x1_var,
  x2_var,
  x1_label,
  x2_label,
  title,
  subtitle = NULL,
  file_path
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

  barbell_plot <- ggplot() +
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
      low = wnba_color,
      high = ubb_color,
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

  ggsave(
    file_path,
    plot = barbell_plot,
    width = chart_width,
    height = chart_height,
    dpi = 300
  )
  invisible(barbell_plot)
}

#' Render and save shooting improvement scatter plot
#' @param shooting_improvement Data frame with shooting improvement stats
#' @param x_var X-axis variable (improvement metric)
#' @param y_var Y-axis variable (improvement metric)
#' @param x_lab X-axis label
#' @param y_lab Y-axis label
#' @param title Plot title
#' @param subtitle Plot subtitle
#' @param file_path Path to save the plot
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
#' @param scatter_point_size Base size for points
#' @param scatter_label_size Size for player labels
#' @param scatter_min_attempts Minimum attempts to display label
#' @param scatter_point_color Color for points
#' @param scatter_label_color Color for labels
#' @param scatter_quadrant_label_color Color for quadrant labels
#' @param scatter_quadrant_label_size Size for quadrant labels
#' @param scatter_reference_line_color Color for reference lines
#' @param scatter_quadrant_position_factor Factor for positioning quadrant labels
#' @param add_trendline Boolean to add trend line
render_improvement_scatter <- function(
  shooting_improvement,
  x_var,
  y_var,
  x_lab,
  y_lab,
  title,
  subtitle,
  file_path,
  add_trendline = FALSE
) {
  plot <- ggplot(shooting_improvement, aes(x = {{ x_var }}, y = {{ y_var }})) +
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
    # Add quadrant labels
    annotate(
      "text",
      x = max(shooting_improvement |> pull({{ x_var }})) *
        scatter_quadrant_position_factor,
      y = max(shooting_improvement |> pull({{ y_var }})) *
        scatter_quadrant_position_factor,
      label = "Improved in both",
      color = scatter_quadrant_label_color,
      family = "InputMono",
      size = scatter_quadrant_label_size,
      hjust = 1 # Right align for NE quadrant
    ) +
    annotate(
      "text",
      x = min(shooting_improvement |> pull({{ x_var }})) *
        scatter_quadrant_position_factor,
      y = max(shooting_improvement |> pull({{ y_var }})) *
        scatter_quadrant_position_factor,
      label = "Better 3PT",
      color = scatter_quadrant_label_color,
      family = "InputMono",
      size = scatter_quadrant_label_size,
      hjust = 0 # Left align for NW quadrant
    ) +
    annotate(
      "text",
      x = max(shooting_improvement |> pull({{ x_var }})) *
        scatter_quadrant_position_factor,
      y = min(shooting_improvement |> pull({{ y_var }})) *
        scatter_quadrant_position_factor,
      label = "Better 2PT",
      color = scatter_quadrant_label_color,
      family = "InputMono",
      size = scatter_quadrant_label_size,
      hjust = 1 # Right align for SE quadrant
    ) +
    annotate(
      "text",
      x = min(shooting_improvement |> pull({{ x_var }})) *
        scatter_quadrant_position_factor,
      y = min(shooting_improvement |> pull({{ y_var }})) *
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
      title = title,
      subtitle = subtitle,
      x = x_lab,
      y = y_lab
    )

  if (add_trendline) {
    plot <- plot +
      geom_smooth(
        method = "lm",
        formula = y ~ x,
        se = FALSE,
        color = scatter_reference_line_color,
        linewidth = 0.5,
        na.rm = TRUE
      )
  }

  ggsave(
    file_path,
    plot = plot,
    width = chart_width,
    height = chart_height,
    dpi = 300
  )
  invisible(plot)
}

#' Render and save field goal attempts histogram
#' @param player_fga Data frame with player FGA stats
#' @param chart_width Width of the chart
#' @param chart_height Height of the chart
render_fga_histogram <- function(player_fga) {
  # Create base histogram plot
  base_histogram <- ggplot(player_fga, aes(x = total_fga)) +
    geom_histogram(
      bins = 15,
      fill = ubb_color,
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
      color = wnba_color,
      linetype = "dashed",
      linewidth = 1
    ) +
    geom_vline(
      aes(xintercept = median(total_fga)),
      color = median_color,
      linetype = "dashed",
      linewidth = 1
    ) +
    # Add labels for mean and median
    annotate(
      "text",
      x = mean(player_fga$total_fga),
      y = max_count * 0.9,
      label = sprintf("Mean: %.1f", mean(player_fga$total_fga)),
      color = wnba_color,
      hjust = -0.1,
      family = "InputMono",
      fontface = "bold"
    ) +
    annotate(
      "text",
      x = median(player_fga$total_fga),
      y = max_count * 0.8,
      label = sprintf("Median: %.1f", median(player_fga$total_fga)),
      color = median_color,
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
  invisible(fga_histogram)
}
