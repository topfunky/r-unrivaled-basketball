## Task 2: Scrape data

Scrape live data from the Unrivaled website and save to the `fixtures` directory as `unrivaled_scores.csv`.

Using `rvest`, read HTML from https://www.unrivaled.basketball/schedule

The data is contained in HTML elements within the document, but none have a clear identifier.

Each day contains multiple games and follows the format found in `fixtures/game_day.html`.

A day starts with the HTML snippet `<div class="flex row-12 p-12">`. Inside this div is a span that looks like `<span class="uppercase weight-500">` and contains a human readable date on which the games inside occurred.

Immediately inside `<div class="relative">` is an `<h3 class="weight-900">`. The h3 contains the away team's score.

Inside a `<a class="flex-row items-center col-12" href="">` is an `img` and then a `<div class="color-blue weight-500 font-14">` with the name of the away team.

A second `<h3 class="weight-900">` contains the home team's score. Then there is another `<a class="flex-row items-center col-12" href="">` which contains an `img` and `<div class="color-blue weight-500 font-14">` with the name of the home team.

That's one game.

Repeat that to find all scores for the away team and home team for all games on all days.
