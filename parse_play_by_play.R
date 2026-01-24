# Purpose: Parses play by play data from downloaded game files.

# Load required libraries
library(tidyverse)
library(rvest)
library(fs)
library(feather)

# Function to parse play by play data
parse_play_by_play <- function(game_id, season_year) {
  # Read the play by play HTML file
  play_by_play_file <- path("games", season_year, game_id, "play-by-play.html")
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

  # Extract possessing team from image alt text
  play_cells <- html |> html_nodes("td:nth-child(2)") # Get play description cells
  pos_teams <- map_chr(play_cells, function(cell) {
    # Team associated with the play is mentioned in the image alt text
    img <- html_node(cell, "img")
    if (!is.null(img)) {
      alt_text <- html_attr(img, "alt")
      if (!is.na(alt_text) && str_detect(alt_text, "Logo$")) {
        return(str_remove(alt_text, " Logo$"))
      }
    }
    return(NA_character_)
  })

  # Convert to tibble and set names
  plays <- table_data[[1]] |>
    as_tibble() |>
    set_names(c("time", "play", "score")) |>
    mutate(
      game_id = game_id,
      season = season_year,
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
      ),
      # Add possessing team from image alt text
      pos_team = pos_teams
    ) |>
    # Reorder columns
    select(
      game_id,
      season,
      quarter,
      time,
      minute,
      second,
      play,
      pos_team,
      away_score,
      home_score
    )

  return(plays)
}

# Function to parse box score data
parse_box_score <- function(game_id, season_year) {
  # Read the box score HTML file
  box_score_file <- path("games", season_year, game_id, "box-score.html")
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
      season = season_year,
      # Convert MIN to character to ensure consistent type across all games
      MIN = as.character(MIN),
      # Add starter flag and clean player names
      is_starter = str_starts(PLAYERS, "S "),
      player_name_raw = if_else(is_starter, str_remove(PLAYERS, "^S "), PLAYERS)
    ) |>
    # Filter out rows with blank player names or "TEAM" rows
    filter(
      !is.na(player_name_raw),
      str_trim(player_name_raw) != "",
      str_trim(player_name_raw) != "TEAM"
    ) |>
    # Split player name and jersey number
    mutate(
      # Extract jersey number if present (format: "Name #XX")
      jersey_number = as.numeric(str_extract(player_name_raw, "(?<=#)\\d+$")),
      # Remove jersey number from player name
      player_name = str_remove(player_name_raw, " #\\d+$")
    ) |>
    # Split shooting stats into made and attempted
    mutate(
      # Use field names from wehoop
      field_goals_made = as.numeric(str_extract(FG, "^\\d+")),
      field_goals_attempted = as.numeric(str_extract(FG, "\\d+$")),
      three_point_field_goals_made = as.numeric(str_extract(`3PT`, "^\\d+")),
      three_point_field_goals_attempted = as.numeric(str_extract(
        `3PT`,
        "\\d+$"
      )),
      free_throws_made = as.numeric(str_extract(FT, "^\\d+")),
      free_throws_attempted = as.numeric(str_extract(FT, "\\d+$")),
      # Calculate two-point field goals
      two_point_field_goals_made = field_goals_made -
        three_point_field_goals_made,
      two_point_field_goals_attempted = field_goals_attempted -
        three_point_field_goals_attempted,
      # Convert numeric columns to ensure consistent types across all games
      across(
        c(REB, OREB, DREB, AST, STL, BLK, TO, PF, PTS),
        ~ as.numeric(.)
      )
    ) |>
    # Reorder columns to put new columns first
    select(
      game_id,
      season,
      is_starter,
      player_name,
      jersey_number,
      MIN,
      field_goals_made,
      field_goals_attempted,
      three_point_field_goals_made,
      three_point_field_goals_attempted,
      free_throws_made,
      free_throws_attempted,
      two_point_field_goals_made,
      two_point_field_goals_attempted,
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
parse_summary <- function(game_id, season_year) {
  # Read the summary HTML file
  summary_file <- path("games", season_year, game_id, "summary.html")
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
      season = season_year,
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
    select(game_id, season, team, stat, value) |>
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

# Function to process a season
process_season <- function(season_year) {
  season_dir <- path("games", season_year)
  if (!dir_exists(season_dir)) {
    return(NULL)
  }

  game_dirs <- dir_ls(season_dir, type = "directory") |>
    path_file()

  list(
    play_by_play = map_dfr(game_dirs, ~ parse_play_by_play(.x, season_year)),
    box_score = map_dfr(game_dirs, ~ parse_box_score(.x, season_year)),
    summary = map_dfr(game_dirs, ~ parse_summary(.x, season_year))
  )
}

# Process all seasons
seasons <- c(2025, 2026)
all_data <- map(seasons, process_season) |> compact()

# Create data subdirectories if they don't exist
for (season_year in seasons) {
  data_dir <- path("data", season_year)
  if (!dir_exists(data_dir)) {
    dir_create(data_dir)
  }
}

# Process and save each season separately
for (i in seq_along(all_data)) {
  season_year <- seasons[i]
  season_data <- all_data[[i]]
  
  data_dir <- path("data", season_year)
  
  write_feather(
    season_data$play_by_play,
    path(data_dir, "unrivaled_play_by_play.feather")
  )
  write_feather(
    season_data$box_score,
    path(data_dir, "unrivaled_box_scores.feather")
  )
  write_feather(
    season_data$summary,
    path(data_dir, "unrivaled_summaries.feather")
  )
  
  # Also save CSV versions in the same directory
  write_csv(
    season_data$play_by_play,
    path(data_dir, "unrivaled_play_by_play.csv")
  )
  write_csv(
    season_data$box_score,
    path(data_dir, "unrivaled_box_scores.csv")
  )
  write_csv(
    season_data$summary,
    path(data_dir, "unrivaled_summaries.csv")
  )
}

# Combine all seasons for global files (legacy support)
play_by_play_data <- map_dfr(all_data, ~ .x$play_by_play)
box_score_data <- map_dfr(all_data, ~ .x$box_score)
summary_data <- map_dfr(all_data, ~ .x$summary)

# Save the combined parsed data to root data directory (legacy support)
write_feather(play_by_play_data, "data/unrivaled_play_by_play.feather")
write_feather(box_score_data, "data/unrivaled_box_scores.feather")
write_feather(summary_data, "data/unrivaled_summaries.feather")

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
