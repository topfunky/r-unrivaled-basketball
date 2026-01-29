# Purpose: Tests for render_stats.R functions
# Tests helper functions for formatting and rendering statistics

library(knitr)
library(dplyr)

describe("format_pct", {
  it("formats decimal as percentage with default 1 digit", {
    result <- format_pct(0.5)
    expect_equal(result, "50.0%")
  })

  it("formats with specified digits", {
    result <- format_pct(0.12345, digits = 2)
    expect_equal(result, "12.35%")
  })

  it("formats zero correctly", {
    result <- format_pct(0)
    expect_equal(result, "0.0%")
  })

  it("formats one (100%) correctly", {
    result <- format_pct(1)
    expect_equal(result, "100.0%")
  })

  it("handles values greater than 1", {
    result <- format_pct(1.5)
    expect_equal(result, "150.0%")
  })

  it("handles negative values", {
    result <- format_pct(-0.25)
    expect_equal(result, "-25.0%")
  })
})

describe("format_signed_pct", {
  it("formats positive value with plus sign", {
    result <- format_signed_pct(5.5)
    expect_equal(result, "+5.5%")
  })

  it("formats negative value with minus sign", {
    result <- format_signed_pct(-3.2)
    expect_equal(result, "-3.2%")
  })

  it("formats zero with plus sign", {
    result <- format_signed_pct(0)
    expect_equal(result, "+0.0%")
  })

  it("formats with specified digits", {
    result <- format_signed_pct(12.345, digits = 2)
    expect_equal(result, "+12.35%")
  })
})

describe("render_shooting_improvements", {
  it("outputs markdown table header", {
    # Create minimal test data
    test_data <- tibble::tibble(
      player_name = c("Player A", "Player B"),
      two_pt_improvement = c(5.0, -2.0),
      three_pt_improvement = c(3.0, 4.0),
      two_pt_relative_improvement = c(10.0, -5.0),
      three_pt_relative_improvement = c(8.0, 12.0)
    )

    output <- capture.output(render_shooting_improvements(test_data))

    expect_true(any(grepl("Shooting Percentage Improvements", output)))
    expect_true(any(grepl("Player", output)))
  })
})

describe("render_possession_stats", {
  it("outputs free throw and possession statistics", {
    test_ppp <- tibble::tibble(
      total_points = 1000,
      total_possessions = 500,
      avg_points = 100,
      avg_possessions = 50,
      points_per_possession = 2.0
    )

    output <- capture.output(render_possession_stats(150, test_ppp))

    expect_true(any(grepl("Free Throw Statistics", output)))
    expect_true(any(grepl("Total Free Throw Attempts: 150", output)))
    expect_true(any(grepl("Points Per Possession", output)))
  })
})

describe("render_player_comparison", {
  it("outputs player comparison table", {
    test_data <- tibble::tibble(
      player_name = "Test Player",
      ubb_fg_pct = 0.45,
      field_goal_pct = 0.42,
      ubb_two_pt_pct = 0.50,
      wnba_two_pt_pct = 0.48,
      ubb_three_pt_pct = 0.35,
      three_point_pct = 0.33,
      ubb_ts_pct = 0.55,
      wnba_ts_pct = 0.52
    )

    output <- capture.output(render_player_comparison(test_data))

    expect_true(any(grepl("Player Comparison", output)))
    expect_true(any(grepl("Test Player", output)))
  })
})

describe("render_shooting_differences", {
  it("outputs shooting differences table", {
    test_data <- tibble::tibble(
      player_name = "Test Player",
      ubb_fg_pct = 0.45,
      field_goal_pct = 0.42,
      ubb_two_pt_pct = 0.50,
      wnba_two_pt_pct = 0.48,
      ubb_three_pt_pct = 0.35,
      three_point_pct = 0.33,
      ubb_ts_pct = 0.55,
      wnba_ts_pct = 0.52,
      ubb_fg_attempted = 100
    )

    output <- capture.output(render_shooting_differences(test_data))

    expect_true(any(grepl("Shooting Percentage Differences", output)))
  })
})

describe("render_top_shooters", {
  it("outputs top shooters by FG%, 2P%, and 3P%", {
    test_data <- tibble::tibble(
      player_name = c("Player A", "Player B"),
      ubb_fg_pct = c(0.55, 0.45),
      ubb_fg_made = c(50, 40),
      ubb_fg_attempted = c(91, 89),
      ubb_two_pt_pct = c(0.60, 0.50),
      ubb_two_pt_made = c(40, 30),
      ubb_two_pt_attempted = c(67, 60),
      ubb_three_pt_pct = c(0.40, 0.35),
      ubb_three_pt_made = c(10, 10),
      ubb_three_pt_attempted = c(25, 29)
    )

    output <- capture.output(render_top_shooters(test_data))

    expect_true(any(grepl("Top 10 Players by Field Goal Percentage", output)))
    expect_true(any(grepl("Top 10 Players by Two-Point Percentage", output)))
    expect_true(any(grepl("Top 10 Players by Three-Point Percentage", output)))
  })
})

describe("render_top_ts_shooters", {
  it("outputs top true shooting percentage table", {
    test_data <- tibble::tibble(
      player_name = c("Player A", "Player B"),
      ubb_ts_pct = c(0.60, 0.55),
      ubb_pts = c(200, 180),
      ubb_fg_attempted = c(100, 90),
      ubb_ft_attempted = c(50, 40)
    )

    output <- capture.output(render_top_ts_shooters(test_data))

    expect_true(any(grepl("True Shooting Percentage", output)))
    expect_true(any(grepl("Player A", output)))
  })
})

describe("render_top_2pt_diff", {
  it("outputs two-point shooting differences", {
    test_data <- tibble::tibble(
      player_name = c("Player A", "Player B"),
      ubb_two_pt_pct = c(0.55, 0.50),
      wnba_two_pt_pct = c(0.45, 0.48),
      ubb_two_pt_attempted = c(100, 80)
    )

    output <- capture.output(render_top_2pt_diff(test_data))

    expect_true(any(grepl("Two-Point Shooting Percentage Differences", output)))
  })
})

describe("render_shot_distribution", {
  it("outputs shot distribution comparison", {
    test_data <- tibble::tibble(
      player_name = "Test Player",
      ubb_fg_attempted = 100,
      ubb_two_pt_attempted = 60,
      ubb_three_pt_attempted = 40,
      field_goals_attempted = 90,
      wnba_two_pt_attempted = 55,
      three_point_field_goals_attempted = 35
    )

    output <- capture.output(render_shot_distribution(test_data))

    expect_true(any(grepl("Shot Distribution", output)))
  })
})

describe("render_all_stats", {
  it("writes all stats to output file", {
    temp_file <- tempfile(fileext = ".md")
    on.exit(unlink(temp_file))

    test_stats <- list(
      total_ft_attempts = 100,
      points_per_possession = tibble::tibble(
        total_points = 500,
        total_possessions = 250,
        avg_points = 50,
        avg_possessions = 25,
        points_per_possession = 2.0
      ),
      player_comparison = tibble::tibble(
        player_name = "Test",
        ubb_fg_pct = 0.45,
        field_goal_pct = 0.42,
        ubb_two_pt_pct = 0.50,
        wnba_two_pt_pct = 0.48,
        ubb_three_pt_pct = 0.35,
        three_point_pct = 0.33,
        ubb_ts_pct = 0.55,
        wnba_ts_pct = 0.52,
        ubb_fg_attempted = 100,
        ubb_two_pt_attempted = 60,
        ubb_three_pt_attempted = 40,
        field_goals_attempted = 90,
        wnba_two_pt_attempted = 55,
        three_point_field_goals_attempted = 35
      ),
      shooting_improvement = tibble::tibble(
        player_name = "Test",
        two_pt_improvement = 5.0,
        three_pt_improvement = 3.0,
        two_pt_relative_improvement = 10.0,
        three_pt_relative_improvement = 8.0
      ),
      player_fg_pct = tibble::tibble(
        player_name = "Test",
        ubb_fg_pct = 0.45,
        ubb_fg_made = 45,
        ubb_fg_attempted = 100,
        ubb_two_pt_pct = 0.50,
        ubb_two_pt_made = 30,
        ubb_two_pt_attempted = 60,
        ubb_three_pt_pct = 0.375,
        ubb_three_pt_made = 15,
        ubb_three_pt_attempted = 40
      ),
      player_ts_pct = tibble::tibble(
        player_name = "Test",
        ubb_ts_pct = 0.55,
        ubb_pts = 100,
        ubb_fg_attempted = 100,
        ubb_ft_attempted = 20
      )
    )

    render_all_stats(temp_file, test_stats)

    expect_true(file.exists(temp_file))
    content <- readLines(temp_file)
    expect_true(any(grepl("Basketball Metrics Summary", content)))
  })
})
