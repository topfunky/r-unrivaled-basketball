# Purpose: Contains functions for creating win probability visualizations
# for basketball games.

# Load required libraries
library(tidyverse)
library(gghighcontrast)

#' Create a win probability visualization for a single game
#'
#' @param game_data A data frame containing play-by-play data for a single game
#' @param game_id The ID of the game to visualize
#' @return A ggplot object with the win probability visualization
create_win_probability_plot <- function(game_data, game_id) {
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
      values = c("Win Probability" = "#B39DFF") # Light purple
    ) +
    scale_fill_manual(
      name = "Point Differential",
      values = c("TRUE" = "#E1BEE7", "FALSE" = "#9C27B0"), # Higher contrast purples
      labels = c("TRUE" = "Away Team Ahead", "FALSE" = "Home Team Ahead")
    ) +
    labs(
      title = paste0("Win Probability and Point Differential - ", game_id),
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

  invisible(p)
}

#' Generate and save win probability visualizations for all games
#'
#' @param model_data A data frame containing play-by-play data with win probabilities
#' @param output_dir Directory to save the visualizations
#' @param file_pattern Pattern for the output filenames
#' @return NULL
generate_win_probability_plots <- function(
  model_data,
  output_dir = "plots",
  file_pattern = "win_prob_%s.png"
) {
  # Create output directory if it doesn't exist
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Create visualization for each game
  message("Creating win probability visualizations...")
  for (game in unique(model_data$game_id)) {
    game_data <- model_data |>
      filter(game_id == game)

    # Create the plot
    p <- create_win_probability_plot(game_data, game)

    # Save the plot
    ggsave(
      filename = file.path(output_dir, sprintf(file_pattern, game)),
      plot = p,
      width = 10,
      height = 6,
      dpi = 300
    )
  }

  message("All visualizations saved to ", output_dir, "/ directory!")
  invisible(NULL)
}
