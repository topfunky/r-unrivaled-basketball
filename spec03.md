## Task 3: Render chart

Using the data saved to CSV in `fixtures/unrivaled_scores.csv`, render a chart as implemented in `task1.R`

The data from the CSV includes game by game results with a date, team names, and scores. A team has won the game if their score is more than the score of the other team.

Summarize this data into a new variable. The summary contains a row for each team_name for each week and also includes wins and losses. Wins is the cumulative sum of the games the team has won up to and including the current week of the season. Losses is a cumulative sum of the games the team has lost up to and including the current week of the season.

Rank is the team's position in the league each week, out of six total, starting with 1. Recalculate rankings after each week's games have concluded. A week for this league starts on Thursday and ends on Monday. So the calculation of rankings can occur after all Monday games have concluded.

Chart each team's wins and ranking in the entire league during each week of the season and generate a chart with ggplot that shows a bump chart to show the leading teams during the season. Use shades of Unrivaled purple for the chart.

Save the rendered chart to a file unrivaled_rankings_3.png

Use https://github.com/topfunky/gghighcontrast as the theme for the chart but keep the colors for each team as already specified.
