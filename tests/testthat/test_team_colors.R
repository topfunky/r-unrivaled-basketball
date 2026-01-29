# Purpose: Tests for team_colors.R constants
# Tests that team colors and league colors are defined correctly

describe("TEAM_COLORS", {
  it("contains all 8 Unrivaled teams", {
    expected_teams <- c(
      "Rose",
      "Lunar Owls",
      "Mist",
      "Laces",
      "Phantom",
      "Vinyl",
      "Breeze",
      "Hive"
    )

    expect_equal(length(TEAM_COLORS), 8)
    expect_setequal(names(TEAM_COLORS), expected_teams)
  })

  it("has valid hex color codes for all teams", {
    hex_pattern <- "^#[0-9A-Fa-f]{6}$"

    for (team in names(TEAM_COLORS)) {
      expect_match(
        TEAM_COLORS[[team]],
        hex_pattern,
        info = paste("Team", team, "should have valid hex color")
      )
    }
  })

  it("has unique colors for each team", {
    expect_equal(
      length(unique(TEAM_COLORS)),
      length(TEAM_COLORS),
      info = "All team colors should be unique"
    )
  })

  it("contains expected specific colors", {
    expect_equal(TEAM_COLORS[["Rose"]], "#1c5750")
    expect_equal(TEAM_COLORS[["Hive"]], "#FFD700")
    expect_equal(TEAM_COLORS[["Vinyl"]], "#820234")
  })
})

describe("ubb_color", {
  it("is a valid hex color", {
    expect_match(ubb_color, "^#[0-9A-Fa-f]{6}$")
  })

  it("is purple", {
    expect_equal(ubb_color, "#6A0DAD")
  })
})

describe("wnba_color", {
  it("is a valid hex color", {
    expect_match(wnba_color, "^#[0-9A-Fa-f]{6}$")
  })

  it("is orange", {
    expect_equal(wnba_color, "#FF8C00")
  })
})

describe("mean_color", {
  it("is a valid hex color", {
    expect_match(mean_color, "^#[0-9A-Fa-f]{6}$")
  })

  it("matches WNBA orange", {
    expect_equal(mean_color, wnba_color)
  })
})

describe("median_color", {
  it("is a valid hex color", {
    expect_match(median_color, "^#[0-9A-Fa-f]{6}$")
  })

  it("is turquoise", {
    expect_equal(median_color, "#00CED1")
  })
})
