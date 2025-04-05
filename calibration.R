# Purpose: Functions for creating and saving calibration plots
# for the win probability model.

#' Create and save a calibration plot for the win probability model
#' @param model_data Data frame containing model predictions and actual outcomes
#' @param title Title for the calibration plot
#' @param output_dir Directory to save the plot
#' @param timestamp Optional timestamp to append to filename
#' @return The calibration plot object
create_calibration_plot <- function(
  model_data,
  title = "Win Probability Calibration by Quarter",
  output_dir = "plots",
  timestamp = format(Sys.time(), "%Y%m%d_%H%M%S")
) {
  # Calculate Brier scores for each quarter
  brier_scores <- model_data |>
    group_by(quarter) |>
    summarize(
      brier_score = mean((win_prob - away_win)^2),
      .groups = "drop"
    )

  # Create calibration data with separate bins for each quarter
  calibration_data <- model_data |>
    # Create bins for predicted probabilities
    mutate(
      bin = cut(
        win_prob,
        breaks = seq(0, 1, 0.1),
        labels = seq(0.1, 1, 0.1),
        include.lowest = TRUE
      )
    ) |>
    # Calculate actual win rates for each bin and quarter
    group_by(quarter, bin) |>
    summarize(
      actual_win_rate = mean(away_win),
      n_games = n(),
      .groups = "drop"
    ) |>
    # Convert bin labels to numeric for plotting
    mutate(
      bin_midpoint = as.numeric(as.character(bin))
    ) |>
    # Join with Brier scores
    left_join(brier_scores, by = "quarter")

  # Create calibration plot with separate facets for each quarter
  p <- ggplot(calibration_data, aes(x = bin_midpoint, y = actual_win_rate)) +
    geom_point(aes(size = n_games), color = "#FFA500", alpha = 0.8) + # Size based on number of games
    scale_size_continuous(range = c(2, 8)) + # Control point size range
    geom_line(color = "#FFA500", linewidth = 1) +
    geom_abline(
      intercept = 0,
      slope = 1,
      color = "#45B7D1",
      linetype = "dashed",
      alpha = 0.5
    ) +
    facet_wrap(~quarter, ncol = 2, nrow = 2) +
    scale_x_continuous(breaks = seq(0, 1, 0.1), labels = scales::percent) +
    scale_y_continuous(breaks = seq(0, 1, 0.1), labels = scales::percent) +
    # Add Brier score labels
    geom_text(
      data = brier_scores,
      aes(
        x = 0.6,
        y = 0.05,
        label = sprintf("Brier Score: %.4f", brier_score)
      ),
      color = "white", # White text for Brier scores
      size = 3,
      family = "InputMono"
    ) +
    labs(
      title = title,
      subtitle = "How well predicted probabilities match actual outcomes",
      x = "Predicted Win Probability",
      y = "Actual Win Rate",
      caption = "Data: Unrivaled Basketball League"
    ) +
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    )

  # Save the plot with high resolution
  ggsave(
    filename = file.path(
      output_dir,
      sprintf("model_calibration_%s.png", timestamp)
    ),
    plot = p,
    width = 10,
    height = 6,
    dpi = 300,
    bg = "#1A1A1A"
  )

  return(p)
}
