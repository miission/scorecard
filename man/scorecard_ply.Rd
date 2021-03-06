% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/scorecard.R
\name{scorecard_ply}
\alias{scorecard_ply}
\title{Application of Scorecard}
\usage{
scorecard_ply(dt, card, only_total_score = TRUE)
}
\arguments{
\item{dt}{Original data}

\item{card}{Scorecard generated from \code{scorecard}.}

\item{only_total_score}{Logical, default TRUE. If it is TRUE, return total credit score only; if FALSE, return both total credit score and score points of each variables.}
}
\value{
Credit score
}
\description{
\code{scorecard_ply} calculates credit score using the results of \code{scorecard}.
}
\examples{
library(data.table)
library(scorecard)

# Traditional Credit Scoring Using Logistic Regression
# load germancredit data
data("germancredit")

# random subset 10 x variables
# rename creditability as y
dt <- setDT(germancredit)[, c(sample(20, 10), 21)][, `:=`(
  y = ifelse(creditability == "bad", 1, 0),
  creditability = NULL
)]

# woe binning ------
bins <- woebin(dt, "y")
dt_woe <- woebin_ply(dt, bins)

# glm ------
m <- glm( y ~ ., family = "binomial", data = dt_woe)
# summary(m)

\dontrun{
# Select a formula-based model by AIC
m_step <- step(m, direction="both")
m <- eval(m_step$call)
# summary(m)

# performance ------
# predicted proability
# dt_woe$pred <- predict(m, type='response', dt_woe)

# performace
# ks & roc plot
# perf_plot(dt_woe$y, dt_woe$pred)
}

# card
card <- scorecard(bins, m)

# score
# only total score
score1 <- scorecard_ply(dt, card)

\dontrun{
# credit score for both total and each variable
score2 <- scorecard_ply(dt, card, only_total_score = F)
}
}
\seealso{
\code{\link{scorecard}}
}
