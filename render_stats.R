# Functions for rendering basketball statistics in markdown format
# This file contains functions that take aggregated data and render it as markdown

library(tidyverse)

#' Render a markdown table of shooting improvements
#' @param shooting_improvement Data frame with shooting improvement statistics
render_shooting_improvements <- function(shooting_improvement) {
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
}

#' Render free throw and points per possession statistics
#' @param total_ft_attempts Total number of free throw attempts
#' @param points_per_possession Data frame with points per possession statistics
render_possession_stats <- function(total_ft_attempts, points_per_possession) {
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
}

#' Render player comparison statistics
#' @param player_comparison Data frame with player comparison statistics
render_player_comparison <- function(player_comparison) {
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
}

#' Render shooting percentage differences
#' @param player_comparison Data frame with player comparison statistics
render_shooting_differences <- function(player_comparison) {
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
}

#' Render top players by shooting percentage
#' @param player_fg_pct Data frame with field goal percentage statistics
render_top_shooters <- function(player_fg_pct) {
  # Top 10 by FG%
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

  # Top 10 by 2P%
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

  # Top 10 by 3P%
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
}

#' Render top players by true shooting percentage
#' @param player_ts_pct Data frame with true shooting percentage statistics
render_top_ts_shooters <- function(player_ts_pct) {
  cat(
    "\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n"
  )
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
}

#' Render all statistics to a markdown file
#' @param output_file Path to output markdown file
#' @param stats List containing all statistics data frames
render_all_stats <- function(output_file, stats) {
  sink(output_file)

  cat("# Basketball Metrics Summary\n\n")

  # Render possession stats
  render_possession_stats(stats$total_ft_attempts, stats$points_per_possession)

  cat("## Player Shooting Statistics\n")

  # Render player comparison
  render_player_comparison(stats$player_comparison)

  # Render shooting differences
  render_shooting_differences(stats$player_comparison)

  # Render shooting improvements
  render_shooting_improvements(stats$shooting_improvement)

  # Render top shooters
  render_top_shooters(stats$player_fg_pct)

  # Render top TS shooters
  render_top_ts_shooters(stats$player_ts_pct)

  # Close the sink
  while (sink.number() > 0) sink()
}
