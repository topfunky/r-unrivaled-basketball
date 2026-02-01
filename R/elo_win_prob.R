#' Calculate win probability for a team based on ELO ratings
#'
#' Uses the standard ELO formula: P(A) = 1 / (1 + 10^((R_B - R_A)/400))
#' where R_A and R_B are the ELO ratings of teams A and B.
#'
#' @param elo_a ELO rating of team A
#' @param elo_b ELO rating of team B
#' @return Probability that team A wins (between 0 and 1)
#' @export
#' @examples
#' elo_win_prob(1500, 1500)
#' elo_win_prob(1600, 1400)
#' elo_win_prob(1400, 1600)
elo_win_prob <- function(elo_a, elo_b) {
  prob <- 1 / (1 + 10^((elo_b - elo_a) / 400))
  return(prob)
}
