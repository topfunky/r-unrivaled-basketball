# Plan: Multi-Season Scraper Improvement (2025-2026)

This plan outlines the steps to upgrade the current Unrivaled Basketball scraper to support the 2026 season while maintaining and categorizing the 2025 data.

## 1. Data Structure Updates
- **Global Season Identifier**: Add a `season` column (integer ) to all core data frames:
  - `unrivaled_scores.csv`
  - `unrivaled_play_by_play.feather`
  - `unrivaled_box_scores.feather`
  - `unrivaled_summaries.feather`
- **File Organization**: 
  - Move current `games/` subdirectories to `games/2025/`.
  - Create `games/2026/` for upcoming season downloads.
  - Update `fixtures/` to include season-specific files if necessary (e.g., `fixtures/2025/schedule.html`).

## 2. Scraper Logic Refactoring (`scrape_unrivaled_scores.R`)
- **Parameterize `scrape_unrivaled_games`**: Update the function to accept a `season` year.
- **Dynamic URL/Path Handling**: Use the `season` parameter to determine which local fixture or remote URL to hit.
- **Season Validation**: Update `VALID_TEAMS` if new teams are added in 2026 or if team names change.
- **Date Range Handling**: Parameterize `SKIP_START`, `SKIP_END`, and `POSTSEASON_START` so they are specific to the requested season.

## 3. Data Processing Pipeline (`parse_play_by_play.R`)
- **Directory Traversal**: Update `game_dirs` logic to iterate through season-specific folders (e.g., `games/2025/*` and `games/2026/*`).
- **Map-Reduce with Season Tagging**: Ensure `parse_play_by_play`, `parse_box_score`, and `parse_summary` include a `season` column in their output tibbles.
- **Aggregated Storage**: Ensure the final `.feather` and `.csv` exports contain the combined data from all seasons, allowing easy filtering by the `season` column.

## 4. Downstream Analysis & Visualization
- **Filtering**: Update analysis scripts (`analyze_sample_rankings.R`, `render_stats.R`, etc.) to filter for a specific season or group by season when performing comparisons.
- **Comparison Plots**: Create new visualizations that compare 2025 vs 2026 performance metrics (e.g., league-wide FG% trends).

## 5. Execution Steps
1. **Migration**: Move existing 2025 HTML files into season-specific directories.
2. **Schema Update**: Run a one-time script to add `season = 2025` to existing data files.
3. **Refactor**: Apply the parameterization changes to `scrape_unrivaled_scores.R` and `parse_play_by_play.R`.
4. **Validation**: Run the updated scraper for 2025 and verify it still produces identical results (plus the new season column).
5. **2026 Setup**: Initialize 2026 fixtures and test the scraper against the first 2026 data points.
