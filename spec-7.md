## Task 7: Download all box scores for each game

- Create a subdirectory `games` if it does not exist
- Read fixtures/schedule.html
- Find all HTML links that point to a sub-path of `/game` such as <a href="/game/jcdgg9yavn4e/box-score">
- Remember the game ID such as `jcdgg9yavn4e`
- Remember the root website URL as `https://www.unrivaled.basketball/`
- Create a subdirectory `games/<game-id>` such as `games/jcdgg9yavn4e`
- Using the root URL and the following URL paths, download the HTML file for the summary, box score, and play by play for each game. Save the file to the game-specific subdirectory.
  -- Summary: `game/<game-id>`
  -- Box score: `game/<game-id>/box-score`
  -- Play by play: `game/<game-id>/play-by-play`

### Reference

https://www.unrivaled.basketball/game/jcdgg9yavn4e

https://www.unrivaled.basketball/game/jcdgg9yavn4e/play-by-play

https://www.unrivaled.basketball/game/jcdgg9yavn4e/box-score
