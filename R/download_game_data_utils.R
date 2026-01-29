# Purpose: Utility functions for downloading game data from Unrivaled Basketball
# These functions are used by download_game_data.R and tested in test_download_game_data.R

#' Extract game IDs from final games in schedule HTML
#'
#' Parses schedule HTML and extracts unique game IDs only from games
#' that have a "Final" status indicator.
#'
#' @param schedule_html An rvest html_document object containing the schedule
#' @return Character vector of unique game IDs from final games
#' @export
#' @importFrom rvest html_elements html_element html_text html_attr
#' @importFrom stringr str_extract
extract_final_games <- function(schedule_html) {
  # Find all game links
  game_links <- schedule_html |>
    rvest::html_elements("a[href*='/game/']")

  final_game_ids <- character()

  for (game_link in game_links) {
    # Check if game is final (has "Final" status indicator)
    final_indicator <- game_link |>
      rvest::html_element("span.font-10.uppercase.clamp1.weight-700")

    if (is.null(final_indicator)) {
      next
    }

    final_text <- rvest::html_text(final_indicator)
    if (is.na(final_text) || trimws(final_text) != "Final") {
      # Skip games that aren't final
      next
    }

    # Extract game ID from href
    game_href <- rvest::html_attr(game_link, "href")
    game_id <- if (!is.null(game_href) && game_href != "") {
      # Extract ID from /game/{id} or /game/{id}/box-score
      id <- stringr::str_extract(game_href, "(?<=/game/)[a-z0-9]+")
      if (is.na(id)) {
        id <- stringr::str_extract(game_href, "[a-z0-9]+(?=/box-score$)")
      }
      id
    } else {
      NA_character_
    }

    if (!is.na(game_id) && game_id != "") {
      final_game_ids <- c(final_game_ids, game_id)
    }
  }

  # Return unique game IDs
  unique(final_game_ids)
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
      if (is.na(title_text) || stringr::str_detect(title_text, "Game Not Found")) {
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
