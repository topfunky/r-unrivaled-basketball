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
