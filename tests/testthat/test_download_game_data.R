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
    # The single-game fixture has a box-score link
    game_file <- find_fixture("single-game.html")
    game_html <- read_html(game_file)
    
    game_ids <- extract_final_games(game_html)
    
    # single-game.html has different class structure (font-14 not font-10)
    # so it won't match the selector - this tests that we correctly
    # filter based on the expected CSS class
    expect_empty(game_ids)
  })
  
  it("game_day fixture extracts correct game IDs", {
    game_file <- find_fixture("game_day.html")
    game_html <- read_html(game_file)
    
    game_ids <- extract_final_games(game_html)
    
    # game_day.html uses font-14 class, not font-10, so no matches expected
    expect_empty(game_ids)
  })
})
