# Functions for rendering basketball statistics in Markdown format
# This file contains functions that take aggregated data and render it as Markdown
# for later use in a blog post or other documentation.

library(tidyverse)
library(knitr) # Added for kable

# Helper function for percentage formatting
format_pct <- function(value, digits = 1) {
  sprintf(paste0("%.", digits, "f%%"), value * 100)
}

# Helper function for signed percentage formatting
format_signed_pct <- function(value, digits = 1) {
  sprintf(paste0("%+.", digits, "f%%"), value)
}

#' Render a markdown table of shooting improvements
#' @param shooting_improvement Data frame with shooting improvement statistics
render_shooting_improvements <- function(shooting_improvement) {
  cat("\n### Shooting Percentage Improvements: Unrivaled vs WNBA\n")
  shooting_improvement |>
    arrange(desc(two_pt_improvement + three_pt_improvement)) |>
    mutate(
      `2PT% Improvement` = format_signed_pct(two_pt_improvement),
      `3PT% Improvement` = format_signed_pct(three_pt_improvement),
      `2PT% Relative` = format_signed_pct(two_pt_relative_improvement),
      `3PT% Relative` = format_signed_pct(three_pt_relative_improvement)
    ) |>
    select(
      Player = player_name,
      `2PT% Improvement`,
      `3PT% Improvement`,
      `2PT% Relative`,
      `3PT% Relative`
    ) |>
    kable(format = "markdown") |>
    print()
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
  cat("\n### Player Comparison: Unrivaled vs WNBA Stats\n")
  player_comparison |>
    mutate(
      `UBB FG%` = format_pct(ubb_fg_pct),
      `WNBA FG%` = format_pct(field_goal_pct),
      `UBB 2P%` = format_pct(ubb_two_pt_pct),
      `WNBA 2P%` = format_pct(wnba_two_pt_pct),
      `UBB 3P%` = format_pct(ubb_three_pt_pct),
      `WNBA 3P%` = format_pct(three_point_pct),
      `UBB TS%` = format_pct(ubb_ts_pct),
      `WNBA TS%` = format_pct(wnba_ts_pct)
    ) |>
    select(
      Player = player_name,
      `UBB FG%`,
      `WNBA FG%`,
      `UBB 2P%`,
      `WNBA 2P%`,
      `UBB 3P%`,
      `WNBA 3P%`,
      `UBB TS%`,
      `WNBA TS%`
    ) |>
    kable(format = "markdown") |>
    print()
}

#' Render shooting percentage differences
#' @param player_comparison Data frame with player comparison statistics
render_shooting_differences <- function(player_comparison) {
  cat("\n### Shooting Percentage Differences (UBB - WNBA)\n")
  player_comparison |>
    mutate(
      `FG% Diff` = format_signed_pct((ubb_fg_pct - field_goal_pct) * 100),
      `2P% Diff` = format_signed_pct((ubb_two_pt_pct - wnba_two_pt_pct) * 100),
      `3P% Diff` = format_signed_pct(
        (ubb_three_pt_pct - three_point_pct) * 100
      ),
      `TS% Diff` = format_signed_pct((ubb_ts_pct - wnba_ts_pct) * 100)
    ) |>
    arrange(desc((ubb_fg_pct - field_goal_pct))) |>
    select(
      Player = player_name,
      `UBB FGA` = ubb_fg_attempted,
      `FG% Diff`,
      `2P% Diff`,
      `3P% Diff`,
      `TS% Diff`
    ) |>
    kable(format = "markdown") |>
    print()
}

#' Render top players by shooting percentage
#' @param player_fg_pct Data frame with field goal percentage statistics
render_top_shooters <- function(player_fg_pct) {
  # Top 10 by FG%
  cat("\n### Top 10 Players by Field Goal Percentage (minimum 10 attempts)\n")
  player_fg_pct |>
    filter(ubb_fg_attempted >= 10) |>
    arrange(desc(ubb_fg_pct)) |>
    head(10) |>
    mutate(
      `FG%` = format_pct(ubb_fg_pct),
      `FGM/FGA` = paste0(ubb_fg_made, "/", ubb_fg_attempted)
    ) |>
    select(Player = player_name, `FG%`, `FGM/FGA`) |>
    kable(format = "markdown") |>
    print()

  # Top 10 by 2P%
  cat("\n### Top 10 Players by Two-Point Percentage (minimum 10 attempts)\n")
  player_fg_pct |>
    filter(ubb_two_pt_attempted >= 10) |>
    arrange(desc(ubb_two_pt_pct)) |>
    head(10) |>
    mutate(
      `2P%` = format_pct(ubb_two_pt_pct),
      `2PM/2PA` = paste0(ubb_two_pt_made, "/", ubb_two_pt_attempted)
    ) |>
    select(Player = player_name, `2P%`, `2PM/2PA`) |>
    kable(format = "markdown") |>
    print()

  # Top 10 by 3P%
  cat("\n### Top 10 Players by Three-Point Percentage (minimum 5 attempts)\n")
  player_fg_pct |>
    filter(ubb_three_pt_attempted >= 5) |>
    arrange(desc(ubb_three_pt_pct)) |>
    head(10) |>
    mutate(
      `3P%` = format_pct(ubb_three_pt_pct),
      `3PM/3PA` = paste0(ubb_three_pt_made, "/", ubb_three_pt_attempted)
    ) |>
    select(Player = player_name, `3P%`, `3PM/3PA`) |>
    kable(format = "markdown") |>
    print()
}

#' Render top players by true shooting percentage
#' @param player_ts_pct Data frame with true shooting percentage statistics
render_top_ts_shooters <- function(player_ts_pct) {
  cat(
    "\n### Top 10 Players by True Shooting Percentage (minimum 10 attempts)\n"
  )
  player_ts_pct |>
    filter(ubb_fg_attempted >= 10) |>
    arrange(desc(ubb_ts_pct)) |>
    head(10) |>
    mutate(
      `TS%` = format_pct(ubb_ts_pct)
    ) |>
    select(
      Player = player_name,
      `TS%`,
      PTS = ubb_pts,
      FGA = ubb_fg_attempted,
      FTA = ubb_ft_attempted
    ) |>
    kable(format = "markdown") |>
    print()
}

#' Render top 10 2pt shooting differences
#' @param player_comparison Data frame with player comparison stats
render_top_2pt_diff <- function(player_comparison) {
  cat(
    "
### Two-Point Shooting Percentage Differences (Top 10 Improvements)
"
  )

  # Calculate top 10 differences internally, mirroring analyze_shooting_metrics.R logic
  two_pt_diff_data <- player_comparison |>
    filter(ubb_two_pt_attempted >= 40) |> # Filter by shot attempts
    mutate(
      two_pt_diff = (ubb_two_pt_pct - wnba_two_pt_pct) * 100
    ) |>
    arrange(desc(two_pt_diff)) |>
    head(10) |>
    arrange(desc(ubb_two_pt_pct)) # Keep original sorting for display

  two_pt_diff_data |>
    select(
      Player = player_name,
      `UBB 2P%` = ubb_two_pt_pct,
      `WNBA 2P%` = wnba_two_pt_pct,
      Difference = two_pt_diff,
      `UBB 2PA` = ubb_two_pt_attempted
    ) |>
    mutate(
      # Apply formatting consistent with other tables
      `UBB 2P%` = format_pct(`UBB 2P%`),
      `WNBA 2P%` = format_pct(`WNBA 2P%`),
      Difference = sprintf("%+.1fpp", Difference) # Using pp for percentage points
    ) |>
    kable(format = "markdown") |>
    print()
}

#' Render shot distribution comparison
#' @param player_comparison Data frame comparing player stats
render_shot_distribution <- function(player_comparison) {
  cat(
    "
### Shot Distribution: 2-Point vs 3-Point Attempts
"
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
    select(
      Player = player_name,
      `UBB 2P%` = ubb_2pt_pct,
      `UBB 3P%` = ubb_3pt_pct,
      `WNBA 2P%` = wnba_2pt_pct,
      `WNBA 3P%` = wnba_3pt_pct,
      `UBB 2PA` = ubb_two_pt_attempted,
      `UBB 3PA` = ubb_three_pt_attempted,
      `WNBA 2PA` = wnba_two_pt_attempted,
      `WNBA 3PA` = three_point_field_goals_attempted
    ) |>
    mutate(
      # Apply percentage formatting
      `UBB 2P%` = format_pct(`UBB 2P%`, 0),
      `UBB 3P%` = format_pct(`UBB 3P%`, 0),
      `WNBA 2P%` = format_pct(`WNBA 2P%`, 0),
      `WNBA 3P%` = format_pct(`WNBA 3P%`, 0)
    ) |>
    kable(format = "markdown") |>
    print()
}

#' Render all statistics to a markdown file
#' @param output_file Path to output markdown file
#' @param stats List containing all statistics data frames
render_all_stats <- function(output_file, stats) {
  sink(output_file)

  cat("# Basketball Metrics Summary\n\n")

  # Render possession stats
  render_possession_stats(stats$total_ft_attempts, stats$points_per_possession)

  cat("\n## Player Shooting Statistics\n") # Added newline

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

  # Render top 2pt diff
  render_top_2pt_diff(stats$player_comparison)

  # Render shot distribution
  render_shot_distribution(stats$player_comparison)

  # Close the sink
  while (sink.number() > 0) {
    sink()
  }
}
