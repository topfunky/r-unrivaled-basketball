## Task 8: Parse box score and play by play data

Build three data structures that contain game statistics for each game played during the season. The three structures are `summary`, `box-score`, and `play-by-play`.

In the `games` directory are subdirectories for each game. Inside each `game/<game-id>` subdirectory are three files:

- summary.html
- box-score.html
- play-by-play.html

First, read the `play-by-play.html` file. In it is a `table`. The table has three columns:

- time
- play
- score

Parse the table as data with `rvest`. Create a row for each play by play entry that contains the values from the three columns, plus a fourth column with the `game-id`.
