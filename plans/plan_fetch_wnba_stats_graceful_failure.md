# Plan: Graceful Failure in fetch_wnba_stats.R

## Goal

Allow `fetch_wnba_stats.R` to continue (or skip gracefully) when the WNBA
Stats API is unavailable, so downstream `make` tasks can still run using
previously saved data.

## Behavior on API Failure

- Warn to stderr via `message()` / `warning()`
- Write a status file to `data/wnba_fetch_status.txt` with timestamp and error
- If a previously saved feather file exists for the target season, load it and
  continue with all downstream steps (summary, plots, markdown report)
- If no feather file exists either, warn and exit with code 0 (not 1) so
  `make` does not halt

## Changes to `fetch_wnba_stats.R`

### 1. Wrap API call in `tryCatch`

In `get_wnba_shooting_stats()`, wrap the `wnba_leaguedashplayerstats()` call
in a `tryCatch` block. On error:
- Log the error message with `warning()`
- Return `NULL` instead of propagating the error

```r
player_stats <- tryCatch(
  wnba_leaguedashplayerstats(
    season = season,
    measure_type = "Base",
    per_mode = "Totals"
  ),
  error = function(e) {
    warning(glue("API call failed for {season}: {conditionMessage(e)}"))
    NULL
  }
)

if (is.null(player_stats)) return(NULL)
```

### 2. Write a status file

Add a helper `write_fetch_status(status, message)` that appends a line to
`data/wnba_fetch_status.txt`:

```
2026-03-10 19:42:31 | FAILURE | Timeout was reached...
2026-03-10 20:00:00 | SUCCESS | Loaded from cache
```

Call it with `"FAILURE"` when API returns NULL, and `"SUCCESS"` when data is
fetched or loaded from cache.

### 3. Fallback to existing feather file

After calling `get_wnba_shooting_stats()`, check if the result is `NULL`.
If so, attempt to load the feather file for that season:

```r
output_file <- glue("data/wnba_shooting_stats_{season}.feather")

wnba_shooting_stats <- get_wnba_shooting_stats(season)

if (is.null(wnba_shooting_stats)) {
  if (file.exists(output_file)) {
    message(glue("API unavailable. Loading cached data from {output_file}..."))
    wnba_shooting_stats <- read_feather(output_file)
    write_fetch_status("CACHED", glue("Loaded from {output_file}"))
  } else {
    write_fetch_status("SKIPPED", "No cached data available. Skipping.")
    message("No cached data available. Skipping all downstream steps.")
    quit(save = "no", status = 0)
  }
} else {
  write_feather(wnba_shooting_stats, output_file)
  write_fetch_status("SUCCESS", glue("Fetched and saved to {output_file}"))
}
```

### 4. Continue with existing downstream steps unchanged

After the fallback logic resolves `wnba_shooting_stats`, the rest of the
script (summary, plots, markdown report) runs exactly as before with no
further changes needed.

## Files Changed

| File | Change |
|---|---|
| `fetch_wnba_stats.R` | Add `tryCatch` in fetch function, add `write_fetch_status()` helper, add fallback logic after fetch call |

## Testing

- Run `make test` before and after changes to confirm no regressions
- Simulate failure by temporarily passing an invalid season (e.g. `9999`)
  and confirm:
  - Script exits with code 0
  - `data/wnba_fetch_status.txt` is written
  - If feather exists: downstream steps run
  - If feather missing: script skips cleanly
- Confirm normal run still saves feather and writes `SUCCESS` status
