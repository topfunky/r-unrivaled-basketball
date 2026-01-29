# Plan: Convert Project to R Package Structure

## Goal
Convert this project from a collection of standalone R scripts to a proper R package structure so that `covr::package_coverage()` can run successfully.

## Current State
- Project has standalone R scripts in the root directory
- Tests exist in `tests/testthat/` but use `source()` to load functions
- No `DESCRIPTION` file or `NAMESPACE` file
- No `R/` directory for package functions

## Implementation Steps

### 1. Create DESCRIPTION file
Create a `DESCRIPTION` file with package metadata including:
- Package name: `unrivaled`
- Dependencies (Imports): tidyverse, rvest, lubridate, glue, testthat
- Suggests: covr

### 2. Create R/ directory and move reusable functions
Extract reusable functions from scripts into `R/` directory:
- `R/extract_game_ids.R` - from `scrape_unrivaled_scores.R`
- `R/scrape_unrivaled_games.R` - from `scrape_unrivaled_scores.R`
- `R/team_colors.R` - from `team_colors.R`
- `R/elo_win_prob.R` - from `elo_win_prob.R`

### 3. Create NAMESPACE file
Create a `NAMESPACE` file that exports the package functions.

### 4. Update test files
- Update `tests/testthat.R` to use standard package test runner format
- Update test files to use `library(unrivaled)` instead of `source()`

### 5. Update original scripts
- Update scripts to use `library(unrivaled)` or keep them as standalone executables that source from `R/`

### 6. Verify coverage works
Run `make coverage` to verify the package structure is correct.

## Files to Create
- `DESCRIPTION`
- `NAMESPACE`
- `R/extract_game_ids.R`
- `R/scrape_unrivaled_games.R`
- `R/team_colors.R`
- `R/elo_win_prob.R`

## Files to Modify
- `tests/testthat.R`
- `tests/testthat/test_schedule_parsing.R`
- `scrape_unrivaled_scores.R` (to source from R/ or use library)

## Notes
- Keep the original scripts functional as entry points
- The `R/` directory functions should be pure functions without side effects
- Script execution code (file I/O, main logic) stays in the root scripts
