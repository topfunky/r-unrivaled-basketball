# Purpose: Tests for elo_win_prob.R functions
# Tests the ELO win probability calculation function

describe("elo_win_prob", {
  it("returns 0.5 for equal ELO ratings", {
    result <- elo_win_prob(1500, 1500)
    expect_equal(result, 0.5)
  })

  it("returns higher probability for higher rated team", {
    result <- elo_win_prob(1600, 1400)
    expect_gt(result, 0.5)
  })

  it("returns lower probability for lower rated team", {
    result <- elo_win_prob(1400, 1600)
    expect_lt(result, 0.5)
  })

  it("returns approximately 0.76 for 200 point ELO advantage", {
    # Standard ELO formula: 200 point advantage ~= 76% win probability
    result <- elo_win_prob(1600, 1400)
    expect_equal(result, 0.76, tolerance = 0.01)
  })

  it("returns approximately 0.24 for 200 point ELO disadvantage", {
    result <- elo_win_prob(1400, 1600)
    expect_equal(result, 0.24, tolerance = 0.01)
  })

  it("returns approximately 0.91 for 400 point ELO advantage", {
    # 400 point advantage ~= 91% win probability
    result <- elo_win_prob(1800, 1400)
    expect_equal(result, 0.91, tolerance = 0.01)
  })

  it("returns probability between 0 and 1", {
    # Test with extreme values
    result_high <- elo_win_prob(2000, 1000)
    result_low <- elo_win_prob(1000, 2000)

    expect_gte(result_high, 0)
    expect_lte(result_high, 1)
    expect_gte(result_low, 0)
    expect_lte(result_low, 1)
  })

  it("is symmetric: P(A wins) + P(B wins) = 1", {
    prob_a <- elo_win_prob(1600, 1400)
    prob_b <- elo_win_prob(1400, 1600)

    expect_equal(prob_a + prob_b, 1, tolerance = 1e-10)
  })

  it("handles zero ELO ratings", {
    result <- elo_win_prob(0, 0)
    expect_equal(result, 0.5)
  })

  it("handles negative ELO ratings", {
    result <- elo_win_prob(-100, -100)
    expect_equal(result, 0.5)

    result_diff <- elo_win_prob(100, -100)
    expect_gt(result_diff, 0.5)
  })

  it("handles very large ELO differences", {
    result <- elo_win_prob(3000, 1000)
    expect_gt(result, 0.99)

    result_low <- elo_win_prob(1000, 3000)
    expect_lt(result_low, 0.01)
  })
})
