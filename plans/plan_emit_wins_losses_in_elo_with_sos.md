# Plan: Emit team wins and losses in elo_with_sos output

## Goal
Add `wins` and `losses` columns to
`data/{year}/unrivaled_elo_with_sos.csv` for all years in `data/`,
with records represented as running totals at each row snapshot.

## Assumptions from answers
- Scope is full pipeline update: scripts, tests, docs, and dependent
  outputs.
- Apply to all existing years under `data/`.
- Wins/losses are derived from game-level results already used by the
  Elo pipeline.
- Output schema adds integer columns named `wins` and `losses`.
- Values are running totals aligned to each row date or snapshot in
  `unrivaled_elo_with_sos.csv`.
- Ties/no-contests are ignored (no extra columns).
- Validation includes adding or updating tests.

## Plan
1. Baseline and data-shape review
   - Run `make test` before making changes (repo rule).
   - Inspect `R/combine_elo_sos.R` and related pipeline scripts to
     confirm row grain and join keys used to build
     `unrivaled_elo_with_sos`.
   - Identify where snapshot date/order is established so running
     records can align correctly.

2. Add running record computation from existing game results
   - Reuse the game-level results source already feeding Elo inputs.
   - Build or extract a focused helper that computes per-team running
     `wins` and `losses` by snapshot (team + date/game index key).
   - Ensure the helper handles missing/edge rows explicitly and ignores
     ties/no-contests rather than counting them as wins or losses.

3. Join running wins/losses into elo_with_sos assembly
   - In `R/combine_elo_sos.R` (and any upstream script that prepares
     intermediate tables), join running records using stable keys that
     preserve row grain.
   - Emit integer `wins` and `losses` columns in
     `data/{year}/unrivaled_elo_with_sos.csv`.
   - Confirm behavior is consistent across all years in `data/{year}`.

4. Update dependent outputs and documentation
   - Update any related writer/schema expectations for
     `unrivaled_elo_with_sos` so downstream readers expect `wins` and
     `losses`.
   - Add concise documentation notes where output columns are described
     (script header/comments or docs file as appropriate).

5. Tests (TDD)
   - Add or update `testthat` coverage for:
     - Running `wins`/`losses` progression per team over snapshots.
     - Correct join alignment between snapshot rows and running record.
     - Tie/no-contest rows not incrementing wins or losses.
     - Presence and integer type of `wins` and `losses` in output.
   - Prefer informative assertions over generic truthy checks.

6. Verification
   - Run `make test` after implementation.
   - Spot-check at least one early-season and one late-season snapshot
     for multiple teams to validate running totals in
     `data/{year}/unrivaled_elo_with_sos.csv`.
