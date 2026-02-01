# Plan: Fix 2026 scraping for schedule, box score, and play-by-play

## Goal
- Update the scraping pipeline so 2026 schedule, box scores, and play-by-
  play data are correctly collected from the Unrivaled site.
- Recognize completed games by the "Final" label and scores.
- Skip future/uncompleted games while ensuring 20+ completed games are
  processed.
- Cache 2026 HTML in `games/2026/` using the requested overwrite rubric.

## Constraints and assumptions
- Authoritative schedule source:
  `https://www.unrivaled.basketball/schedule?games=All`
- Game-specific sources:
  `https://www.unrivaled.basketball/game/{game_id}/play-by-play` and
  `https://www.unrivaled.basketball/game/{game_id}/box-score`
- Entry points: `scrape_unrivaled_scores.R` and `download_game_data.R`
- Scraping helpers: `R/scrape_utils.R`
- Completed games contain the word "Final" and team scores; incomplete
  games have neither.
- Cache policy:
  - Always fetch the full schedule fresh.
  - Do not overwrite cached HTML for completed games.
  - Overwrite cached HTML for games not completed or not yet occurred.
- Polite delay: 1 second between requests.
- Tests must use `fixtures/` only.

## Pre-work
- Run `make test` to ensure baseline is green.
- Inspect `R/scrape_utils.R`, `scrape_unrivaled_scores.R`, and
  `download_game_data.R` for current season parsing and caching logic.
- Review existing fixtures and test coverage for schedule parsing and
  caching behaviors.

## Implementation steps (TDD)
1. Add/adjust fixtures if needed
   - Capture an updated 2026 schedule fixture that includes:
     - Multiple completed games ("Final" + scores).
     - Ignore upcoming games (no "Final", no scores).
   - Ensure fixtures remain in `fixtures/` only.

2. Tests for schedule parsing (red)
   - Add tests asserting that:
     - Completed games are detected via "Final" and scores.
     - Game IDs are extracted for all completed games.
     - Future games are excluded from the list used for box/play scraping.
   - Use meaningful expectations (avoid `expect_true/false`).

3. Tests for caching overwrite rubric (red)
   - Add tests that simulate cached HTML presence:
     - Completed games are not re-fetched.
     - Incomplete or missing games are re-fetched and overwritten.
   - Use fixtures and temporary directories.

4. Update schedule parsing (green)
   - In `R/scrape_utils.R`, adjust schedule parsing to:
     - Detect "Final" label reliably.
     - Extract scores explicitly and mark completion.
     - Return a structured set of completed games with game IDs.

5. Update download and cache logic (green)
   - In `download_game_data.R` (or helper functions):
     - Always fetch schedule fresh.
     - Apply caching rules for `games/2026/`:
       - Skip download for cached completed games.
       - Download and overwrite for incomplete or missing games.
     - Enforce 1s delay between requests.

6. Update entrypoint script(s)
   - Ensure `scrape_unrivaled_scores.R` uses the updated helpers.
   - Confirm outputs are written to `data/2026/` CSVs.

7. Refactor for readability (refactor)
   - Extract shorter helper functions if needed.
   - Use descriptive variable names and tidyverse pipe `|>`.
   - Document any non-obvious transformations or assumptions.

## Verification
- Run `make test`.
- Run `make all-tasks` and verify:
  - Schedule pulls >20 completed 2026 games.
  - Box score and play-by-play downloads occur only for completed games.
  - `data/2026/` CSVs update as expected.

## Deliverables
- Updated tests in `tests/testthat/` and fixtures in `fixtures/`.
- Updated scraping logic in `R/scrape_utils.R` and entrypoint scripts.
- Cached 2026 HTML in `games/2026/` updated according to policy.
