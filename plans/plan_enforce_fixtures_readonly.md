# Plan: Enforce Fixtures Directory as Read-Only for Non-Test Code

## Overview

Refactor codebase to ensure fixtures directory is read-only for all non-test code. Move all writes from fixtures to appropriate data directories, update dependent scripts, and use TDD to verify no non-test code writes to fixtures.

## Current State

### Files that WRITE to `data` and `games`:
- `scrape_unrivaled_scores.R` → writes `data/unrivaled_scores.csv` and `data/{year}/unrivaled_scores.csv`
- `fetch_wnba_stats.R` → writes `data/{year}/wnba_shooting_stats_{season}.feather`
- Other scripts write raw game HTML to `games/{year}/`
- `calculate_elo_ratings.R` → reads `data/unrivaled_scores.csv`
- `rankings_bump_chart.R` → reads `data/unrivaled_scores.csv`
- `find_winning_plays.R` → reads `data/unrivaled_scores.csv`
- `analyze_shooting_metrics.R` → reads `data/wnba_shooting_stats_2024.feather`
- `download_game_data.R` → reads `games/{year}/schedule.html` 
- `scrape_unrivaled_scores.R` → reads `games/{year}/schedule.html` 
- `tests/testthat/test_schedule_parsing.R` → reads `games/2026/schedule.html` 

## Implementation Plan

### Phase 1: RED - Create Test to Detect Fixtures Writes

1. Create `tests/testthat/test_no_fixtures_writes.R`
   - Test scans all `.R` files outside `tests/` directory
   - Uses regex to detect file write operations targeting `fixtures/` directory
   - Detects: `write_csv(.*fixtures`, `write_feather(.*fixtures`, `dir.create(.*fixtures`, etc.
   - Test should FAIL initially (RED) showing current violations

### Phase 2: GREEN - Move Writes and Update Dependencies

2. **Update `scrape_unrivaled_scores.R`:**
   - Change writes from `fixtures/unrivaled_scores.csv` → `data/unrivaled_scores.csv`
   - Change writes from `fixtures/{year}/unrivaled_scores.csv` → `data/{year}/unrivaled_scores.csv`
   - Keep reading from `fixtures/{year}/schedule.html` (manually added)

3. **Update `fetch_wnba_stats.R`:**
   - Change write from `fixtures/wnba_shooting_stats_{season}.feather` → `data/{year}/wnba_shooting_stats_{season}.feather`
   - Remove `dir.create("fixtures", ...)` call

4. **Update dependent scripts to read from new locations:**
   - `calculate_elo_ratings.R`: `fixtures/unrivaled_scores.csv` → `data/unrivaled_scores.csv`
   - `rankings_bump_chart.R`: `fixtures/unrivaled_scores.csv` → `data/unrivaled_scores.csv`
   - `find_winning_plays.R`: `fixtures/unrivaled_scores.csv` → `data/unrivaled_scores.csv`
   - `analyze_shooting_metrics.R`: `fixtures/wnba_shooting_stats_2024.feather` → `data/wnba_shooting_stats_2024.feather`

### Phase 3: REFACTOR - Verify and Clean Up

5. Run test suite to verify test passes (GREEN)
6. Verify all scripts still function correctly
7. Update any documentation/comments referencing old paths
8. Ensure `games/` directory structure remains unchanged (only writes game HTML files)

## File Structure After Changes

```
data/
  ├── unrivaled_scores.csv (combined, written by scrape_unrivaled_scores.R)
  ├── {year}/
  │   ├── unrivaled_scores.csv (season-specific, written by scrape_unrivaled_scores.R)
  │   └── wnba_shooting_stats_{season}.feather (written by fetch_wnba_stats.R)

fixtures/ (read-only for non-test code)
  ├── {year}/
  │   └── schedule.html (manually added)
  ├── fixtures.csv (test data)
  └── [other manually added test files]

games/ (written by download_game_data.R)
  └── {year}/
      └── {game_id}/
          ├── summary.html
          ├── box-score.html
          └── play-by-play.html
```

## Test Strategy

The test will use static analysis to detect violations:
- Parse all `.R` files in project root (excluding `tests/`)
- Search for patterns: `write_csv(.*"fixtures`, `write_feather(.*"fixtures`, `dir.create(.*"fixtures`
- Report any violations with file path and line number
- Allow exceptions for files in `tests/` directory

## Implementation Todos

1. Create test_no_fixtures_writes.R that detects writes to fixtures directory (should fail initially)
2. Update scrape_unrivaled_scores.R to write to data/ instead of fixtures/
3. Update fetch_wnba_stats.R to write to data/ instead of fixtures/
4. Update calculate_elo_ratings.R to read from data/unrivaled_scores.csv
5. Update rankings_bump_chart.R to read from data/unrivaled_scores.csv
6. Update find_winning_plays.R to read from data/unrivaled_scores.csv
7. Update analyze_shooting_metrics.R to read from data/wnba_shooting_stats_2024.feather
8. Run test suite to verify test_no_fixtures_writes.R passes (GREEN)
9. Update documentation/comments and verify all scripts function correctly
