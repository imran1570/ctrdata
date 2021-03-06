% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{installCygwinWindowsDoInstall}
\alias{installCygwinWindowsDoInstall}
\title{Convenience function to install a cygwin environment under MS Windows,
including perl, sed and php}
\usage{
installCygwinWindowsDoInstall(force = FALSE, proxy = "")
}
\arguments{
\item{force}{Set to \code{TRUE} to force updating and overwriting an existing
installation in \code{c:\\cygwin}}

\item{proxy}{Specify any proxy to be used for downloading via http, e.g.
"host_or_ip:port". \code{installCygwinWindowsDoInstall()} may detect and use
the proxy configuration uset in MS Windows to use an automatic proxy
configuration script. Authenticated proxies are not supported at this time.}
}
\description{
Alternatively and in case of difficulties, download and run the cygwin
setup yourself as follows: \code{cygwinsetup.exe --no-admin --quiet-mode
--verbose --upgrade-also --root c:/cygwin --site
http://www.mirrorservice.org/sites/sourceware.org/pub/cygwin/ --packages
perl,php-jsonc,php-simplexml}
}
