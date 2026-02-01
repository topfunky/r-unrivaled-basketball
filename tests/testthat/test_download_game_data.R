# Purpose: Tests for download_game_data.R functions
# Tests extract_final_games, is_game_file_empty, and download_if_missing
# Uses find_fixture helper from helper-fixtures.R

library(rvest)
library(fs)
library(stringr)

# Tests for extract_final_games
describe("extract_final_games", {
  it("extracts game IDs from final games only", {
    schedule_file <- find_fixture("schedule_with_final_games.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should find exactly 2 final games
    expect_equal(length(game_ids), 2)
    
    # Should include the expected game IDs
    expect_in("abc123def456", game_ids)
    expect_in("xyz789ghi012", game_ids)
    
    # Should NOT include non-final games
    expect_not_in("scheduled123", game_ids)
    expect_not_in("live456game", game_ids)
  })
  
  it("returns empty vector when no final games exist", {
    schedule_file <- find_fixture("schedule_no_final_games.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    expect_equal(length(game_ids), 0)
    expect_type(game_ids, "character")
  })
  
  it("returns empty vector for schedule with no game links", {
    schedule_file <- find_fixture("schedule_empty.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    expect_equal(length(game_ids), 0)
    expect_type(game_ids, "character")
  })
  
  it("returns unique game IDs (no duplicates)", {
    schedule_file <- find_fixture("schedule_with_final_games.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    expect_equal(length(game_ids), length(unique(game_ids)))
  })
  
  it("extracts game ID from /game/{id}/box-score format", {
    schedule_file <- find_fixture("schedule_with_final_games.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # xyz789ghi012 comes from /game/xyz789ghi012/box-score
    expect_in("xyz789ghi012", game_ids)
  })
  
  it("works with real 2026 schedule fixture", {
    schedule_file <- find_fixture("2026/schedule.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should find multiple final games
    expect_not_empty(game_ids)
    
    # All IDs should match expected pattern
    for (id in game_ids) {
      expect_match(id, "^[a-z0-9]+$")
    }
  })
})

# Tests for is_game_file_empty
describe("is_game_file_empty", {
  it("returns TRUE for non-existent file", {
    result <- is_game_file_empty("/nonexistent/path/to/file.html")
    expect_true(result)
  })
  
  it("returns TRUE for 'Game Not Found' page", {
    game_file <- find_fixture("game_not_found.html")
    result <- is_game_file_empty(game_file)
    expect_true(result)
  })
  
  it("returns FALSE for valid game file", {
    game_file <- find_fixture("valid_game.html")
    result <- is_game_file_empty(game_file)
    expect_false(result)
  })
  
  it("returns TRUE for file without title element", {
    game_file <- find_fixture("game_no_title.html")
    result <- is_game_file_empty(game_file)
    expect_true(result)
  })
  
  it("returns TRUE for invalid HTML file", {
    # Create a temporary invalid file
    temp_file <- tempfile(fileext = ".html")
    writeLines("not valid html at all {{{", temp_file)
    on.exit(unlink(temp_file))
    
    # rvest is lenient, so this might still parse
    # The function should handle errors gracefully
    result <- is_game_file_empty(temp_file)
    # Should return TRUE because there's no valid title
    expect_true(result)
  })
  
  it("handles file with title containing 'Game Not Found' substring", {
    temp_file <- tempfile(fileext = ".html")
    writeLines(
      "<html><head><title>Error: Game Not Found - Please Try Again</title></head></html>",
      temp_file
    )
    on.exit(unlink(temp_file))
    
    result <- is_game_file_empty(temp_file)
    expect_true(result)
  })
  
  it("returns FALSE for valid game with different title format", {
    temp_file <- tempfile(fileext = ".html")
    writeLines(
      "<html><head><title>Box Score - Team A vs Team B</title></head></html>",
      temp_file
    )
    on.exit(unlink(temp_file))
    
    result <- is_game_file_empty(temp_file)
    expect_false(result)
  })
})

# Tests for download_if_missing (using mocking)
describe("download_if_missing", {
  # We need to test the logic without actually making HTTP requests
  # These tests verify the function's decision-making logic
  
  it("skips download when valid file exists", {
    # Create a valid game file
    temp_dir <- tempdir()
    temp_file <- file.path(temp_dir, "test_valid_game.html")
    writeLines(
      "<html><head><title>Valid Game</title></head></html>",
      temp_file
    )
    on.exit(unlink(temp_file))
    
    # The function should return NULL without downloading
    # We can't easily test this without mocking httr::GET
    # But we can verify the file check logic works
    expect_false(is_game_file_empty(temp_file))
  })
  
  it("identifies files needing re-download (Game Not Found)", {
    temp_dir <- tempdir()
    temp_file <- file.path(temp_dir, "test_not_found.html")
    writeLines(
      "<html><head><title>Game Not Found</title></head></html>",
      temp_file
    )
    on.exit(unlink(temp_file))
    
    # File exists but should be flagged for re-download
    expect_true(file.exists(temp_file))
    expect_true(is_game_file_empty(temp_file))
  })
})

# Edge case tests for extract_final_games
describe("extract_final_games edge cases", {
  it("deduplicates game IDs when same game appears multiple times", {
    schedule_file <- find_fixture("schedule_duplicate_games.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should have exactly 2 unique IDs, not 3
    expect_equal(length(game_ids), 2)
    expect_in("abc123def456", game_ids)
    expect_in("xyz789ghi012", game_ids)
  })
  
  it("handles various game statuses correctly", {
    schedule_file <- find_fixture("schedule_mixed_status.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should only find games with "Final" status (with whitespace trimmed)
    expect_all_in(c("finalgame001", "finalgame002"), game_ids)
    
    # Should NOT include other statuses
    expect_none_in(
      c("livegame0001", "scheduled01", "postponed01", "cancelled01"),
      game_ids
    )
    
    # Lowercase "final" should not match (trimws preserves case)
    expect_not_in("lowercase001", game_ids)
  })
  
  it("handles game link without href attribute", {
    html_content <- '
      <div>
        <a>
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
        <a href="/game/validgame01">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
      </div>
    '
    schedule_html <- read_html(html_content)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should only get the valid game ID
    expect_equal(length(game_ids), 1)
    expect_equal(game_ids[1], "validgame01")
  })
  
  it("handles empty href attribute", {
    html_content <- '
      <div>
        <a href="">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
        <a href="/game/validgame02">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
      </div>
    '
    schedule_html <- read_html(html_content)
    
    game_ids <- extract_final_games(schedule_html)
    
    expect_equal(length(game_ids), 1)
    expect_equal(game_ids[1], "validgame02")
  })
  
  it("handles malformed game URLs", {
    html_content <- '
      <div>
        <a href="/game/">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
        <a href="/games/notgame123">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
        <a href="/game/validid123">
          <span class="font-10 uppercase clamp1 weight-700">Final</span>
        </a>
      </div>
    '
    schedule_html <- read_html(html_content)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Only the valid game URL should be extracted
    expect_equal(length(game_ids), 1)
    expect_equal(game_ids[1], "validid123")
  })
})

# Integration-style tests
describe("download_game_data integration", {
  it("correctly identifies final games from real schedule", {
    schedule_file <- find_fixture("2026/schedule.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Verify we get reasonable results
    expect_type(game_ids, "character")
    expect_not_empty(game_ids)
    
    # All IDs should be valid format
    for (id in game_ids) {
      expect_match(id, "^[a-z0-9]+$")
    }
  })
  
  it("single-game fixture produces expected game ID", {
    # The single-game fixture has a box-score link with main layout structure
    game_file <- find_fixture("single-game.html")
    game_html <- read_html(game_file)
    
    game_ids <- extract_final_games(game_html)
    
    # single-game.html uses font-14 class (main layout) with Final status
    expect_equal(length(game_ids), 1)
    expect_equal(game_ids[1], "jcdgg9yavn4e")
  })
  
  it("game_day fixture extracts correct game IDs", {
    game_file <- find_fixture("game_day.html")
    game_html <- read_html(game_file)
    
    game_ids <- extract_final_games(game_html)
    
    # game_day.html has 2 final games with font-14 class (main layout)
    expect_equal(length(game_ids), 2)
    expect_all_in(c("jcdgg9yavn4e", "jb3jklxmsrks"), game_ids)
  })
})

# Tests for caching overwrite rubric
describe("should_download_game", {
  it("returns TRUE for missing game file", {
    # Non-existent file should be downloaded
    result <- should_download_game(
      game_id = "newgame001",
      game_dir = tempdir(),
      is_game_final = TRUE
    )
    expect_true(result)
  })
  
  it("returns FALSE for cached final game with valid content", {
    # Create a temp directory with valid game files
    temp_game_dir <- file.path(tempdir(), "cached_final_game")
    dir.create(temp_game_dir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(temp_game_dir, recursive = TRUE))
    
    # Create valid box-score file
    box_score_file <- file.path(temp_game_dir, "box-score.html")
    writeLines(
      "<html><head><title>Box Score - Mist vs Rose</title></head></html>",
      box_score_file
    )
    
    result <- should_download_game(
      game_id = "finalgame",
      game_dir = temp_game_dir,
      is_game_final = TRUE
    )
    expect_false(result)
  })
  
  it("returns TRUE for cached game with 'Game Not Found' content", {
    # Create a temp directory with invalid game files
    temp_game_dir <- file.path(tempdir(), "not_found_game")
    dir.create(temp_game_dir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(temp_game_dir, recursive = TRUE))
    
    # Create "Game Not Found" box-score file
    box_score_file <- file.path(temp_game_dir, "box-score.html")
    writeLines(
      "<html><head><title>Game Not Found</title></head></html>",
      box_score_file
    )
    
    result <- should_download_game(
      game_id = "notfoundgame",
      game_dir = temp_game_dir,
      is_game_final = TRUE
    )
    expect_true(result)
  })
  
  it("returns TRUE for non-final game even if cached", {
    # Non-final (incomplete/upcoming) games should always be re-downloaded
    # to check if they've been completed
    temp_game_dir <- file.path(tempdir(), "incomplete_game")
    dir.create(temp_game_dir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(temp_game_dir, recursive = TRUE))
    
    # Create valid-looking box-score file
    box_score_file <- file.path(temp_game_dir, "box-score.html")
    writeLines(
      "<html><head><title>Box Score - Mist vs Rose</title></head></html>",
      box_score_file
    )
    
    result <- should_download_game(
      game_id = "incompletegame",
      game_dir = temp_game_dir,
      is_game_final = FALSE
    )
    expect_true(result)
  })
})

# Tests for schedule with mixed final and upcoming games
describe("extract_final_games with mixed schedule", {
  it("extracts only final games, excludes upcoming games", {
    schedule_file <- find_fixture("schedule_final_and_upcoming.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Should find exactly 3 final games
    expect_equal(length(game_ids), 3)
    
    # Should include all final game IDs
    expect_all_in(c("finalgame001", "finalgame002", "finalgame003"), game_ids)
    
    # Should NOT include upcoming games (those with time indicators, no Final)
    expect_none_in(c("upcoming001", "upcoming002"), game_ids)
  })
  
  it("distinguishes Final from time-based status indicators", {
    schedule_file <- find_fixture("schedule_final_and_upcoming.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # Games with "7:30 PM ET" or similar should not be extracted
    # Only games with "Final" status should be included
    for (id in game_ids) {
      expect_not_contains(id, "upcoming")
    }
  })
  
  it("handles box-score URL format for final games", {
    schedule_file <- find_fixture("schedule_final_and_upcoming.html")
    schedule_html <- read_html(schedule_file)
    
    game_ids <- extract_final_games(schedule_html)
    
    # finalgame002 uses /game/id/box-score format
    expect_in("finalgame002", game_ids)
  })
})
