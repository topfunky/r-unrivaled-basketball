#' Extract game IDs from schedule HTML file
#'
#' Parses an Unrivaled schedule HTML file and extracts unique game IDs
#' from game links.
#'
#' @param schedule_file Path to the schedule HTML file
#' @param season_year The season year (used for validation)
#' @return Character vector of unique game IDs
#' @export
#' @importFrom rvest read_html html_elements html_attr
#' @importFrom purrr map_chr
#' @importFrom stringr str_extract
#' @importFrom glue glue
extract_game_ids <- function(schedule_file, season_year = 2026) {
  if (!file.exists(schedule_file)) {
    stop(glue::glue("Schedule file {schedule_file} not found"))
  }

  html <- rvest::read_html(schedule_file)

  game_links <- html |>
    rvest::html_elements("a[href*='/game/']")

  game_ids <- purrr::map_chr(
    game_links,
    ~ {
      href <- rvest::html_attr(.x, "href")
      if (is.na(href) || is.null(href)) {
        return(NA_character_)
      }
      id <- stringr::str_extract(href, "(?<=/game/)[a-z0-9]+")
      if (is.na(id)) {
        return(NA_character_)
      }
      id
    }
  )

  game_ids <- game_ids[!is.na(game_ids)]
  unique(game_ids)
}
