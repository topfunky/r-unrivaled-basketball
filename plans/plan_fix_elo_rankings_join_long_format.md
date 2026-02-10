# Plan: Fix ELO Rankings Join by Team Game Index (All Years)

## Goal

Fix the data assembly approach for
`data/{year}/unrivaled_elo_rankings.csv` so game counts are preserved and each
team-game row can compare:

- actual record at that point (`wins_to_date`, `losses_to_date`), and
- projected outcomes (`estimated_wins_remaining`) from
  `data/{year}/unrivaled_elo_with_sos.csv`.

The plan covers **all existing years** under `data/{year}/` and includes a
shared helper refactor.

## Scope and Decisions (from requirements)

- **Year scope:** all years in `data/{year}/`.
- **Refactor target:** refactor shared helper(s) if present, then update the
  rankings builder.
- **Join key definition:** team-specific chronological game index.
- **Long-format output columns:** include cumulative wins/losses and games
  played to date.
- **Unmatched joins:** fail fast with explicit error (no silent drop/NA pass).
- **Testing depth:** full suite additions, including edge cases.
- **Plan detail:** full rollout with risks and validation checks.

## High-Level Design

1. Build a canonical **team-game long table** from existing game results.
2. Compute cumulative per-team progression fields:
   `wins_to_date`, `losses_to_date`, `games_played_to_date`,
   and `team_game_index`.
3. Join this long table to `unrivaled_elo_with_sos.csv` on:
   `(team, team_game_index)`.
4. Enforce strict validation that all expected rows match and that game-count
   invariants hold before writing `unrivaled_elo_rankings.csv`.
5. Reuse helper(s) across all year pipelines to avoid duplicated logic.

## Implementation Phases

### Phase 0: Baseline and Safety Checks

1. Run `make test` before introducing new tests or implementation changes.
2. Inventory current helper functions used by the rankings build path and
   identify where join logic currently reduces row counts.
3. Document current row-count behavior per year (pre-fix baseline) to make
   regression visible.

## Phase 1: Red (Tests First)

Add failing tests that expose the bug and lock intended behavior.

1. **Long conversion behavior**
   - Verify each played game contributes exactly two long rows (one per team).
   - Verify team/opponent orientation is correct for both sides.

2. **Team game index behavior**
   - Verify `team_game_index` increments strictly within each team by game date
     (plus stable tie-break if needed).
   - Verify index starts at 1 per team.

3. **Cumulative record behavior**
   - Verify `wins_to_date`, `losses_to_date`, and `games_played_to_date`
     at each team-game row.
   - Verify `games_played_to_date == wins_to_date + losses_to_date`.

4. **Join correctness**
   - Given fixture data, verify join by `(team, team_game_index)` produces no
     row loss and no unexpected duplication.
   - Verify strict failure on any unmatched key.

5. **Pipeline integration**
   - For each available year fixture/sample, verify output row counts match
     expected team-game totals.
   - Verify rankings output contains cumulative columns needed downstream.

6. **Edge cases**
   - Missing or duplicated game rows.
   - Doubleheaders / same-day games requiring deterministic ordering.
   - Incomplete season data snapshots.
   - Missing ELO/SOS rows for a team-game key (must error).

## Phase 2: Green (Implementation)

1. Refactor or create shared helper(s) for:
   - converting wide game results into long team-game rows,
   - computing cumulative results with tidyverse pipelines,
   - validating keys and row-count invariants before/after join.

2. Update rankings build path to:
   - use the long table as the left side of the join,
   - join `unrivaled_elo_with_sos.csv` by `team` + `team_game_index`,
   - preserve all played team-game rows,
   - include `wins_to_date`, `losses_to_date`, `games_played_to_date`,
     and projected fields used for downstream calculations.

3. Add explicit error handling:
   - fail when join keys are missing in either direction where required,
   - fail on duplicated `(team, team_game_index)` keys,
   - fail on negative or inconsistent cumulative values.

## Phase 3: Refactor

1. Keep helper functions short and focused with descriptive names.
2. Remove duplicate transformation logic across years.
3. Improve readability by grouping pipeline stages:
   parse -> long transform -> cumulative fields -> validate -> join -> validate.
4. Add concise comments only where transformation assumptions are non-obvious.

## Validation and Quality Gates

1. Run full tests (`make test`) after implementation.
2. Add per-year validation assertions:
   - team-game output row count equals expected derived count from source games,
   - no missing required columns in rankings output,
   - no NA in required join-derived fields unless explicitly allowed.
3. Add deterministic ordering checks for reproducible CSV output.
4. Spot-check representative years and teams for expected progression curves.

## Data Contract for Downstream Calculations

The rankings output must expose, at minimum:

- `team`
- `team_game_index`
- `wins_to_date`
- `losses_to_date`
- `games_played_to_date`
- `estimated_wins_remaining`

This guarantees downstream steps can compare actual-to-date performance against
remaining estimate.

## Risks and Mitigations

1. **Risk:** Ambiguous chronological ordering for same-date games.
   - **Mitigation:** define and test a deterministic tie-break key.

2. **Risk:** Existing helper behavior relied on implicit wide-format assumptions.
   - **Mitigation:** centralize conversion rules in one tested helper.

3. **Risk:** Historical data inconsistencies across years.
   - **Mitigation:** run per-year validation and fail with actionable messages.

4. **Risk:** Silent row drops during joins.
   - **Mitigation:** strict unmatched-key errors and explicit row-count checks.

## Rollout Sequence

1. Implement tests (red) for one representative year fixture.
2. Generalize tests to all available years.
3. Implement helper refactor and update rankings builder (green).
4. Run full test suite and validation checks.
5. Regenerate outputs for all years and confirm count invariants.
6. Prepare focused `jj` commit(s) after validation passes.

## Definition of Done

- All tests pass, including new edge-case coverage.
- `unrivaled_elo_rankings.csv` generation preserves expected game counts.
- Join uses `(team, team_game_index)` and fails on mismatches.
- Output includes cumulative played-game fields for downstream computations.
- Logic is shared, readable, and reusable across all year pipelines.
