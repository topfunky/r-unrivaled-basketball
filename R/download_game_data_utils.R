# Purpose: Utility functions for downloading game data from Unrivaled Basketball
# These functions are used by download_game_data.R and tested in test_download_game_data.R

#' Extract game ID from href attribute
#'
#' @param game_href The href attribute value
#' @return Game ID string or NA_character_
extract_game_id_from_href <- function(game_href) {
  if (is.null(game_href) || is.na(game_href) || game_href == "") {
    return(NA_character_)
  }
  # Extract ID from /game/{id} or /game/{id}/box-score
  id <- stringr::str_extract(game_href, "(?<=/game/)[a-z0-9]+")
  if (is.na(id)) {
    id <- stringr::str_extract(game_href, "[a-z0-9]+(?=/box-score$)")
  }
  id
}

#' Extract game IDs from final games using compact layout
#'
#' Handles the compact/carousel layout where Final indicator is inside the
#' game link element (font-10 class).
#'
#' @param schedule_html An rvest html_document object
#' @return Character vector of game IDs
extract_final_games_compact <- function(schedule_html) {
  game_links <- schedule_html |>
    rvest::html_elements("a[href*='/game/']")

  final_game_ids <- character()

  for (game_link in game_links) {
    # Check for compact layout Final indicator (font-10 class)
    final_indicator <- game_link |>
      rvest::html_element("span.font-10.uppercase.clamp1.weight-700")

    if (is.null(final_indicator)) {
      next
    }

    final_text <- rvest::html_text(final_indicator)
    if (is.na(final_text) || trimws(final_text) != "Final") {
      next
    }

    game_href <- rvest::html_attr(game_link, "href")
    game_id <- extract_game_id_from_href(game_href)

    if (!is.na(game_id) && game_id != "") {
      final_game_ids <- c(final_game_ids, game_id)
    }
  }

  final_game_ids
}

#' Extract game IDs from final games using main schedule layout
#'
#' Handles the main schedule layout where Final indicator (font-14 class)
#' and box-score link are siblings within a game container.
#'
#' @param schedule_html An rvest html_document object
#' @return Character vector of game IDs
extract_final_games_main <- function(schedule_html) {
  # Find game containers with the radius-8 class (main schedule cards)
  game_containers <- schedule_html |>
    rvest::html_elements("div.flex.w-100.radius-8")

  final_game_ids <- character()

  for (container in game_containers) {
    # Check for main layout Final indicator (font-14 class)
    final_indicator <- container |>
      rvest::html_element("span.uppercase.weight-500.font-14")

    if (is.null(final_indicator)) {
      next
    }

    final_text <- rvest::html_text(final_indicator)
    if (is.na(final_text) || trimws(final_text) != "Final") {
      next
    }

    # Find box-score link within the same container
    box_score_link <- container |>
      rvest::html_element("a[href*='/game/'][href*='/box-score']")

    if (is.null(box_score_link)) {
      next
    }

    game_href <- rvest::html_attr(box_score_link, "href")
    game_id <- extract_game_id_from_href(game_href)

    if (!is.na(game_id) && game_id != "") {
      final_game_ids <- c(final_game_ids, game_id)
    }
  }

  final_game_ids
}

#' Extract game IDs from final games in schedule HTML
#'
#' Parses schedule HTML and extracts unique game IDs only from games
#' that have a "Final" status indicator. Handles both compact (carousel)
#' and main schedule layouts.
#'
#' @param schedule_html An rvest html_document object containing the schedule
#' @return Character vector of unique game IDs from final games
#' @export
#' @importFrom rvest html_elements html_element html_text html_attr
#' @importFrom stringr str_extract
extract_final_games <- function(schedule_html) {
  # Extract from both layouts and combine
  compact_ids <- extract_final_games_compact(schedule_html)
  main_ids <- extract_final_games_main(schedule_html)

  # Return unique game IDs from both sources
  unique(c(compact_ids, main_ids))
}

#' Determine if a game should be downloaded based on cache policy
#'
#' Implements the caching rubric:
#' - Always download if game files are missing
#' - Always download if cached files contain "Game Not Found"
#' - Skip download for completed (final) games with valid cached content
#' - Always re-download non-final games to check for completion
#'
#' @param game_id The game ID
#' @param game_dir Path to the game's cache directory
#' @param is_game_final TRUE if the game is marked as Final in the schedule
#' @return TRUE if the game should be downloaded, FALSE otherwise
#' @export
should_download_game <- function(game_id, game_dir, is_game_final) {
  box_score_file <- file.path(game_dir, "box-score.html")

  # Always download if files are missing
  if (!fs::file_exists(box_score_file)) {
    return(TRUE)
  }

  # Always download if cached content is invalid (Game Not Found)
  if (is_game_file_empty(box_score_file)) {
    return(TRUE)
  }

  # For final games with valid cache, skip download
  if (is_game_final) {
    return(FALSE)
  }

  # Non-final games should be re-downloaded to check for updates
  TRUE
}

#' Check if cached HTML game file is empty or contains "Game Not Found"
#'
#' Determines if a cached game HTML file should be re-downloaded by checking
#' if the file exists and has valid content (not a "Game Not Found" page).
#'
#' @param filepath Path to the HTML file to check
#' @return TRUE if file is missing, empty, or contains "Game Not Found"; FALSE otherwise
#' @export
#' @importFrom rvest read_html html_element html_text
#' @importFrom fs file_exists
#' @importFrom stringr str_detect
is_game_file_empty <- function(filepath) {
  if (!fs::file_exists(filepath)) {
    return(TRUE)
  }

  tryCatch(
    {
      # Read and parse the HTML file
      html <- rvest::read_html(filepath)
      title_element <- rvest::html_element(html, "title")
      if (is.null(title_element)) {
        return(TRUE)
      }
      title_text <- rvest::html_text(title_element)
      # Check if title contains "Game Not Found"
      if (
        is.na(title_text) || stringr::str_detect(title_text, "Game Not Found")
      ) {
        return(TRUE)
      }
      return(FALSE)
    },
    error = function(e) {
      # If we can't parse the file, treat it as empty
      return(TRUE)
    }
  )
}
