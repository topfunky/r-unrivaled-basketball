# Purpose: Parses play by play data from downloaded game files.

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(feather)

# Function to parse play by play data
parse_play_by_play <- function(game_id) {
  # Read the play by play HTML file
  play_by_play_file <- path("games", game_id, "play-by-play.html")
  if (!file_exists(play_by_play_file)) {
    warning(sprintf("Play by play file not found for game %s", game_id))
    return(NULL)
  }

  # Parse the HTML
  html <- read_html(play_by_play_file)

  # Extract the table data
  tables <- html |> html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf(
      "No tables found in play by play file for game %s",
      game_id
    ))
    return(NULL)
  }

  # Get the first table and check if it has data
  table_data <- html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in play by play file for game %s", game_id))
    return(NULL)
  }

  # Convert to tibble and set names
  plays <- table_data[[1]] |>
    as_tibble() |>
    set_names(c("time", "play", "score")) |>
    mutate(
      game_id = game_id,
      # Extract quarter from play description if it exists,
      # otherwise use NA
      quarter = if_else(
        str_detect(play, "^Q\\d"),
        as.numeric(str_match(play, "^Q(\\d)")[, 2]),
        NA_real_
      ),
      # Clean up play description by removing quarter prefix if it exists
      play = if_else(
        str_detect(play, "^Q\\d"),
        str_remove(play, "^Q\\d"),
        play
      ),
      # Split score into away and home scores
      away_score = as.numeric(str_extract(score, "^\\d+")),
      home_score = as.numeric(str_extract(score, "\\d+$")),
      # Split time into minutes and seconds
      minute = if_else(
        str_detect(time, ":"),
        as.numeric(str_extract(time, "^\\d+")),
        0 # Set minutes to 0 if no colon
      ),
      second = if_else(
        str_detect(time, ":"),
        round(as.numeric(str_extract(time, "\\d+\\.?\\d*$"))),
        round(as.numeric(time)) # If no colon, treat entire value as seconds
      )
    ) |>
    # Reorder columns
    select(game_id, quarter, time, minute, second, play, away_score, home_score)

  return(plays)
}

# Function to parse box score data
parse_box_score <- function(game_id) {
  # Read the box score HTML file
  box_score_file <- path("games", game_id, "box-score.html")
  if (!file_exists(box_score_file)) {
    warning(sprintf("Box score file not found for game %s", game_id))
    return(NULL)
  }

  # Parse the HTML
  html <- read_html(box_score_file)

  # Extract the table data
  tables <- html |> html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf("No tables found in box score file for game %s", game_id))
    return(NULL)
  }

  # Get the first table and check if it has data
  table_data <- html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in box score file for game %s", game_id))
    return(NULL)
  }

  # Convert to tibble and ensure consistent types
  box_score <- table_data[[1]] |>
    as_tibble() |>
    mutate(
      game_id = game_id,
      # Convert MIN to character to ensure consistent type across all games
      MIN = as.character(MIN),
      # Add starter flag and clean player names
      is_starter = str_starts(PLAYERS, "S "),
      player_name = if_else(is_starter, str_remove(PLAYERS, "^S "), PLAYERS)
    ) |>
    # Filter out rows with blank player names or "TEAM" rows
    filter(
      !is.na(player_name),
      str_trim(player_name) != "",
      str_trim(player_name) != "TEAM"
    ) |>
    # Split shooting stats into made and missed
    # TODO: Should be made and attempted (not missed)
    mutate(
      # Split FG into made and attempts
      fg = as.numeric(str_extract(FG, "^\\d+")),
      fg_attempts = as.numeric(str_extract(FG, "\\d+$")),
      # Split 3PT into made and attempts
      three_pt = as.numeric(str_extract(`3PT`, "^\\d+")),
      three_pt_attempts = as.numeric(str_extract(`3PT`, "\\d+$")),
      # Split FT into made and attempts
      ft = as.numeric(str_extract(FT, "^\\d+")),
      ft_attempts = as.numeric(str_extract(FT, "\\d+$"))
    ) |>
    # Reorder columns to put new columns first
    select(
      game_id,
      is_starter,
      player_name,
      MIN,
      fg,
      fg_attempts,
      three_pt,
      three_pt_attempts,
      ft,
      ft_attempts,
      REB,
      OREB,
      DREB,
      AST,
      STL,
      BLK,
      TO,
      PF,
      PTS
    )

  return(box_score)
}

# Function to parse summary data
parse_summary <- function(game_id) {
  # Read the summary HTML file
  summary_file <- path("games", game_id, "summary.html")
  if (!file_exists(summary_file)) {
    warning(sprintf("Summary file not found for game %s", game_id))
    return(NULL)
  }

  # Parse the HTML
  html <- read_html(summary_file)

  # Extract the table data
  tables <- html |> html_nodes("table")
  if (length(tables) == 0) {
    warning(sprintf("No tables found in summary file for game %s", game_id))
    return(NULL)
  }

  # Get the first table and check if it has data
  table_data <- html_table(tables[1])
  if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) {
    warning(sprintf("Empty table in summary file for game %s", game_id))
    return(NULL)
  }

  # Convert to tibble and process the shooting stats
  summary <- table_data[[1]] |>
    # Convert to tibble with temporary names
    as_tibble(.name_repair = "minimal") |>
    # Add temporary column names
    set_names(c("col1", "col2", "col3")) |>
    # Filter out rows we want
    filter(
      col1 %in%
        c("FG", "Field Goal %", "3PT", "Three Point %", "FT", "Free Throw %")
    ) |>
    # Add game_id and rename stats
    mutate(
      game_id = game_id,
      stat = case_when(
        col1 == "FG" ~ "field_goals",
        col1 == "Field Goal %" ~ "field_goal_pct",
        col1 == "3PT" ~ "three_pointers",
        col1 == "Three Point %" ~ "three_point_pct",
        col1 == "FT" ~ "free_throws",
        col1 == "Free Throw %" ~ "free_throw_pct",
        TRUE ~ col1
      )
    ) |>
    # Convert to long format for teams
    pivot_longer(
      cols = c(col2, col3),
      names_to = "team_col",
      values_to = "value"
    ) |>
    # Add team indicator
    mutate(
      team = if_else(team_col == "col2", "team_a", "team_b")
    ) |>
    # Remove unnecessary columns
    select(game_id, team, stat, value) |>
    # Convert to wide format by stat
    pivot_wider(
      names_from = stat,
      values_from = value
    ) |>
    # Clean up percentage values
    mutate(
      field_goal_pct = as.numeric(str_remove(field_goal_pct, "%")),
      three_point_pct = as.numeric(str_remove(three_point_pct, "%")),
      free_throw_pct = as.numeric(str_remove(free_throw_pct, "%"))
    )

  return(summary)
}

# Get list of all game directories
game_dirs <- dir_ls("games", type = "directory") |>
  path_file()

# Parse all games
message("Parsing play by play data...")
play_by_play_data <- map_dfr(game_dirs, parse_play_by_play)

# Count unique games in play by play data
message(sprintf(
  "Number of unique games in play by play data: %d",
  n_distinct(play_by_play_data$game_id)
))

message("Parsing box score data...")
box_score_data <- map_dfr(game_dirs, parse_box_score)

# Count unique games in box score data
message(sprintf(
  "Number of unique games in box score data: %d",
  n_distinct(box_score_data$game_id)
))

message("Parsing summary data...")
summary_data <- map_dfr(game_dirs, parse_summary)

# Count unique games in summary data
message(sprintf(
  "Number of unique games in summary data: %d",
  n_distinct(summary_data$game_id)
))

# Save the parsed data
write_feather(play_by_play_data, "unrivaled_play_by_play.feather")
write_feather(box_score_data, "unrivaled_box_scores.feather")
write_feather(summary_data, "unrivaled_summaries.feather")

message("All game data parsed and saved successfully!")

# Display samples of each dataset
message("\nSample of play by play data:")
print(
  play_by_play_data |>
    filter(game_id == first(game_id)) |>
    slice_head(n = 5)
)

message("\nSample of box score data:")
print(
  box_score_data |>
    filter(game_id == first(game_id)) |>
    slice_head(n = 5)
)

message("\nSample of summary data:")
print(
  summary_data |>
    filter(game_id == first(game_id))
)
