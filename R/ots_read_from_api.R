#' Reads data from the API (internal function)
#' @description Accesses \code{api.tradestatistics.io} and
#' performs different API calls to return \code{data.frames} by reading \code{JSON} data
#' @param year Year contained within the years specified in
#' api.tradestatistics.io/year_range (e.g. \code{1980}).
#' Default set to \code{NULL}.
#' @param reporter_iso ISO code for reporter country (e.g. \code{"chl"}). Default set to \code{"all"}.
#' @param partner_iso ISO code for partner country (e.g. \code{"chl"}). Default set to \code{"all"}.
#' @param product_code HS code (e.g. \code{0101} or \code{01}) to filter products.
#' Default set to \code{"all"}.
#' @param table Character string to select the table to obtain the data. Default set to \code{yrpc}
#' (Year - Reporter - Partner - product).
#' @param max_attempts Number of attempts to retry in case of data retrieving failure.
#' Default set to \code{5}.
#' @param use_localhost Logical to determine if the base URL shall be localhost instead
#' of api.tradestatistics.io. Default set to \code{FALSE}.
#' @importFrom jsonlite fromJSON
#' @importFrom crul HttpClient
#' @examples
#' \dontrun{
#' # The next examples can take more than 5 seconds to compute,
#' # so these are shown without evaluation according to CRAN rules
#'
#' # Run `countries` to display the full table of countries
#'
#' # What does Chile export to China? (1980)
#' ots_read_from_api(year = 1980, reporter_iso = "chl", partner_iso = "chn")
#'
#' # What can we say about chilean Horses export? (1980)
#' ots_read_from_api(year = 1980, product_code = "0101", table = "yc")
#' ots_read_from_api(year = 1980, reporter_iso = "chl", product_code = "0101", table = "yrc")
#' ots_read_from_api(
#'   year = 1980, reporter_iso = "chl", partner_iso = "arg", product_code = "0101",
#'   table = "yrpc"
#' )
#' }
#' @keywords internal
ots_read_from_api <- function(year = NULL,
                              reporter_iso = NULL,
                              partner_iso = NULL,
                              product_code = "all",
                              group_code = "all",
                              section_code = "all",
                              table = "yr",
                              max_attempts = 5,
                              use_localhost = FALSE) {
  stopifnot(max_attempts > 0)

  url <- switch(
    table,
    "countries" = "countries",
    "products" = "products",
    "reporters" = sprintf("reporters?y=%s", year),
    "country_rankings" = sprintf("country_rankings?y=%s", year),
    "product_rankings" = sprintf("product_rankings?y=%s", year),
    "yrpc" = sprintf(
      "yrpc?y=%s&r=%s&p=%s&c=%s",
      year, reporter_iso, partner_iso, product_code
    ),
    "yrpc-ga" = sprintf(
      "yrpc-ga?y=%s&r=%s&p=%s&g=%s",
      year, reporter_iso, partner_iso, group_code
    ),
    "yrpc-sa" = sprintf(
      "yrpc-sa?y=%s&r=%s&p=%s&s=%s",
      year, reporter_iso, partner_iso, section_code
    ),
    "yrpc-sga" = sprintf(
      "yrpc-sga?y=%s&r=%s&p=%s&g=%s&s=%s",
      year, reporter_iso, partner_iso, group_code, section_code
    ),
    "yrp" = sprintf("yrp?y=%s&r=%s&p=%s", year, reporter_iso, partner_iso),
    "yrc" = sprintf(
      "yrc?y=%s&r=%s&c=%s",
      year, reporter_iso, product_code
    ),
    "yrc-ga" = sprintf(
      "yrc-ga?y=%s&r=%s&c=%s&g=%s",
      year, reporter_iso, product_code, group_code
    ),
    "yrc-sa" = sprintf(
      "yrc-sa?y=%s&r=%s&c=%s&s=%s",
      year, reporter_iso, product_code, section_code
    ),
    "yrc-sga" = sprintf(
      "yrc-sga?y=%s&r=%s&c=%s&g=%s&s=%s",
      year, reporter_iso, product_code, group_code, section_code
    ),
    "yr" = sprintf("yr?y=%s&r=%s", year, reporter_iso),
    "yr-short" = sprintf("yr-short?y=%s&r=%s", year, reporter_iso),
    "yr-ga" = sprintf("yr-ga?y=%s&r=%s", year, reporter_iso),
    "yr-sa" = sprintf("yr-sa?y=%s&r=%s", year, reporter_iso),
    "yc" = sprintf("yc?y=%s&c=%s", year, product_code)
  )

  if (use_localhost == TRUE) {
    base_url <- "http://localhost:8080/"
  } else {
    base_url <- "https://api.tradestatistics.io/"
  }

  resp <- HttpClient$new(url = base_url)
  resp <- resp$get(url)

  # on a successful GET, return the response
  if (resp$status_code == 200) {
    combination <- paste(year, reporter_iso, partner_iso, sep = ", ")
    
    if (product_code != "all") {
      combination <- paste(combination, product_code, sep = ", ")
    }
    
    if (group_code != "all") {
      combination <- paste(combination, group_code, sep = ", ")
    }
    
    if (section_code != "all") {
      combination <- paste(combination, section_code, sep = ", ")
    }
    
    message(sprintf("Downloading data for the combination %s...", combination))

    data <- try(
      fromJSON(resp$parse(encoding = "UTF-8"))
    )

    if (!is.data.frame(data)) {
      stop("It wasn't possible to obtain data. Provided this function tests your internet connection\nyou misspelled a reporter, partner or table, or there was a server problem. Please check and try again.")
    }

    return(data)
  } else if (max_attempts == 0) {
    # when attempts run out, stop with an error
    stop("Cannot connect to the API. Either the server is down or there is a connection problem.")
  } else {
    # otherwise, sleep a second and try again
    Sys.sleep(1)
    ots_read_from_api(year, reporter_iso, partner_iso, product_code, group_code,
                      section_code, table, max_attempts = max_attempts - 1,
                      use_localhost
    )
  }
}
