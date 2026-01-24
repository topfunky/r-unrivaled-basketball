# Purpose: Creates a bump chart visualization of team rankings based on games played,
# using data from the scraped scores CSV. Calculates rankings after each game and
# displays them with custom Unrivaled colors and high contrast theme. Outputs include
# a PNG chart and a feather file with the rankings data.

# Load required libraries
library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)
library(ggbump) # For smooth bump charts
library(feather) # For saving data in feather format

# Import team colors
source("team_colors.R")

# Process each season separately
seasons <- c(2025, 2026)

# Read the CSV data
all_games <- read_csv("fixtures/unrivaled_scores.csv")

for (season_year in seasons) {
  print(paste0("Processing season ", season_year, "..."))
  
  # Filter games for this season
  games <- all_games |>
    filter(season == season_year)
  
  # Skip if no games for this season
  if (nrow(games) == 0) {
    print(paste0("No games found for season ", season_year, ". Skipping..."))
    next
  }

  # Transform data into long format for analysis
  games_long <- games |>
    # Create away team rows
    mutate(
      team = away_team,
      score = away_team_score,
      opponent = home_team,
      opponent_score = home_team_score,
      is_home = FALSE
    ) |>
    # Add home team rows
    bind_rows(
      games |>
        mutate(
          team = home_team,
          score = home_team_score,
          opponent = away_team,
          opponent_score = away_team_score,
          is_home = TRUE
        )
    ) |>
    # Calculate wins and losses
    mutate(
      result = case_when(
        score > opponent_score ~ "W",
        score < opponent_score ~ "L",
        TRUE ~ "T"
      ),
      point_differential = score - opponent_score
    )

  print("🏀 Games Long Format:")
  print(games_long)

  # Calculate cumulative wins and losses for each team
  team_records <- games_long |>
    select(
      date,
      team,
      score,
      opponent,
      opponent_score,
      is_home,
      result,
      point_differential,
      season_type
    ) |>
    group_by(team) |>
    arrange(date) |>
    mutate(
      wins = cumsum(result == "W"),
      losses = cumsum(result == "L"),
      games_played = cumsum(!is.na(result)), # Count cumulative games played
      point_differential = cumsum(score - opponent_score) # Cumulative point differential
    )

  print("🏀 Team Records:")
  print(team_records)

  # Determine playoff line for this season
  playoff_line <- if (season_year == 2025) 14 else max(team_records$games_played, na.rm = TRUE)

  # Create rankings based on games played
  game_rankings <- team_records |>
    # Group by games_played to compare teams with same number of games
    group_by(games_played) |>
    # Calculate head-to-head records for each team
    mutate(
      h2h_wins = map_dbl(seq_len(n()), function(i) {
        # Get current team and its wins from the current row
        current_team <- team[i]
        current_wins <- wins[i]
        current_games_played <- games_played[i]

        # For playoff line, count all wins against playoff teams
        if (current_games_played == playoff_line) {
          # Playoff teams vary by season - adjust as needed
          playoff_teams <- if (season_year == 2025) c("Lunar Owls", "Rose", "Laces") else c()
          # Count all wins against playoff teams
          playoff_wins <- games_long |>
            filter(
              team == current_team,
              opponent %in% playoff_teams,
              date <= max(date[team == current_team]) # Only count games up to current date
            ) |>
            summarise(wins = sum(result == "W")) |>
            pull(wins)
          return(playoff_wins)
        }

        # For other games, use regular head-to-head comparison
        # Get the next team with same number of wins (if any)
        next_team <- team_records |>
          filter(
            games_played == current_games_played,
            wins == current_wins,
            team != current_team # Exclude self
          ) |>
          slice(1) |>
          pull(team)

        # If no tied team, return 0
        if (length(next_team) == 0) {
          return(0)
        }

        # Count wins against the specific tied team
        team_games <- games_long |>
          filter(
            team == current_team,
            opponent == next_team,
            date <= max(date[team == current_team]) # Only count games up to current date
          )
        sum(team_games$result == "W")
      })
    ) |>
    # First sort by wins (descending), then by head-to-head wins, then by point differential
    arrange(desc(wins), desc(h2h_wins), desc(point_differential)) |>
    # Assign ranks from 1 to 6
    mutate(rank = row_number()) |>
    # Ensure rank is between 1 and 6
    mutate(rank = pmin(pmax(rank, 1), 6)) |>
    # Fill in the ranks for the rest of the week
    group_by(team) |>
    fill(rank, .direction = "down") |>
    ungroup()

  print(game_rankings)

  # Print final standings with point differential (regular season only)
  print(paste0("\nFinal Regular Season Standings (", season_year, "):"))
  # For 2025, filter to playoff_line. For 2026 (ongoing season), get latest record for each team
  if (season_year == 2025) {
    final_standings <- team_records |>
      filter(games_played == playoff_line) |> # Only include regular season games
      select(team, wins, losses, point_differential)
  } else {
    # For ongoing seasons, get the most recent record for each team
    final_standings <- team_records |>
      group_by(team) |>
      slice_max(games_played, n = 1) |>
      ungroup() |>
      select(team, wins, losses, point_differential)
  }
  
  final_standings <- final_standings |>
    arrange(desc(wins), desc(point_differential)) |>
    mutate(
      rank = row_number(),
      record = paste0(wins, "-", losses)
    )

  # Print in markdown format
  cat("\n| Team | Record | Point Differential |\n")
  cat("|------|---------|-------------------|\n")
  final_standings |>
    {
      \(x) {
        walk(
          seq_len(nrow(x)),
          \(i) {
            cat(sprintf(
              "| %s | %s | %+d |\n",
              x$team[i],
              x$record[i],
              round(x$point_differential[i])
            ))
          }
        )
      }
    }()
  
  # Create output directory if it doesn't exist
  output_dir <- file.path("data", season_year)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  
  write_feather(final_standings, file.path(output_dir, "unrivaled_regular_season_standings.feather"))

  # Create the bump chart
  # Define plot parameters
  line_width <- 4
  dot_size <- 8
  label_size <- 3

  p <- game_rankings |>
    ggplot(aes(x = games_played, y = rank, color = team)) +
    # Add vertical line at end of regular season (only for 2025)
    {if (season_year == 2025 && max(game_rankings$games_played, na.rm = TRUE) >= 14)
      geom_vline(
        xintercept = 14,
        linetype = "dotted",
        color = "white",
        alpha = 0.5
      )
    } +
    # Add "Playoffs" label (only for 2025)
    {if (season_year == 2025 && max(game_rankings$games_played, na.rm = TRUE) >= 14)
      annotate(
        "text",
        x = 14.2,
        y = 6,
        label = "Playoffs",
        color = "#606060",
        family = "InputMono",
        size = 2,
        hjust = 0,
        vjust = 0.5 # Center vertically
      )
    } +
  # Use geom_bump for smooth lines and points
  geom_bump(
    linewidth = line_width,
    size = dot_size, # TODO: Might not be needed if linewidth is set
    show.legend = FALSE # Don't show in legend
  ) +
  # Use team colors from imported palette
  scale_color_manual(values = TEAM_COLORS) +
  # Reverse y-axis so rank 1 is at the top
  scale_y_reverse(breaks = 1:6) +
  # Add team labels at the end of each line
  geom_text(
    data = game_rankings |>
      group_by(team) |>
      slice_max(games_played, n = 1) |>
      mutate(
        x_offset = case_when(
          team == "Rose" ~ -1,
          team == "Lunar Owls" ~ 0,
          team == "Mist" ~ -2.9,
          team == "Laces" ~ 0,
          team == "Phantom" ~ 0,
          team == "Vinyl" ~ -0.7
        ),
        y_offset = case_when(
          team == "Rose" ~ 1,
          team == "Lunar Owls" ~ 0,
          team == "Mist" ~ 0,
          team == "Laces" ~ 0,
          team == "Phantom" ~ 0,
          team == "Vinyl" ~ 2
        )
      ),
    aes(
      label = team,
      x = games_played + x_offset,
      y = rank + y_offset
    ),
    hjust = 1.1,
    size = label_size,
    family = "InputMono",
    show.legend = FALSE,
    color = "black",
    fontface = "bold"
  ) +
  # Use gghighcontrast theme with white text on black background
  theme_high_contrast(
    foreground_color = "white",
    background_color = "black",
    base_family = "InputMono"
  ) +
  # Style grid lines in dark grey
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  # Add labels
  labs(
    title = paste0("Unrivaled Basketball League Rankings ", season_year),
    subtitle = "Team rankings by win/loss record throughout the season",
    x = "Games Played",
    y = "Rank",
    color = "Team",
    caption = "Game data from unrivaled.basketball",
  )

  # Create plots directory if it doesn't exist
  plots_dir <- file.path("plots", season_year)
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

  # Save the plot
  ggsave(file.path(plots_dir, "unrivaled_rankings.png"), p, width = 6, height = 4, dpi = 300)

  # Save the data
  write_feather(game_rankings, file.path(output_dir, "unrivaled_rankings.feather"))
  
  print(paste0("✅ Completed processing season ", season_year))
}
