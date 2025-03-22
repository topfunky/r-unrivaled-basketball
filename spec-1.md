# Unrivaled Basketball games, teams, dates, and scores

Write code in R that scrapes game by game win data from the unrivaled basketball league. Save the data to a feather database. Chart each team's wins and ranking during each week of the season and generate a chart with ggplot that shows a bump chart to show the leading teams during the season. Use shades of Unrivaled purple for the chart.

Implement this in multiple steps and stop after each task so I can run the code and verify it.

Use the native R pipe in R code.

## Task 1: Create a chart from fixture data

Create fixture data that can be used to render a chart of team wins throughout the season. Fixture data should originate in a CSV file.

Team names include:

- Lunar Owls
- Laces
- Vinyl
- Phantom
- Mist
- Rose

The data is a tidy data structure with columns for home_team, home_team_score, away_team, away_team_score, week_number, and date. Each team plays once each week for 14 weeks for a total of 14 games per team.

A team has won the game if their score is more than the score of the other team.

Summarize this data into a new variable. The summary contains a row for each team_name for each week and also includes wins and losses. Wins is the cumulative sum of the games the team has won up to and including the current week of the season. Losses is a cumulative sum of the games the team has lost up to and including the current week of the season. Rank is the team's position in the league each week, out of six total, starting with 1.

Chart each team's wins and ranking in the entire league during each week of the season and generate a chart with ggplot that shows a bump chart to show the leading teams during the season. Use shades of Unrivaled purple for the chart.

Save the rendered chart to a file rankings.png

Use https://github.com/topfunky/gghighcontrast as the theme for the chart.
