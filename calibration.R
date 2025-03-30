# Purpose: Functions for creating and saving calibration plots for the win probability model.

#' Create and save a calibration plot for the win probability model
#' @param model_data Data frame containing model predictions and actual outcomes
#' @param output_dir Directory to save the plot
#' @param timestamp Optional timestamp to append to filename
#' @return The calibration plot object
create_calibration_plot <- function(
  model_data,
  output_dir = "plots",
  timestamp = format(Sys.time(), "%Y%m%d_%H%M%S")
) {
  # Group predictions into 10 bins
  calibration_data <- model_data |>
    mutate(
      pred_bin = cut(win_prob, breaks = seq(0, 1, 0.1), include.lowest = TRUE)
    ) |>
    # Calculate actual win rate for each bin
    group_by(pred_bin) |>
    summarize(
      n = n(),
      actual_win_rate = mean(away_win),
      pred_win_rate = mean(win_prob)
    ) |>
    # Calculate bin centers for plotting
    mutate(
      bin_center = as.numeric(pred_bin) - 0.05
    )

  # Calculate Brier score
  brier_score <- mean((model_data$win_prob - model_data$away_win)^2)

  # Create calibration plot
  p_calibration <- ggplot(
    calibration_data,
    aes(x = pred_win_rate, y = actual_win_rate)
  ) +
    # Add perfect calibration line
    geom_abline(intercept = 0, slope = 1, color = "white", alpha = 0.5) +
    # Add points with size based on number of predictions
    geom_point(aes(size = n), color = "#FF6B6B") +
    # Add error bars (Wilson confidence intervals)
    geom_errorbar(
      aes(
        ymin = actual_win_rate -
          1.96 * sqrt(actual_win_rate * (1 - actual_win_rate) / n),
        ymax = actual_win_rate +
          1.96 * sqrt(actual_win_rate * (1 - actual_win_rate) / n)
      ),
      width = 0.02,
      color = "#FF6B6B",
      alpha = 0.5
    ) +
    # Add labels
    scale_x_continuous(
      name = "Predicted Win Probability",
      labels = scales::percent,
      limits = c(0, 1)
    ) +
    scale_y_continuous(
      name = "Actual Win Rate",
      labels = scales::percent,
      limits = c(0, 1)
    ) +
    scale_size_continuous(
      name = "Number of Predictions",
      range = c(2, 8)
    ) +
    labs(
      title = "Model Calibration: Predicted vs Actual Win Probabilities",
      subtitle = sprintf(
        "Points show actual win rate for each prediction bin\nBrier Score: %.4f (lower is better)",
        brier_score
      )
    ) +
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    )

  # Save calibration plot
  ggsave(
    filename = file.path(
      output_dir,
      sprintf("model_calibration_%s.png", timestamp)
    ),
    plot = p_calibration,
    width = 10,
    height = 6,
    dpi = 300
  )

  return(p_calibration)
}
