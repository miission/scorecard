% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/var_filter.R
\name{var_filter}
\alias{var_filter}
\title{Variable Filter}
\usage{
var_filter(dt, y, x = NA, iv_limit = 0.02, na_perc_limit = 0.95,
  ele_perc_limit = 0.95, var_rm = NA, var_kp = NA)
}
\arguments{
\item{dt}{A data frame with both x (predictor/feature) and y (response/label) variables.}

\item{y}{Name of y variable.}

\item{x}{Name vector of x variables. Default NA. If x is NA, all variables exclude y will counted as x variables.}

\item{iv_limit}{The minimum IV of each kept variable, default 0.02.}

\item{na_perc_limit}{The maximum NA percent of each kept variable, default 0.95.}

\item{ele_perc_limit}{The maximum element (excluding NAs) percentage in each kept variable, default 0.95.}

\item{var_rm}{Name vector of force removed variables, default NA.}

\item{var_kp}{Name vector of force kept variables, default NA.}
}
\value{
A dataframe with y and selected x variables
}
\description{
This function filter variables base on the specified conditions, including minimum iv, maximum na percentage and maximum element percentage.
}
\examples{
# Load German credit data
data(germancredit)

# variable filter
dt_selected <- var_filter(germancredit, y = "creditability")

}
