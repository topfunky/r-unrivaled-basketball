## Task 5: Write a blog post about the findings

Write a blog post in Markdown format about the competitiveness and outcomes of the Unrivaled Basketball league using statistical analysis and charting. Include Markdown image includes for unrivaled_elo_ratings.png and unrivaled_rankings_3.png

Keep it interesting but not silly. Be concise rather than wordy.

About the league

- difficult to start a new pro sports league
- mostly standard rules (but single free throw and elam ending winning score)
- Short court dimensions
- Short shot clock
- Only six teams
- Short season with 14 games per team
- Extremely short playoffs with two total rounds and single elimination
- All games played at a neutral location

Calculations & programming

- No official data feed, only win/loss and score (also box score and play by play but only as HTML)
- Nasty modern web app page with no clear CSS classes to index on in order to assemble dataset
- Six games per league week with two games by each team
- I used Cursor AI IDE by writing a Markdown spec to start the process
- One game canceled while 0-11 but still counts in record
- Still required a lot of debugging
- Aesthetic considerations on top of what Cursor generated
- Impressive that it integrated my own ggplot theme code which is not on CRAN but does have a good readme

Lunar owls

- 13-1 record, only losing to Rose
- 80% chance of winning playoff game. Lost by 3
- Point differential +170 (next +34) or 136 points ahead of next team, and +12 ppg
- Highest ELO
- Lost to 2nd lowest elo team in their only playoff game
- Only regular season loss was to eventual champion Rose

Rose

- Lost first few games
- 3rd best elo and 3rd best record at halfway point of season
- Made it to title game and won somewhat easily
- What happened in week 5 that they became much better? What happened to Laces in week 5?

Other stats needed

- point differential
- pythagorean wins
- WP playoff games, esp WP of Rose v Vinyl compared to Rose v Lunar Owls
- Strength of schedule
- In how many games did the ELO favored team win?
