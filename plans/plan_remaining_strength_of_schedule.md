## Remaining strength of schedule plan

### Goals
- Add a `remaining_estimated_wins` column to the Elo table for each team/week.
- Use `elo_win_prob()` to estimate win probability for each remaining matchup.
- Include future (unplayed) games by enhancing schedule parsing.
- Define "week" as games played/remaining, not calendar time.

### Assumptions
- Remaining games for a given week include games strictly after the current
  games played count.
- Week indices are derived from team games played (or games remaining).
- Current week Elo is the team Elo after its latest completed game.
- Teams with zero games played use the initial Elo (1500).
- `calculate_elo_ratings.R` remains the main pipeline that produces the Elo
  table files.

### Plan
1. **Baseline and exploration**
   - Run `make test` before any new work.
   - Parse `data/{year}/schedule.html` and build a season matchup table that
     includes both completed and upcoming games.
   - Compute per-team game counts (played and remaining) from the schedule
     table and confirm counts align with the total games per team.

2. **Schedule parsing enhancements**
   - Extend schedule parsing in `R/scrape_utils.R` to capture upcoming games:
     extract date, teams, game_id, and status (Final vs Scheduled).
   - Preserve existing behavior for completed games so current workflows stay
     intact.
   - Add/extend tests in `tests/testthat` to cover upcoming game parsing and
     the played/remaining counts.

3. **Games played/remaining utility**
   - Add a small utility (new helper or in `R/scrape_utils.R`) to compute
     per-team `games_played` and `games_remaining` using the schedule and
     completed games.
   - Ensure the helper is reused for both schedule parsing and Elo table output.

4. **Remaining strength of schedule computation**
   - In `calculate_elo_ratings.R`, build a per-team/per-game-count Elo table
     that includes each team’s Elo after its latest completed game.
   - For each team and games_played count, join the future schedule to include
     all unplayed matchups for that team.
   - For each remaining matchup, compute win probability with
     `elo_win_prob(my_elo, opponent_elo)` using the team’s Elo for the current
     games_played value.
   - Sum probabilities to produce `remaining_estimated_wins` and add it to the
     Elo table.

5. **Validation and outputs**
   - Add tests verifying:
     - remaining games exclude games already played
     - `remaining_estimated_wins` equals the sum of `elo_win_prob` values
   - Run `make test` after changes.
   - Ensure updated Elo tables are saved with the new column.

### Notes
- If the schedule analysis shows uneven games per team by Monday, document the
  impact and adjust the remaining-game join logic as needed.
