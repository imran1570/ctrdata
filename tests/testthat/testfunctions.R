# testfunctions.R
# ralf.herold@gmx.net
# 2016-01-23

# run tests manually with:
# devtools::test()
# library(testthat)

# check code coverage:
# https://codecov.io/gh/rfhb/ctrdata/

# Mac OS X:
# brew services {start|stop} mongodb

library(ctrdata)
context("ctrdata functions")

# ensure warnings are not turned into errors
# getOption("warn")
# options(warn = 0)

# helper function to check if there
# is a useful internect connection
has_internet <- function(){
  if (is.null(curl::nslookup("r-project.org", error = FALSE))) {
    skip("No internet connection available. ")
  }
  if ("try-error" %in% c(
    class(try(httr::headers(httr::HEAD(
      url = utils::URLencode("https://clinicaltrials.gov"))),
      silent = TRUE)),
    class(try(httr::headers(httr::HEAD(
      url = utils::URLencode("https://www.clinicaltrialsregister.eu/"),
      config = httr::config(ssl_verifypeer = FALSE)
      )),
      silent = TRUE))
  )
  ) {
    skip("One or more registers not available. ")
  }
}

# helper function to check mongodb
has_mongo <- function(){
  # check server
  tmp <- getOption("warn")
  options("warn" = 2)
  # test
  mongo_ok <- try(ctrdata:::ctrMongo(), silent = TRUE)
  # use test result
  options("warn" = tmp)
  if ("try-error" %in% class(mongo_ok)) {
    skip("No password-free localhost mongodb accessible.")
  }
}

# helper function to check tool chain
has_toolchain <- function(){

  tc_ok <- try({
    any(

      # the tests are similar to those in onload.R
      !suppressWarnings(installFindBinary("php --version")),
      !suppressWarnings(installFindBinary("php -r 'simplexml_load_string(\"\");'")),
      !suppressWarnings(installFindBinary("echo x | sed s/x/y/")),
      !suppressWarnings(installFindBinary("perl -V:osname")),
      !suppressMessages({
        tmp <- installCygwinWindowsTest()
        ifelse(is.null(tmp), TRUE, tmp)
      }),

      na.rm = TRUE)
  }, silent = TRUE)

  if ((class(tc_ok) == "try-error") || (tc_ok == TRUE)) {
    skip("One or more tool chain applications are not available.")
  }
}


# helper function to check mongodb
has_mongo_remote <- function(mdburi = "", ...) {

  # for maintainer's local testing uncomment
  #Sys.unsetenv("ctrdatamongopassword")

  mongo_ok <- try(ctrdata:::ctrMongo(
    uri = mdburi,
    collection = "", ...),
    silent = TRUE)
  #
  # use test result
  if ("try-error" %in% class(mongo_ok)) {
    skip("Remote mongodb not accessible.")
  }
}


#### local mongodb ####
test_that("local mongodb", {

  has_mongo()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # initialise = drop collections from mongodb
  try(mongolite::mongo(collection = coll,
                       url = "mongodb://localhost/users")$drop(),
      silent = TRUE)

  # test 1
  expect_message(dbQueryHistory(collection = coll),
                 "No history found in expected format.")

})


#### remote mongodb read only ####
test_that("remote mongodb read only", {

  ## brief testing of main functions

  has_toolchain()
  has_internet()

  # specify base uri for remote mongodb server, trailing slash
  mdburi <- "mongodb+srv://DWbJ7Wh@cluster0-b9wpw.mongodb.net/"

  # permissions are restricted to "find" in "dbperm" in "dbperm"
  # no other functions can be executed, no login possible

  # skip if no access despite internet
  has_mongo_remote(mdburi = mdburi, "bdTHh5cS")

  ## read-only tests

  # initialise - this collection has been filled with
  # documents from test "remote mongodb read write"
  coll <- "dbperm"

  # field get test
  expect_warning(tmp <- dbFindFields(namepart = "date",
                                     uri = paste0(mdburi, "dbperm"),
                                     password = "bdTHh5cS",
                                     collection = coll),
                 "Using alternative method")

  # read test
  expect_silent(
    tmp <- dbGetFieldsIntoDf(fields = c("a2_eudract_number",
                                        "overall_status",
                                        "record_last_import",
                                        "primary_completion_date",
                                        "x6_date_on_which_this_record_was_first_entered_in_the_eudract_database",
                                        "study_design_info",
                                        "e71_human_pharmacology_phase_i"),
                             uri = paste0(mdburi, "dbperm"),
                             password = "bdTHh5cS",
                             collection = coll)
  )

  # output tests
  expect_equal(dim(tmp)[2], 8)
  expect_true("POSIXct"   %in% class(tmp[["record_last_import"]]))
  expect_true("character" %in% class(tmp[["study_design_info"]]))

})


#### remote mongodb read write ####
test_that("remote mongodb read write", {

  ## brief testing of main functions
  # expected to work only on CI Travis
  # password is set as environment variable,
  # which is read by ctrdata main functions

  has_toolchain()
  has_internet()

  # specify base uri for remote mongodb server, trailing slash
  mdburi <- "mongodb+srv://7RBnH3BF@cluster0-b9wpw.mongodb.net/"

  has_mongo_remote(mdburi = mdburi)

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"


  # test 2a
  expect_equivalent(ctrLoadQueryIntoDb(
    queryterm = "2010-024264-18",
    register = "CTGOV",
    uri = paste0(mdburi, "dbtemp"),
    collection = coll)$n,
    1L)

  # test 2b
  expect_equivalent(ctrLoadQueryIntoDb(
    queryterm = "2010-024264-18",
    register = "EUCTR",
    uri = paste0(mdburi, "dbtemp"),
    collection = coll)$n,
    6L)

  # test 2c
  expect_true(
    length(
      suppressWarnings(
        dbFindFields(namepart = "date",
                     uri = paste0(mdburi, "dbtemp"),
                     collection = coll))) > 5)

  # clean up
  ctrdata:::ctrMongo(uri = paste0(mdburi, "dbtemp"),
                     collection = coll)$drop()

})


#### empty downloads ####
test_that("retrieve data from registers", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # test 3
  expect_equal(suppressWarnings(ctrLoadQueryIntoDb(
    queryterm = "query=NonExistingConditionGoesInHere",
    register = "EUCTR",
    collection = coll)$n),
    0L)

  # test 4
  expect_equal(suppressWarnings(ctrLoadQueryIntoDb(
    queryterm = "cond=NonExistingConditionGoesInHere",
    register = "CTGOV",
    collection = coll)$n),
    0L)

  # clean up is the end of script = drop collection from mongodb

})


#### ctgov new, update ####
test_that("retrieve data from register ctgov", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # test 5
  expect_message(ctrLoadQueryIntoDb(
    queryterm = "2010-024264-18",
    register = "CTGOV",
    collection = coll),
    "Imported or updated 1 trial")

  ## create and test updatable query

  q <- paste0("https://clinicaltrials.gov/ct2/results?term=osteosarcoma&type=Intr&phase=0&age=0&lup_e=")

  # test 6
  expect_message(capture_output(
    ctrLoadQueryIntoDb(
      paste0(q, "12%2F31%2F2008"),
      collection = coll,
      debug = TRUE,
      verbose = TRUE)),
    "Imported or updated ")

  # manipulate history to force testing updating
  # based on code in dbCTRUpdateQueryHistory
  hist <- dbQueryHistory(collection = coll)
  # manipulate query
  hist[nrow(hist), "query-term"] <- sub("(.*&lup_e=).*", "\\112%2F31%2F2009", hist[nrow(hist), "query-term"])
  # convert into json object
  json <- jsonlite::toJSON(list("queries" = hist))
  # update database
  mongolite::mongo(collection = coll,
                   url = "mongodb://localhost/users")$update(query = '{"_id":{"$eq":"meta-info"}}',
                                                             update = paste0('{ "$set" :', json, "}"),
                                                             upsert = TRUE)

  # test 7
  expect_message(suppressWarnings(ctrLoadQueryIntoDb(
    querytoupdate = "last", collection = coll)),
    "Imported or updated")

  remove("hist", "json", "q")

})


#### euctr new, fast, slow, update ####
test_that("retrieve data from register euctr", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  q <- paste0("https://www.clinicaltrialsregister.eu/ctr-search/search?query=",
              "neuroblastoma&status=completed&phase=phase-one&country=pl")
  # ctrGetQueryUrlFromBrowser(content = q)

  # test 11
  expect_message(suppressWarnings(
    ctrLoadQueryIntoDb(q,
                       collection = coll)),
    "Imported or updated")

  ## download without details
  # test 12
  expect_message(suppressWarnings(
    ctrLoadQueryIntoDb(q,
                       collection = coll,
                       details = FALSE)),
    "Imported or updated")

  ## create and test updatable query

  # only works for last 7 days with rss mechanism
  # query based on date is used since this avoids no trials are found

  date.today <- Sys.time()
  date.from  <- format(date.today - (60 * 60 * 24 * 12), "%Y-%m-%d")
  date.to    <- format(date.today - (60 * 60 * 24 *  6), "%Y-%m-%d")

  q <- paste0("https://www.clinicaltrialsregister.eu/ctr-search/search?query=",
              "&dateFrom=", date.from, "&dateTo=", date.to)
  # ctrOpenSearchPagesInBrowser(q)

  # test 13
  expect_message(suppressWarnings(
    ctrLoadQueryIntoDb(q,
                       collection = coll,
                       details = FALSE)),
    "Imported or updated ")

  # manipulate history to force testing updating
  # based on code in dbCTRUpdateQueryHistory
  hist <- dbQueryHistory(collection = coll)
  # manipulate query
  hist[nrow(hist), "query-term"]      <- sub(".*(&dateFrom=.*)&dateTo=.*", "\\1", q)
  hist[nrow(hist), "query-timestamp"] <- paste0(date.to, " 23:59:59")
  # convert into json object
  json <- jsonlite::toJSON(list("queries" = hist))
  # update database
  mongolite::mongo(collection = coll,
                   url = "mongodb://localhost/users")$update(query = '{"_id":{"$eq":"meta-info"}}',
                                                             update = paste0('{ "$set" :', json, "}"),
                                                             upsert = TRUE)

  # test 14
  expect_message(
    ctrLoadQueryIntoDb(querytoupdate = "last",
                       collection = coll,
                       details = FALSE),
    "(Imported or updated|First result page empty)")

  remove("hist", "json", "q", "date.from", "date.today", "date.to")

})


#### euctr results ####
test_that("retrieve results from register euctr", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  q <- paste0("https://www.clinicaltrialsregister.eu/ctr-search/search?query=",
              "2007-000371-42+OR+2011-004742-18")
  # ctrGetQueryUrlFromBrowser(content = q)
  # ctrOpenSearchPagesInBrowser(input = q)

  # test 15
  expect_message(suppressWarnings(
    ctrLoadQueryIntoDb(q,
                       euctrresults = TRUE,
                       collection = coll,
                       debug = TRUE)),
    "Imported or updated results for")

  tmp <- dbGetFieldsIntoDf(fields = c("a2_eudract_number",
                                      "endPoints.endPoint.title",
                                      "firstreceived_results_date",
                                      "e71_human_pharmacology_phase_i",
                                      "version_results_history"),
                           collection = coll,
                           stopifnodata = FALSE)

  # test 16
  expect_true(!any(tmp[tmp$a2_eudract_number == "2007-000371-42", c(1, 2, 3)] == ""))
  expect_true(all(c(tmp$firstreceived_results_date[tmp$a2_eudract_number == "2007-000371-42"] == as.Date("2015-07-29"),
                    tmp$firstreceived_results_date[tmp$a2_eudract_number == "2011-004742-18"] == as.Date("2016-07-28"))))

  # test 16a
  expect_true(class(tmp$firstreceived_results_date)     == "Date")
  expect_true(class(tmp$e71_human_pharmacology_phase_i) == "logical")

})

#### browser show query ####
test_that("browser interaction", {

  # test 17
  expect_equal(suppressWarnings(ctrGetQueryUrlFromBrowser("something_insensible")), NULL)

  # ctgov

  q <- "https://clinicaltrials.gov/ct2/results?type=Intr&cond=cancer&age=0"

  tmp <- ctrGetQueryUrlFromBrowser(content = q)

  # test 18
  expect_is(tmp, "data.frame")

  # test 19
  expect_warning(ctrGetQueryUrlFromBrowser(content = "ThisDoesNotExist"),
                 "no clinical trial register search URL found")

  has_internet()

  # test 20
  expect_message(ctrOpenSearchPagesInBrowser(input = q),
                 "Opening browser for search:")

  # test 21
  expect_message(ctrOpenSearchPagesInBrowser(input = tmp),
                 "Opening browser for search:")

  # euctr

  q <- "https://www.clinicaltrialsregister.eu/ctr-search/search?query=&age=under-18&status=completed"

  tmp <- ctrGetQueryUrlFromBrowser(content = q)

  # test 22
  expect_is(tmp, "data.frame")

  # test 23
  expect_message(ctrOpenSearchPagesInBrowser(q),
                 "Opening browser for search:")

  # test 24
  expect_message(ctrOpenSearchPagesInBrowser(tmp),
                 "Opening browser for search:")

  # both registers

  # test 25
  expect_equal(ctrOpenSearchPagesInBrowser(register = c("EUCTR", "CTGOV"), copyright = TRUE), TRUE)

  # test with database

  has_mongo()
  has_toolchain()

  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # test 26
  expect_message(ctrOpenSearchPagesInBrowser(dbQueryHistory(collection = coll)[1, ]),
                 "Opening browser for search:")

  tmp <-  data.frame(lapply(dbQueryHistory(collection = coll),
                            tail, 1L), stringsAsFactors = FALSE)
  names(tmp) <- sub("[.]", "-", names(tmp))

  # test 27
  expect_message(ctrOpenSearchPagesInBrowser(tmp),
                 "Opening browser for search:")

})


#### db fields and records ####
test_that("operations on database after download from register", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # test 28
  expect_error(dbFindFields(
    namepart = c("onestring", "twostring"),
    collection = coll),
    "Name part should have only one element.")

  expect_error(dbFindFields(
    namepart = list("onestring", "twostring"),
    collection = coll),
    "Name part should be atomic.")

  expect_error(dbFindFields(namepart = "",
                            collection = coll),
               "Empty name part string.")

  # test 31
  expect_type(dbFindFields(
    namepart = "date",
    collection = coll),
    "character")

  expect_message(dbFindFields(
    namepart = "ThisNameShouldNotExistAnywhere",
    collection = coll), "Using cache of fields.")

  expect_equivalent(ctrLoadQueryIntoDb(
    queryterm = "2010-024264-18",
    register = "CTGOV",
    collection = coll)$n,
    1L)

  expect_message(dbFindFields(
    namepart = "ThisNameShouldNotExistAnywhere",
    collection = coll),
    "Finding fields on server")

  # dbFindIdsUniqueTrials

  # test 33
  expect_message(dbFindIdsUniqueTrials(
    collection = coll,
    preferregister = "EUCTR"),
    "Searching multiple country records")

  # test 34
  expect_message(dbFindIdsUniqueTrials(
    collection = coll,
    preferregister = "CTGOV"),
    "Returning keys")

  # test 35
  expect_warning(dbFindIdsUniqueTrials(
    collection = coll,
    prefermemberstate = "3RD",
    include3rdcountrytrials = FALSE),
    "Preferred EUCTR version set to 3RD country trials, but include3rdcountrytrials was FALSE")


  # dbGetFieldsIntoDf

  # test 36
  expect_error(dbGetFieldsIntoDf(
    fields = "ThisDoesNotExist",
    collection = coll),
    "For field: ThisDoesNotExist no data could be extracted")

  # test 37
  expect_error(dbGetFieldsIntoDf(
    fields = "",
    collection = coll),
    "'fields' contains empty elements")

  # test 38
  expect_error(dbGetFieldsIntoDf(
    fields = list("ThisDoesNotExist"),
    collection = coll),
    "Input should be a vector of strings of field names.")


  # clean up = drop collections from mongodb

  # test 38
  expect_equivalent(mongolite::mongo(collection = coll, url = "mongodb://localhost/users")$drop(), TRUE)

})


#### deduplication ####
test_that("operations on database for deduplication", {

  has_mongo()
  has_internet()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # get some trials with corresponding numbers
  # ctrLoadQueryIntoDb(queryterm = "NCT00134030", register = "CTGOV", collection = coll) # EUDRACT-2004-000242-20
  # ctrLoadQueryIntoDb(queryterm = "NCT01516580", register = "CTGOV", collection = coll) # 2010-019224-31
  # ctrLoadQueryIntoDb(queryterm = "NCT00025597", register = "CTGOV", collection = coll) # this is not in euctr
  # ctrLoadQueryIntoDb(queryterm = "2010-019224-31", register = "EUCTR", collection = coll)
  # ctrLoadQueryIntoDb(queryterm = "2004-000242-20", register = "EUCTR", collection = coll)
  # ctrLoadQueryIntoDb(queryterm = "2005-000915-80", register = "EUCTR", collection = coll) # this is not in ctgov
  # ctrLoadQueryIntoDb(queryterm = "2014-005674-11", register = "EUCTR", collection = coll) # this is 3rd country only
  # ctrLoadQueryIntoDb(queryterm = "2016-002347-41", register = "EUCTR", collection = coll) # in eu and 3rd country

  ctrLoadQueryIntoDb(
    queryterm = "NCT00134030 OR NCT01516580 OR NCT00025597",
    register = "CTGOV",
    collection = coll)

  ctrLoadQueryIntoDb(
    queryterm = "2010-019224-31 OR 2004-000242-20 OR 2005-000915-80 OR 2014-005674-11 OR 2016-002347-41",
    register = "EUCTR",
    collection = coll)

  # test combinations of parameters

  # test 41
  tmp <- dbFindIdsUniqueTrials(collection = coll)
  expect_true(all.equal(tmp, c("2004-000242-20-GB", "2005-000915-80-GB", "2010-019224-31-GB",
                               "2014-005674-11-3RD", "2016-002347-41-GB", "NCT00025597"),
                        check.attributes = FALSE))

  # test 42
  tmp <- dbFindIdsUniqueTrials(collection = coll, include3rdcountrytrials = FALSE) # removes 2014-005674-11
  expect_true(all.equal(tmp, c("2004-000242-20-GB", "2005-000915-80-GB", "2010-019224-31-GB",
                               "2016-002347-41-GB", "NCT00025597"),
                        check.attributes = FALSE))

  # test 43
  tmp <- dbFindIdsUniqueTrials(collection = coll, prefermemberstate = "3RD") # changes 2016-002347-41
  expect_true(all.equal(tmp, c("2004-000242-20-GB", "2005-000915-80-GB", "2010-019224-31-GB", "2014-005674-11-3RD",
                               "2016-002347-41-3RD", "NCT00025597"),
                        check.attributes = FALSE))

  # test 44
  tmp <- dbFindIdsUniqueTrials(collection = coll, prefermemberstate = "IT")
  expect_true(all.equal(tmp, c("2004-000242-20-GB", "2005-000915-80-IT", "2010-019224-31-IT", "2014-005674-11-3RD",
                               "2016-002347-41-GB", "NCT00025597"),
                        check.attributes = FALSE))

  # test 45
  tmp <- dbFindIdsUniqueTrials(collection = coll, preferregister = "CTGOV")
  expect_true(all.equal(tmp, c("NCT00025597", "NCT00134030", "NCT01516580", "2005-000915-80-GB",
                              "2014-005674-11-3RD", "2016-002347-41-GB"),
                        check.attributes = FALSE))

  # test 46
  tmp <- dbFindIdsUniqueTrials(collection = coll, preferregister = "CTGOV", prefermemberstate = "IT")
  expect_true(all.equal(tmp, c("NCT00025597", "NCT00134030", "NCT01516580", "2005-000915-80-IT",
                               "2014-005674-11-3RD", "2016-002347-41-GB"),
                        check.attributes = FALSE))


  # clean up = drop collections from mongodb

  # test 47
  expect_equivalent(mongolite::mongo(collection = coll, url = "mongodb://localhost/users")$drop(), TRUE)

})



#### annotations ####
test_that("annotate queries", {

  has_internet()
  has_mongo()
  has_toolchain()

  # initialise
  coll <- "ThisNameSpaceShouldNotExistAnywhereInAMongoDB"

  # test 49
  expect_message(ctrLoadQueryIntoDb(
    queryterm = "NCT01516567",
    register = "CTGOV",
    collection = coll,
    annotation.text = "ANNO",
    annotation.mode = "replace"),
    "Imported or updated 1 trial")

  # test 50
  expect_message(ctrLoadQueryIntoDb(
    queryterm = "NCT01516567",
    register = "CTGOV",
    collection = coll,
    annotation.text = "APPEND",
    annotation.mode = "append"),
    "Imported or updated 1 trial")

  expect_message(ctrLoadQueryIntoDb(
    queryterm = "NCT01516567",
    register = "CTGOV",
    collection = coll,
    annotation.text = "PREPEND",
    annotation.mode = "prepend"),
    "Imported or updated 1 trial")

  # test 51
  expect_message(ctrLoadQueryIntoDb(
    queryterm = "2010-024264-18",
    register = "EUCTR",
    collection = coll,
    annotation.text = "EUANNO",
    annotation.mode = "replace"),
    "Imported or updated")

  # test 52

  tmp <- dbGetFieldsIntoDf(
    fields = "annotation",
    collection = coll)

  tmp <- tmp[tmp[["_id"]] %in%
               dbFindIdsUniqueTrials(
                 collection = coll) , ]

  expect_equal(sort(tmp[["annotation"]]),
               sort(c("EUANNO", "PREPEND ANNO APPEND")))

})


#### df operations ####
test_that("operations on data frame", {

  df <- data.frame("var1" = 1:3,
                   "var2" = 2:4,
                   stringsAsFactors = FALSE)

  statusvalues <- list("Firstvalues" = c("12", "23"),
                       "Lastvalue"   = c("34"))

  # dfMergeTwoVariablesRelevel

  # test 53
  expect_error(dfMergeTwoVariablesRelevel(list("var1", "var2")),
               "Need a data frame as input.")

  # test 54
  expect_message(dfMergeTwoVariablesRelevel(df = df,
                                            colnames = c("var1", "var2")),
                 "Unique values returned: 12, 23, 34")

  # test 55
  expect_is(dfMergeTwoVariablesRelevel(df = df,
                                       colnames = c("var1", "var2")),
            "character")

  # test 56
  expect_message(dfMergeTwoVariablesRelevel(df = df,
                                            colnames = c("var1", "var2"),
                                            levelslist = statusvalues),
                 "Unique values returned: Firstvalues, Lastvalue")

  # test 57
  expect_error(dfMergeTwoVariablesRelevel(df = df,
                                          colnames = 1:3),
               "Please provide exactly two column names.")


})


#### active substance ####
test_that("operations on data frame", {

  has_internet()

  # test 57
  expect_equal(sort(ctrFindActiveSubstanceSynonyms(activesubstance = "imatinib")[1:4]),
               sort(c("gleevec", "glivec", "imatinib", "sti 571")))


})
