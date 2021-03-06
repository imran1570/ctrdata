% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{dfMergeTwoVariablesRelevel}
\alias{dfMergeTwoVariablesRelevel}
\title{Merge two variables into one, optionally map values to new levels}
\usage{
dfMergeTwoVariablesRelevel(df = NULL, colnames = "",
  levelslist = NULL, ...)
}
\arguments{
\item{df}{A \link{data.frame} in which there are two variables (columns) to be
merged into one.}

\item{colnames}{A vector of length two with names of the two columns that hold
the variables to be merged. See \link{colnames} for how to obtain the names
of columns of a data frame.}

\item{levelslist}{A list with one slice each for a new value to be used for a
vector of old values (optional).}

\item{...}{for deprecated varnames parameter (will be removed)}
}
\value{
A vector of strings
}
\description{
Merge two variables into one, optionally map values to new levels
}
\examples{

\dontrun{
statusvalues <- list("ongoing" = c("Recruiting", "Active", "Ongoing",
                                   "Active, not recruiting", "Enrolling by invitation"),
                     "completed" = c("Completed", "Prematurely Ended", "Terminated"),
                     "other" = c("Withdrawn", "Suspended",
                                 "No longer available", "Not yet recruiting"))

dfMergeTwoVariablesRelevel(result, c("Recruitment", "x5_trial_status"), statusvalues)
}

}
