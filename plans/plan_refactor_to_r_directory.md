# Plan: Refactor Implementation R Files to R Directory

## Goal
Move all implementation R files (functions/utilities) from the root directory to the `R/` directory for easier testing and better package structure.

## Current State

### Files already in R/ directory:
- `R/download_game_data_utils.R` - utility functions for downloading game data
- `R/elo_win_prob.R` - ELO win probability calculation
- `R/extract_game_ids.R` - game ID extraction from schedule
- `R/team_colors.R` - team color definitions

### Root-level R files to categorize:

**Implementation files (contain reusable functions - should move to R/):**
1. `team_colors.R` - Already duplicated in R/, root version can be deleted
2. `elo_win_prob.R` - Already duplicated in R/, root version can be deleted  
3. `calibration.R` - Contains `create_calibration_plot()` function
4. `render_fg_plots.R` - Contains multiple rendering functions
5. `render_stats.R` - Contains markdown rendering functions
6. `render_wp_plots.R` - Contains win probability plot functions

**Script files (executable scripts - should stay at root):**
1. `scrape_unrivaled_scores.R` - Main scraping script with execution code
2. `parse_play_by_play.R` - Main parsing script with execution code
3. `generate_standings_table.R` - Script that generates standings
4. `find_winning_plays.R` - Script for analysis
5. `model_win_probability.R` - Script that trains models
6. `rankings_bump_chart.R` - Script that generates charts
7. `analyze_sample_rankings.R` - Exploratory analysis script
8. `install_dependencies.R` - Setup script

## Implementation Steps

### Step 1: Delete duplicate root files
- Delete `team_colors.R` (root) - already exists in R/
- Delete `elo_win_prob.R` (root) - already exists in R/

### Step 2: Move implementation files to R/
- Move `calibration.R` → `R/calibration.R`
- Move `render_fg_plots.R` → `R/render_fg_plots.R`
- Move `render_stats.R` → `R/render_stats.R`
- Move `render_wp_plots.R` → `R/render_wp_plots.R`

### Step 3: Extract functions from scripts to R/
Several scripts contain both reusable functions and execution code. Extract functions:

From `scrape_unrivaled_scores.R`:
- `extract_game_ids()` - Already in R/extract_game_ids.R
- `scrape_unrivaled_games()` - Move to R/scrape_utils.R
- `parse_game_day()` - Move to R/scrape_utils.R (nested, may need refactoring)

From `parse_play_by_play.R`:
- `parse_play_by_play()` - Move to R/parse_utils.R
- `parse_box_score()` - Move to R/parse_utils.R
- `parse_summary()` - Move to R/parse_utils.R
- `process_season()` - Move to R/parse_utils.R

### Step 4: Update source() calls in scripts
Scripts that use `source()` need to be updated to reference the new locations:
- `model_win_probability.R` - sources `calibration.R` and `render_wp_plots.R`
- `render_fg_plots.R` - sources `team_colors.R`
- `rankings_bump_chart.R` - sources `team_colors.R`

### Step 5: Update tests/testthat.R
The test runner already sources from `R/` directory, so it should work after the move.

## Files After Refactoring

### R/ directory (implementation):
- `R/calibration.R`
- `R/download_game_data_utils.R`
- `R/elo_win_prob.R`
- `R/extract_game_ids.R`
- `R/parse_utils.R` (new - extracted from parse_play_by_play.R)
- `R/render_fg_plots.R`
- `R/render_stats.R`
- `R/render_wp_plots.R`
- `R/scrape_utils.R` (new - extracted from scrape_unrivaled_scores.R)
- `R/team_colors.R`

### Root directory (scripts):
- `analyze_sample_rankings.R`
- `find_winning_plays.R`
- `generate_standings_table.R`
- `install_dependencies.R`
- `model_win_probability.R`
- `parse_play_by_play.R` (simplified - just execution code)
- `rankings_bump_chart.R`
- `scrape_unrivaled_scores.R` (simplified - just execution code)
