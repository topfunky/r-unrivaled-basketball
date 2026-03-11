# Plan: Fix `parse_summary` Table Index Error

## Problem

`make all-tasks` fails when running `parse_play_by_play.R` with:

```
Error in `dplyr::mutate()`:
ℹ In argument: `field_goal_pct = as.numeric(stringr::str_remove(field_goal_pct, "%"))`.
Caused by error:
! object 'field_goal_pct' not found
```

## Root Cause

`parse_summary()` in `R/parse_utils.R` always reads `tables[1]` from the
summary HTML. Regular-season games have only one table (the shooting/team
stats table), so `tables[1]` is correct. However, playoff/featured games (e.g.
`9r3c2rtv1a4b`, `arprsfrixw5t`, `jx1ocoygd5a4`, `kossd6v863z0`, `y87s0h88otw8`)
have **three** tables:

| Index | Content |
|-------|---------|
| 1 | Player leaders (Points / Rebounds / Assists) — 3 rows |
| 2 | Team shooting/turnover stats — 14 rows (the one we want) |
| 3 | Quarter-by-quarter scoring — 2 rows |

When `tables[1]` is the leaders table, none of its rows match the filter
(`col1 %in% c("FG", "Field Goal %", ...)`) and the resulting tibble has zero
rows. After `pivot_wider`, the columns `field_goal_pct`, `three_point_pct`, and
`free_throw_pct` are never created, causing the downstream `mutate` to fail.

## Fix Strategy

Instead of selecting by positional index, detect the correct table by its
content. The shooting-stats table is the one whose first column contains "FG"
among its values.

## Implementation

### `R/parse_utils.R` — `parse_summary()`

Replace:

```r
table_data <- rvest::html_table(tables[1])
if (length(table_data) == 0 || nrow(table_data[[1]]) == 0) { ... }
```

With logic that searches all tables for the one containing a "FG" row:

```r
# Find the table that contains shooting stats (first col has "FG")
stats_table <- NULL
for (tbl in rvest::html_table(tables)) {
  if ("FG" %in% tbl[[1]]) {
    stats_table <- tbl
    break
  }
}
if (is.null(stats_table)) {
  warning(sprintf("No shooting stats table found in summary file for game %s", game_id))
  return(NULL)
}
```

Then replace all subsequent references to `table_data[[1]]` with `stats_table`.

### Tests

- Add a test in the test suite that calls `parse_summary()` with a fixture that
  has three tables (leaders + stats + quarter scores) and asserts that the
  returned tibble contains `field_goal_pct`, `three_point_pct`, and
  `free_throw_pct` columns with numeric values.
- Verify the existing single-table test still passes.
- Run `make test` before and after the fix to confirm red → green.

## Files to Change

| File | Change |
|------|--------|
| `R/parse_utils.R` | Update `parse_summary()` to search for the stats table by content instead of hardcoded index |
| `tests/` | Add fixture for a 3-table summary and a corresponding test case |

## Acceptance Criteria

- `make all-tasks` completes without error.
- `make test` passes.
- `parse_summary()` correctly returns shooting stats for both 1-table and
  3-table summary HTML files.
