# Plan: Combine Elo rankings + SOS output

## Goal
Combine `data/{year}/unrivaled_elo_rankings.csv` and
`data/{year}/unrivaled_elo_with_sos.csv` into a single output file
`data/{year}/unrivaled_elo_rankings.csv` (per-game rows), and add
`*_total_estimated_wins` columns that sum current wins with estimated wins
for the rest of the season.

## Assumptions from answers
- Apply to all years under `data/`.
- Output file replaces `data/{year}/unrivaled_elo_rankings.csv`.
- Row grain stays per game (current Elo rankings CSV).
- Keep all columns from current Elo rankings output.
- Add remaining SOS columns (games_played, games_remaining,
  remaining_estimated_wins) for each team.
- Compute current wins from `data/unrivaled_scores.csv`.
- Join SOS to per-game rows by `team` + `games_played`.
- `total_estimated_wins`:
  - If `estimated_wins_total` exists, use it.
  - Otherwise use `current_wins + remaining_estimated_wins`.
- Stop writing `unrivaled_elo_with_sos.csv` and
  `unrivaled_elo_with_sos.feather`.

## Plan
1. Baseline tests
   - Run `make test` before any code changes (per repo rules).
2. Add win-count helpers
   - Build a small helper (new or reused) to compute per-team
     `wins`, `losses`, `games_played` per game from
     `data/unrivaled_scores.csv` using tidyverse, matching the
     per-game row grain.
   - Ensure the helper returns one row per team per game with
     `team`, `games_played`, `wins`.
3. Combine Elo + SOS + wins in `calculate_elo_ratings.R`
   - In `process_season`, after `ratings_history` and `elo_with_sos`
     are created, build a per-team lookup for SOS keyed by
     `team` + `games_played`.
   - Join SOS onto `ratings_history` twice: once for `home_team`
     and once for `away_team`, adding:
     - `home_team_games_played`, `home_team_games_remaining`,
       `home_team_remaining_estimated_wins`
     - `away_team_games_played`, `away_team_games_remaining`,
       `away_team_remaining_estimated_wins`
   - Join current wins per team (computed from scores) to add:
     - `home_team_current_wins`, `away_team_current_wins`
   - Compute total estimated wins:
     - If `estimated_wins_total` present from SOS, use it.
     - Else compute:
       - `home_team_total_estimated_wins =
          home_team_current_wins + home_team_remaining_estimated_wins`
       - `away_team_total_estimated_wins =
          away_team_current_wins + away_team_remaining_estimated_wins`
   - Update `save_ratings_data` so the combined per-game table
     (with new columns) writes to `data/{year}/unrivaled_elo_rankings.csv`
     and `data/{year}/unrivaled_elo_rankings.feather`.
   - Remove `save_elo_with_sos` calls and stop writing those files.
4. Tests
   - Add/extend tests in `tests/testthat` to cover:
     - SOS join uses `team` + `games_played`.
     - `total_estimated_wins` equals current wins plus remaining
       estimated wins when `estimated_wins_total` is absent.
     - Expected columns exist in the combined output data frame.
5. Verify
   - Run `make test` after changes.
   - Spot-check a small slice of the output for one season to confirm
     the new columns line up with per-team games played.
