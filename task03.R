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

# Create plots directory if it doesn't exist
message("Creating plots directory if it doesn't exist...")
dir.create("plots", showWarnings = FALSE, recursive = TRUE)


# Read the CSV data
games <- read_csv("fixtures/unrivaled_scores.csv")

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

      # For game 14, count all wins against playoff teams
      if (current_games_played == 14) {
        playoff_teams <- c("Lunar Owls", "Rose", "Laces")
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
      if (length(next_team) == 0) return(0)

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
print("\nFinal Regular Season Standings:")
final_standings <- team_records |>
  filter(games_played == 14) |> # Only include regular season games
  select(team, wins, losses, point_differential) |>
  arrange(desc(wins), desc(point_differential)) |>
  mutate(
    rank = row_number(),
    record = paste0(wins, "-", losses),
    point_differential = sprintf("%+d", round(point_differential)) # Format as whole number with + or - sign
  )

# Print in markdown format
cat("\n| Team | Record | Point Differential |\n")
cat("|------|---------|-------------------|\n")
final_standings |>
  {
    \(x)
      walk(
        seq_len(nrow(x)),
        \(i)
          cat(sprintf(
            "| %s | %s | %s |\n",
            x$team[i],
            x$record[i],
            x$point_differential[i]
          ))
      )
  }()
write_feather(final_standings, "unrivaled_regular_season_standings.feather")


# Create the bump chart
# Define plot parameters
line_width <- 4
dot_size <- 8
label_size <- 3

p <- game_rankings |>
  ggplot(aes(x = games_played, y = rank, color = team)) +
  # Add vertical line at end of regular season
  geom_vline(
    xintercept = 14,
    linetype = "dotted",
    color = "white",
    alpha = 0.5
  ) +
  # Add "Playoffs" label
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
  ) +
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
    title = "Unrivaled Basketball League Rankings 2025",
    subtitle = "Team rankings by win/loss record throughout the season",
    x = "Games Played",
    y = "Rank",
    color = "Team",
    caption = "Game data from unrivaled.basketball",
  )

# Save the plot
ggsave("plots/unrivaled_rankings_3.png", p, width = 6, height = 4, dpi = 300)

# Save the data
write_feather(game_rankings, "unrivaled_rankings_3.feather")
