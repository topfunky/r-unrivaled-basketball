# Journal

## 2026-01-24

### Refactor: Descriptive Filenames for Tasks

Renamed the generic `task01.R` through `task11.R` files to descriptive names that reflect their actual functions. This improves codebase maintainability and readability.

- `task01.R` -> `analyze_sample_rankings.R`
- `task02.R` -> `scrape_unrivaled_scores.R`
- `task03.R` -> `rankings_bump_chart.R`
- `task04.R` -> `calculate_elo_ratings.R`
- `task06.R` -> `generate_standings_table.R`
- `task07.R` -> `download_game_data.R`
- `task08.R` -> `parse_play_by_play.R`
- `task09.R` -> `model_win_probability.R`
- `task10.R` -> `analyze_shooting_metrics.R`
- `task11.R` -> `fetch_wnba_stats.R`

Updated all internal references in:
- `Makefile`
- `plan_multi_season.md`
- `analyze_shooting_metrics.R`
- `render_stats.R`
- `analyze_sample_rankings.R`

### Enhancement: Multi-Season ELO Ratings

Enhanced `calculate_elo_ratings.R` to process 2025 and 2026 seasons separately. Each season now has independent ELO calculations starting from 1500, ensuring ratings don't carry over between seasons.

Changes:
- Added season loop to process 2025 and 2026 separately
- Filter games by season column before calculating ELO ratings
- Save outputs to season-specific directories (`data/2025/` and `data/2026/`)
- Generate separate plots for each season (`plots/unrivaled_elo_ratings_2025.png` and `plots/unrivaled_elo_ratings_2026.png`)
- Dynamic plot titles include season year
- Playoff line only added for 2025 season (when applicable)
- Outputs saved in both feather and CSV formats
- Added error handling to skip seasons with no games

### Refactor: Separate 2025 and 2026 Data Processing

Implemented comprehensive separation of 2025 and 2026 season data processing across all analysis scripts. All plots and data outputs are now organized by season in year-specific subdirectories.

**Plot Directory Structure:**
- Created `plots/2025/` and `plots/2026/` subdirectories
- All plot-generating scripts now save to year-specific subdirectories
- Win probability plots saved to `plots/{season_year}/train/` and `plots/{season_year}/test/`

**Script Updates:**

1. **`render_fg_plots.R`** - Added `output_dir` parameter (default: "plots") to all plot rendering functions:
   - `render_fg_density_plot()`
   - `render_two_pt_density_plot()`
   - `render_three_pt_density_plot()`
   - `render_combined_shooting_plot()`
   - `render_ts_density_plot()`
   - `render_fga_histogram()`
   - All `ggsave()` calls now use `file.path(output_dir, filename)`

2. **`calculate_elo_ratings.R`** - Updated plot save path:
   - Changed from `plots/unrivaled_elo_ratings_{season_year}.png` to `plots/{season_year}/unrivaled_elo_ratings.png`

3. **`model_win_probability.R`** - Updated all plot save paths:
   - Calibration plots → `plots/{season_year}/calibration_train.png` and `calibration_test.png`
   - Win probability plots → `plots/{season_year}/train/` and `plots/{season_year}/test/`

4. **`rankings_bump_chart.R`** - Refactored to process seasons separately:
   - Added season loop to process 2025 and 2026 independently
   - Filters `fixtures/unrivaled_scores.csv` by season column
   - Saves plots to `plots/{season_year}/unrivaled_rankings.png`
   - Saves data to `data/{season_year}/unrivaled_rankings.feather`
   - Updates title to include season year
   - Playoff line logic is season-specific (2025 = 14 games, 2026 = TBD)

5. **`analyze_shooting_metrics.R`** - Updated to accept season parameter:
   - Accepts season as command line argument (default: 2026)
   - Reads from `data/{season_year}/unrivaled_play_by_play.feather` and `data/{season_year}/unrivaled_box_scores.feather`
   - All plot functions receive `output_dir = plots_dir` where `plots_dir = file.path("plots", season_year)`
   - Markdown output saved to `plots/{season_year}/player_stats.md`

6. **`generate_standings_table.R`** - Updated to accept season parameter:
   - Accepts season as command line argument (default: 2026)
   - Reads from `data/{season_year}/unrivaled_regular_season_standings.feather` and `data/{season_year}/unrivaled_final_elo_ratings.feather`
   - Saves output to `data/{season_year}/unrivaled_final_stats.feather`

7. **`find_winning_plays.R`** - Updated to accept season parameter:
   - Accepts season as command line argument (default: 2026)
   - Reads from `data/{season_year}/unrivaled_play_by_play.feather`
   - Filters `fixtures/unrivaled_scores.csv` by season

**Patterns Established:**
- All scripts create necessary directories before saving using `dir.create(..., showWarnings = FALSE, recursive = TRUE)`
- Consistent use of `file.path()` for cross-platform path construction
- Season parameter pattern: `args <- commandArgs(trailingOnly = TRUE); season_year <- if (length(args) > 0) as.numeric(args[1]) else 2026`
- No cross-season data contamination - each season processed independently

### Fix: Generate Season-Specific unrivaled_scores.csv Files

Fixed `scrape_unrivaled_scores.R` to generate season-specific score files at `fixtures/{year}/unrivaled_scores.csv` in addition to the combined file. This was needed for ELO calculations and other season-specific analyses.

**Issues Fixed:**
- Script was only writing to `fixtures/unrivaled_scores.csv` (combined file)
- 2026 HTML structure differs from 2025, requiring different parsing logic
- Date format for 2026 is "Jan19Mon" instead of "Friday, January 17, 2025"
- Game structure for 2026 uses different HTML selectors

**Changes Made:**
- Added logic to write season-specific files to `fixtures/{year}/unrivaled_scores.csv` for each season
- Updated date parsing to handle 2026 format ("Jan19Mon" → "Jan 19 Mon" → Date object)
- Updated game parsing to handle 2026 HTML structure (games in `a[href*='/game/']` links)
- Fixed game ID extraction for 2026 format (extract from `/game/{id}` pattern)
- Maintained backward compatibility by still writing combined file to `fixtures/unrivaled_scores.csv`
- Added season-specific selector logic for finding game days (2025 vs 2026 HTML structure)

**Result:**
- `fixtures/2026/unrivaled_scores.csv` now generated with completed games
- File includes proper game IDs, dates, teams, scores, and season_type
- ELO calculations and other analyses can now use season-specific score files

## 2026-01-25

### Fix: Game Caching for Future Games

Fixed `download_game_data.R` to prevent caching of future games that haven't occurred yet. Previously, the script would cache HTML files for all games found in the schedule, including games marked as "Final" and those scheduled but not yet played. When future games were cached, they contained "Game Not Found" content (~104-105K files), and subsequent runs would see the files exist and skip re-downloading, even if the game had since occurred.

**Changes Made:**

1. **Added `extract_final_games()` function:**
   - Parses the schedule HTML to find all game links using `a[href*='/game/']`
   - Checks for "Final" status using selector `span.font-10.uppercase.clamp1.weight-700`
   - Verifies text content equals "Final" (case-insensitive, trimmed)
   - Extracts game ID from href using regex pattern `(?<=/game/)[a-z0-9]+`
   - Returns only unique game IDs for games marked as "Final"

2. **Added `is_game_file_empty()` function:**
   - Checks if a cached HTML file exists
   - Parses the HTML and checks the title element for "Game Not Found"
   - Returns `TRUE` if the file is missing, unparseable, or contains "Game Not Found"
   - Handles errors gracefully with tryCatch

3. **Modified `download_if_missing()` function:**
   - Now checks both file existence and whether the file is empty/not-found
   - Re-downloads if the file is missing or contains "Game Not Found" content
   - Provides clear messages indicating whether it's a new download or a re-download

4. **Updated main download loop:**
   - Only processes games marked as "Final" in the schedule
   - Skips future games that haven't occurred yet
   - Provides informative messages about how many final games were found

**Result:**
- Only games marked as "Final" in the schedule are downloaded
- Cached files containing "Game Not Found" are detected and re-downloaded
- Games that were cached before they occurred are automatically re-downloaded when they become available
- Future games are not cached, preventing the issue from recurring

### Refactor: Enforce Fixtures Directory as Read-Only

Implemented plan to enforce fixtures directory as read-only for all non-test code. Moved all data writes from `fixtures/` to `data/` directory and updated dependent scripts to read from new locations.

**Test-Driven Development Approach:**

1. **Created test (`tests/testthat/test_no_fixtures_writes.R`):**
   - Scans all `.R` files outside `tests/` directory
   - Uses regex patterns to detect file write operations targeting `fixtures/` directory
   - Detects: `write_csv()`, `write_feather()`, `dir.create()`, and other write operations
   - Test initially failed (RED phase) showing 2 violations

2. **Fixed violations (GREEN phase):**
   - **`scrape_unrivaled_scores.R`**: Changed writes from `fixtures/unrivaled_scores.csv` → `data/unrivaled_scores.csv` and `fixtures/{year}/unrivaled_scores.csv` → `data/{year}/unrivaled_scores.csv`
   - **`fetch_wnba_stats.R`**: Changed write from `fixtures/wnba_shooting_stats_{season}.feather` → `data/wnba_shooting_stats_{season}.feather` and updated `dir.create()` call

3. **Updated dependent scripts to read from new locations:**
   - **`calculate_elo_ratings.R`**: Reads from `data/unrivaled_scores.csv`
   - **`rankings_bump_chart.R`**: Reads from `data/unrivaled_scores.csv`
   - **`find_winning_plays.R`**: Reads from `data/unrivaled_scores.csv`
   - **`analyze_shooting_metrics.R`**: Reads from `data/wnba_shooting_stats_2024.feather`

**Result:**
- All tests pass (8 tests, 0 failures)
- Fixtures directory is now read-only for all non-test code
- Test suite will catch any future violations automatically
- Production code writes to `data/` directory, fixtures remain for test data only

## 2026-02-01

### Fix: 2026 Schedule Scraping for Multiple HTML Layouts

Fixed the 2026 scraping pipeline to correctly parse schedule, box scores, and play-by-play data from the Unrivaled website. The website uses two different HTML layouts that needed to be handled:

1. **Compact/carousel layout** (font-10 class): Used in sidebar/carousel views
2. **Main schedule layout** (font-14 class): Used in the main schedule view

**Problem:**
- The original code only handled the compact layout, finding only 4 games
- The main schedule view uses a different HTML structure where the "Final" indicator and box-score link are siblings, not parent-child
- This resulted in only ~4 games being scraped instead of 30+ completed games

**Changes Made:**

1. **`R/download_game_data_utils.R`:**
   - Added `extract_game_id_from_href()` helper function
   - Added `extract_final_games_compact()` for carousel layout (font-10 class)
   - Added `extract_final_games_main()` for main schedule layout (font-14 class)
   - Updated `extract_final_games()` to combine results from both layouts
   - Added `should_download_game()` implementing caching policy:
     - Always download if files are missing
     - Always download if cached files contain "Game Not Found"
     - Skip download for completed games with valid cache

2. **`R/scrape_utils.R`:**
   - Added `parse_main_layout_game()` for parsing game cards from main layout
   - Added `parse_date_text()` for flexible date parsing across formats
   - Added `scrape_main_layout_games()` for the main schedule view
   - Updated `scrape_unrivaled_games()` to try main layout first, then compact

3. **`download_game_data.R`:**
   - Now fetches schedule fresh from live URL on every run
   - Uses `should_download_game()` for caching decisions
   - Reports download/skip counts for transparency

4. **`Makefile`:**
   - Changed task order: `download` now runs before `scrape`
   - Ensures fresh schedule is available before scraping scores

5. **New fixture (`fixtures/schedule_final_and_upcoming.html`):**
   - Test fixture with both completed ("Final") and upcoming games

6. **Updated tests (`tests/testthat/test_download_game_data.R`):**
   - Added tests for `should_download_game()` caching logic
   - Added tests for mixed final/upcoming schedule parsing
   - Updated expectations for fixtures matching main layout

**Result:**
- 32 final games found for 2026 season (exceeds 20+ requirement)
- Caching works correctly - skips already-cached completed games
- Both HTML layouts are handled seamlessly
- All 204 tests pass

## 2026-02-07

### Feature: Remaining Strength of Schedule

Added remaining strength of schedule calculation to the Elo pipeline. For each team at each `games_played` level, the system computes expected remaining wins by summing `elo_win_prob(my_elo, opponent_elo)` across all unplayed matchups.

**Key design decisions:**
- "Week" is defined as games played per team, not calendar time. Teams may play different numbers of games in a given weekend, so the unit of progress is simply how many games a team has completed.
- Remaining games for a team at `games_played = N` are all matchups in the full schedule after that team's Nth game.
- Teams with zero games played use the initial Elo of 1500.
- `remaining_estimated_wins` is the sum of win probabilities (not a binary > 0.5 threshold).

**New file: `R/remaining_sos.R`**
- `extract_all_schedule_games(html, season_year)` - Parses schedule HTML to extract both completed (Final) and upcoming (Scheduled) games. Handles two HTML formats: `div.color-blue` text for Final games and `img[alt*='Logo']` attributes for upcoming games where only team logos are displayed.
- `parse_schedule_card(card, game_date, s_params)` - Parses individual game cards from the main layout.
- `calculate_remaining_sos(elo_table, full_schedule)` - Computes `games_remaining` and `remaining_estimated_wins` for each team at each `games_played` count.
- `compute_expected_wins(...)` - Looks up remaining opponents and sums win probabilities using `elo_win_prob()`.

**Modified: `calculate_elo_ratings.R`**
- Added `build_elo_by_games_played()` to create per-team/per-game Elo table including `games_played = 0` rows with initial Elo of 1500.
- Added `load_full_schedule()`, `add_remaining_sos()`, `save_elo_with_sos()`, and `print_remaining_sos()`.
- `process_season()` now calculates remaining SOS and saves to `data/{year}/unrivaled_elo_with_sos.csv` and `.feather`.

**New tests: `tests/testthat/test_remaining_sos.R`** (44 tests)
- Schedule parsing with test fixture and real 2026 data: extracts all 56 games, 14 per team, correct status/team/date/game_id.
- Upcoming games correctly parsed from img alt attributes.
- SOS calculation: correct win probability sums, zero remaining when season complete, initial Elo for 0 games played, games_remaining tracking at each level.

**New fixture: `fixtures/schedule_with_upcoming_main.html`**
- Test fixture with both Final and upcoming games in the main layout format, including the logo-only HTML structure used for unplayed games.

**Result:**
- 2026 season: 56 total games (36 Final + 20 Scheduled), 14 per team
- Output verified: total estimated wins across all teams equals the number of remaining games at every `games_played` level
- All 288 tests pass (44 new + 244 existing)
