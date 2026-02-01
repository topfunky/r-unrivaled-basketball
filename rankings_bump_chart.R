# Purpose: Creates a bump chart visualization of team rankings based on games played,
# using data from the scraped scores CSV. Calculates rankings after each game and
# displays them with custom Unrivaled colors and high contrast theme. Outputs include
# a PNG chart and a feather file with the rankings data.

library(tidyverse)
library(ggplot2)
library(lubridate)
library(gghighcontrast)
library(ggbump)
library(feather)

source("R/team_colors.R")

SEASON_TOTAL_GAMES <- 14
SEASONS <- c(2025, 2026)

# ---- Data loading ----

#' Load Unrivaled scores from CSV.
#' @param path Path to unrivaled_scores.csv
#' @return Tibble of game rows
load_unrivaled_scores <- function(path = "data/unrivaled_scores.csv") {
  read_csv(path)
}

#' Reshape games into one row per team per game (long format).
#' @param games Tibble with away_team, home_team, scores, date, season_type
#' @return Tibble with team, opponent, score, result, point_differential, is_home
games_to_long_format <- function(games) {
  away_rows <- games |>
    mutate(
      team = away_team,
      score = away_team_score,
      opponent = home_team,
      opponent_score = home_team_score,
      is_home = FALSE
    )

  home_rows <- games |>
    mutate(
      team = home_team,
      score = home_team_score,
      opponent = away_team,
      opponent_score = away_team_score,
      is_home = TRUE
    )

  bind_rows(away_rows, home_rows) |>
    mutate(
      result = case_when(
        score > opponent_score ~ "W",
        score < opponent_score ~ "L",
        TRUE ~ "T"
      ),
      point_differential = score - opponent_score
    )
}

# ---- Team records and playoff parameters ----

#' Compute cumulative wins, losses, games played, and point differential per team.
#' @param games_long Long-format games from games_to_long_format()
#' @return Tibble with team, date, wins, losses, games_played, point_differential
compute_team_records <- function(games_long) {
  games_long |>
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
      games_played = cumsum(!is.na(result)),
      point_differential = cumsum(score - opponent_score)
    )
}

#' Number of games that define "end of regular season" for ranking display.
#' @param season_year Season year (e.g. 2025)
#' @param team_records Output of compute_team_records()
#' @return Single number (14 for 2025, max games_played otherwise)
playoff_line_for_season <- function(season_year, team_records) {
  if (season_year == 2025) {
    14
  } else {
    max(team_records$games_played, na.rm = TRUE)
  }
}

#' Team names used as playoff tiebreaker for a season.
#' @param season_year Season year
#' @return Character vector of team names (empty for ongoing seasons)
playoff_teams_for_season <- function(season_year) {
  if (season_year == 2025) {
    c("Lunar Owls", "Rose", "Laces")
  } else {
    character(0)
  }
}

# ---- Head-to-head tiebreaker ----

#' Count tiebreaker wins for one row: playoff wins at playoff_line, else H2H vs tied team.
#' @param current_team Team name for this row
#' @param current_wins Win count at this games_played
#' @param current_games_played Games played at this row
#' @param current_date Date of this row (for filtering games up to that point)
#' @param playoff_line End-of-regular-season games count
#' @param playoff_teams Teams to count wins against when at playoff_line
#' @param games_long Long-format games
#' @param team_records Team records from compute_team_records()
#' @return Single number (tiebreaker wins)
count_tiebreaker_wins <- function(
  current_team,
  current_wins,
  current_games_played,
  current_date,
  playoff_line,
  playoff_teams,
  games_long,
  team_records
) {
  if (current_games_played == playoff_line && length(playoff_teams) > 0) {
    games_long |>
      filter(
        team == current_team,
        opponent %in% playoff_teams,
        date <= current_date
      ) |>
      summarise(wins = sum(result == "W")) |>
      pull(wins)
  } else {
    next_team <- team_records |>
      filter(
        games_played == current_games_played,
        wins == current_wins,
        team != current_team
      ) |>
      slice(1) |>
      pull(team)

    if (length(next_team) == 0) {
      return(0)
    }

    games_long |>
      filter(
        team == current_team,
        opponent == next_team,
        date <= current_date
      ) |>
      summarise(wins = sum(result == "W")) |>
      pull(wins)
  }
}

# ---- Rankings ----

#' Compute rank after each games_played, with wins then H2H then point differential.
#' @param team_records Output of compute_team_records()
#' @param games_long Long-format games
#' @param season_year Season year (for playoff_line and playoff_teams)
#' @return Tibble with team, games_played, rank (and filled by team)
compute_game_rankings <- function(team_records, games_long, season_year) {
  playoff_line <- playoff_line_for_season(season_year, team_records)
  playoff_teams <- playoff_teams_for_season(season_year)
  num_teams <- length(unique(team_records$team))

  team_records |>
    group_by(games_played) |>
    mutate(
      h2h_wins = map_dbl(seq_len(n()), function(i) {
        count_tiebreaker_wins(
          current_team = team[i],
          current_wins = wins[i],
          current_games_played = games_played[i],
          current_date = date[i],
          playoff_line = playoff_line,
          playoff_teams = playoff_teams,
          games_long = games_long,
          team_records = team_records
        )
      })
    ) |>
    arrange(desc(wins), desc(h2h_wins), desc(point_differential)) |>
    mutate(rank = pmin(pmax(row_number(), 1), num_teams)) |>
    group_by(team) |>
    fill(rank, .direction = "down") |>
    ungroup()
}

#' Build final standings table (record and point differential) for a season.
#' @param team_records Output of compute_team_records()
#' @param season_year Season year
#' @param playoff_line From playoff_line_for_season()
#' @return Tibble with team, wins, losses, point_differential, rank, record
final_standings_for_season <- function(
  team_records,
  season_year,
  playoff_line
) {
  if (season_year == 2025) {
    standings <- team_records |>
      filter(games_played == playoff_line) |>
      select(team, wins, losses, point_differential)
  } else {
    standings <- team_records |>
      group_by(team) |>
      slice_max(games_played, n = 1) |>
      ungroup() |>
      select(team, wins, losses, point_differential)
  }

  standings |>
    arrange(desc(wins), desc(point_differential)) |>
    mutate(
      rank = row_number(),
      record = paste0(wins, "-", losses)
    )
}

# ---- Output: console and files ----

#' Print final standings as a markdown table to the console.
#' @param final_standings Tibble with team, record, point_differential
print_standings_markdown <- function(final_standings) {
  cat("\n| Team | Record | Point Differential |\n")
  cat("|------|---------|-------------------|\n")
  for (i in seq_len(nrow(final_standings))) {
    x <- final_standings[i, ]
    cat(sprintf(
      "| %s | %s | %+d |\n",
      x$team,
      x$record,
      round(x$point_differential)
    ))
  }
}

#' Create directory if it does not exist.
#' @param path Directory path
ensure_directory <- function(path) {
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
}

#' Write standings and game rankings feather files for a season.
#' @param final_standings Output of final_standings_for_season()
#' @param game_rankings Output of compute_game_rankings()
#' @param season_year Season year
save_season_data <- function(final_standings, game_rankings, season_year) {
  output_dir <- file.path("data", season_year)
  ensure_directory(output_dir)

  write_feather(
    final_standings,
    file.path(output_dir, "unrivaled_regular_season_standings.feather")
  )
  write_feather(
    game_rankings,
    file.path(output_dir, "unrivaled_rankings.feather")
  )
}

# ---- Bump chart ----

BUMP_LINE_WIDTH <- 2
BUMP_DOT_SIZE <- 8
BUMP_LABEL_SIZE <- 3

#' Build ggplot bump chart of rankings over games played.
#' @param game_rankings Output of compute_game_rankings()
#' @param num_teams Number of teams (for y scale and label placement)
#' @param season_year Season year (for title)
#' @return ggplot object
build_rankings_bump_chart <- function(game_rankings, num_teams, season_year) {
  final_ranks <- game_rankings |>
    group_by(team) |>
    slice_max(games_played, n = 1) |>
    ungroup() |>
    select(team, final_rank = rank)

  plot_data <- game_rankings |>
    left_join(final_ranks, by = "team") |>
    arrange(desc(final_rank), games_played, team)

  label_data <- game_rankings |>
    group_by(team) |>
    slice_max(games_played, n = 1) |>
    ungroup()

  max_games <- SEASON_TOTAL_GAMES

  ggplot(plot_data, aes(x = games_played, y = rank, color = team)) +
    geom_vline(
      xintercept = 14,
      linetype = "dotted",
      color = "white",
      alpha = 0.5
    ) +
    annotate(
      "text",
      x = 14.2,
      y = num_teams,
      label = "Playoffs",
      color = "#606060",
      family = "InputMono",
      size = 2,
      hjust = 0,
      vjust = 0.5
    ) +
    geom_bump(linewidth = BUMP_LINE_WIDTH, show.legend = FALSE) +
    scale_color_manual(values = TEAM_COLORS) +
    scale_y_reverse(breaks = 1:num_teams) +
    scale_x_continuous(breaks = 1:SEASON_TOTAL_GAMES) +
    geom_text(
      data = label_data,
      aes(label = team, x = max_games, y = rank),
      hjust = 1,
      nudge_x = 0.2,
      size = BUMP_LABEL_SIZE,
      family = "InputMono",
      show.legend = FALSE,
      color = "white",
      fontface = "bold"
    ) +
    theme_high_contrast(
      foreground_color = "white",
      background_color = "black",
      base_family = "InputMono"
    ) +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank()
    ) +
    coord_cartesian(clip = "off", xlim = c(1, max_games * 1.15)) +
    labs(
      title = paste0("Unrivaled Basketball League Rankings ", season_year),
      subtitle = "Team rankings by win/loss record throughout the season",
      x = "Games Played",
      y = "Rank",
      color = "Team",
      caption = "Game data from unrivaled.basketball",
    )
}

#' Save bump chart PNG to plots/{season_year}/unrivaled_rankings.png.
#' @param p ggplot object from build_rankings_bump_chart()
#' @param season_year Season year
save_bump_chart <- function(p, season_year) {
  plots_dir <- file.path("plots", season_year)
  ensure_directory(plots_dir)
  ggsave(
    file.path(plots_dir, "unrivaled_rankings.png"),
    p,
    width = 6,
    height = 4,
    dpi = 300
  )
}

# ---- Main ----

process_season <- function(games, season_year) {
  games_long <- games_to_long_format(games)
  team_records <- compute_team_records(games_long)
  playoff_line <- playoff_line_for_season(season_year, team_records)
  num_teams <- length(unique(team_records$team))

  game_rankings <- compute_game_rankings(team_records, games_long, season_year)
  final_standings <- final_standings_for_season(
    team_records,
    season_year,
    playoff_line
  )

  print(paste0("\nFinal Regular Season Standings (", season_year, "):"))
  print_standings_markdown(final_standings)

  save_season_data(final_standings, game_rankings, season_year)

  p <- build_rankings_bump_chart(game_rankings, num_teams, season_year)
  save_bump_chart(p, season_year)
}

all_games <- load_unrivaled_scores()

for (season_year in SEASONS) {
  print(paste0("Processing season ", season_year, "..."))

  games <- all_games |> filter(season == season_year)

  if (nrow(games) == 0) {
    print(paste0("No games found for season ", season_year, ". Skipping..."))
    next
  }

  process_season(games, season_year)
  print(paste0("Completed processing season ", season_year))
}
