# Plan: Improving 2026 Season Data Ingest

## Goals
- Support 2026 season data without modifying cached 2025 data.
- Include new teams: **Breeze** and **Hive**.
- Organize data into year-specific subdirectories.
- Enable fetching only the current year's data.

## 1. Configuration Updates
- **Team Validation**: Update `scrape_unrivaled_scores.R` to include "Breeze" and "Hive" in `VALID_TEAMS`.
- **Season Parameters**: Ensure `scrape_unrivaled_scores.R` has correct `skip_start`, `skip_end`, and `postseason_start` for 2026.
- **Team Colors**: Add hex codes for Breeze and Hive to `team_colors.R`.

## 2. Directory Structure
Update scripts to use the following hierarchy:
- `fixtures/{year}/` - For `unrivaled_scores.csv` and `schedule.html`.
- `games/{year}/{game_id}/` - For raw `summary.html`, `box-score.html`, and `play-by-play.html`.
- `data/{year}/` - For processed CSV/Feather files (e.g., `unrivaled_play_by_play.csv`).

## 3. Data Ingest Logic (`download_game_data.R`)
- Add a `season_year` argument to the script (defaulting to 2026).
- Filter schedule parsing to only look at `fixtures/{season_year}/schedule.html`.
- Continue using `download_if_missing` to prevent redundant network requests.

## 4. Parsing and Processing (`parse_play_by_play.R`)
- Modify `process_season` to save results into `data/{season_year}/`.
- Ensure the parsing logic correctly handles the directory shift from `games/` to `games/{year}/`.
- Create a master script or Makefile target to combine years only when necessary for league-wide stats.

## 5. Backward Compatibility
- Maintain the ability to read 2025 data from its current cached location.
- Keep global files (like `team_colors.R`) updated to handle all seasons.
