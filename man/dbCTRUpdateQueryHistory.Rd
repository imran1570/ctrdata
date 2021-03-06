% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/main.R
\name{dbCTRUpdateQueryHistory}
\alias{dbCTRUpdateQueryHistory}
\title{dbCTRUpdateQueryHistory}
\usage{
dbCTRUpdateQueryHistory(register, queryterm, recordnumber, collection, uri,
  password, verbose)
}
\arguments{
\item{register}{Vector of abbreviations of registers to query, defaults to
"EUCTR"}

\item{queryterm}{Either a string with the full URL of a search in a register
or the data frame returned by the \link{ctrGetQueryUrlFromBrowser} or the
\link{dbQueryHistory} functions.
The queryterm is recorded in the collection \code{ns} for later use to
update records.}

\item{collection}{Name of collection (default is "ctrdata")}

\item{uri}{Default is mongodb://localhost/users/.
Address of database in mongodb server, based on mongo connection string
format: mongodb://[username@]host1[:port1][,...hostN[:portN]]]/database/
Do NOT include password, this will only be used from the parameter.
See \url{http://docs.mongodb.org/manual/reference/connection-string/}}

\item{password}{In case access requires credentials.
Note this defaults to the environment variable "ctrdatamongopassword".
(by means of \code{Sys.getenv("ctrdatamongopassword")}), to
support scripting without revealing secrets.}

\item{verbose}{Print information.}
}
\description{
dbCTRUpdateQueryHistory
}
\keyword{internal}
