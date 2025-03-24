# NOTE: Original code generated with GitHub Copilot.

# Load necessary libraries
library(rvest)
library(dplyr)
library(feather)
library(ggplot2)
library(ggbump)

# Player stats
# https://www.unrivaled.basketball/stats/player
# Team stats
# https://www.unrivaled.basketball/stats/team
#

# Define the URL of the Unrivaled Basketball League game data
url <- "https://www.unrivaled.basketball/schedule"

# Function to scrape game data
scrape_game_data <- function(url) {
  # Div with date and multiple games inside
  # flex row-12 p-12
  #
  # Span with date
  # uppercase weight-500

  page <- read_html(url)

  dates <- page %>%
    html_nodes("span.uppercase.weight-500") %>%
    html_text(trim = TRUE)

  games <- page %>% html_nodes(".flex.w-100.radius-8")
  game_data <- list()
  game_divs <- page %>% html_nodes(".flex-row.w-100.items-center.col-12")

  for (game_div in game_divs) {
    game_data <- c(
      game_data,
      lapply(games, function(game) {
        team_a_score <- game %>%
          html_node("h3.weight-900") %>%
          html_text(trim = TRUE) %>%
          as.integer()
        team_a_name <- game %>%
          html_node(".color-blue.weight-500.font-14") %>%
          html_text(trim = TRUE)

        team_b <- game %>% html_nodes(".color-blue.weight-500.font-14") %>% .[2]
        team_b_name <- team_b %>% html_text(trim = TRUE)
        team_b_score <- team_b %>%
          html_node(xpath = "following-sibling::h3") %>%
          html_text(trim = TRUE) %>%
          as.integer()

        data.frame(
          TeamA = team_a_name,
          TeamAScore = team_a_score,
          TeamB = team_b_name,
          TeamBScore = team_b_score,
          stringsAsFactors = FALSE
        )
      })
    )
  }

  game_data <- do.call(rbind, game_data)
  return(game_data)
}

# Scrape the game data
game_data <- scrape_game_data(url)

# Process the data
game_data <- game_data %>%
  mutate(
    Week = as.integer(Week),
    Wins = as.integer(Wins),
    Team = as.factor(Team)
  )

# Save the data to a Feather database
write_feather(game_data, "game_data.feather")

# Calculate weekly rankings
rankings <- game_data %>%
  group_by(Week, Team) %>%
  summarise(TotalWins = sum(Wins)) %>%
  arrange(Week, desc(TotalWins)) %>%
  mutate(Rank = row_number())

# Generate the bump chart
ggplot(rankings, aes(x = Week, y = Rank, color = Team)) +
  geom_bump(size = 2) +
  scale_y_reverse(breaks = 1:nrow(rankings)) +
  scale_color_manual(values = c("#5A2D82", "#7D3C98", "#9B59B6", "#BB8FCE")) +
  labs(
    title = "Unrivaled Basketball League Rankings",
    x = "Week",
    y = "Rank",
    color = "Team"
  ) +
  theme_minimal()

# Save the plot
ggsave("unrivaled_bump_chart.png")
