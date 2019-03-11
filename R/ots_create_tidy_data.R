#' Downloads and processes the data from the API to return a human-readable tibble
#' @description This function accesses \code{api.tradestatistics.io} and
#' performs different API calls to return tidy data. and data transforming.
#' @param years Numeric value greater or equal to 1962 and lower of equal
#' to 2016. Default set to \code{NULL}.
#' @param reporter ISO code for country of reporter (e.g. \code{chl} for
#' Chile). Default set to \code{NULL}.
#' Run \code{countries} in case of doubt.
#' @param partner ISO code for country of partner (e.g. \code{chn} for
#' China). Default set to \code{NULL}.
#' Run \code{countries} in case of doubt.
#' @param product_code Character string (e.g. \code{0101} or \code{01}) to filter products.
#' Default set to \code{"all"}.
#' @param product_code_length Character string to indicate the granularity level on products
#' Default set to \code{4} (it can also take the values \code{6} or
#' \code{all}).
#' @param table Character string to select the table to obtain the data.
#' Default set to \code{yrpc} (Year - Reporter - Partner - Product Code).
#' Run \code{tables} in case of doubt.
#' @param max_attempts How many times to try to download data in case the
#' API or the internet connection fails when obtaining data. Default set
#' to \code{5}.
#' @return A tibble that describes bilateral trade metrics (imports,
#' exports, trade balance and relevant metrics
#' such as exports growth w/r to last year) between an \code{reporter}
#' and \code{partner} country.
#' @importFrom magrittr %>%
#' @importFrom dplyr as_tibble select filter mutate everything
#' everything left_join bind_rows rename matches
#' @importFrom stringr str_sub str_length
#' @importFrom rlang sym syms
#' @importFrom purrr map_df
#' @importFrom jsonlite fromJSON
#' @importFrom crul HttpClient
#' @export
#' @examples
#' \dontrun{
#' # The next example can take more than 5 seconds to compute,
#' # so these are just shown without evaluation according to CRAN rules
#' 
#' # Run `countries` to display the full table of countries
#' 
#' # What does Chile export to China? (2015)
#' ots_create_tidy_data(years = 2015, reporter = "chl", partner = "chn")
#' 
#' # What can we say about Horses exported by Chile? (1980)
#' ots_create_tidy_data(years = 1980, product_code = "0101", table = "yc")
#' ots_create_tidy_data(years = 1980, reporter = "chl", product_code = "0101", table = "yrc")
#' ots_create_tidy_data(years = 1980, reporter = "chl", partner = "arg", product_code = "0101", 
#' table = "yrpc")
#' }
#' @keywords functions

ots_create_tidy_data <- function(years = NULL,
                                 reporter = NULL,
                                 partner = NULL,
                                 product_code = "all",
                                 product_code_length = 4,
                                 table = "yrpc",
                                 max_attempts = 5) {

  # Package data (part 1) ---------------------------------------------------
  tables <- tradestatistics::ots_attributes_tables

  # Check tables ------------------------------------------------------------
  if (!table %in% tables$table) {
    stop(
      "
      The requested table does not exist. Please check the spelling or 
      explore the 'tables' table provided within this package.
      "
    )
  }

  # Check years -------------------------------------------------------------
  year_depending_queries <- grep("^reporters|rankings$|^y", tables$table, value = T)

  if (all(years %in% 1962:2016) != TRUE &
    table %in% year_depending_queries) {
    stop(
      "
      Provided that the table you requested contains a 'year' field,
      please verify that you are requesting data contained within 
      the years 1962-2016.
      "
    )
  }

  # Package data (part 2) ---------------------------------------------------
  products <- tradestatistics::ots_attributes_products
  countries <- tradestatistics::ots_attributes_countries

  # Check reporter and partner ----------------------------------------------
  reporter_depending_queries <- grep("^yr", tables$table, value = T)
  partner_depending_queries <- grep("^yrp", tables$table, value = T)

  if (!is.null(reporter)) {
    if (!reporter %in% countries$country_iso &
      table %in% reporter_depending_queries
    ) {
      reporter <- ots_country_code(reporter)
      match.arg(reporter, countries$country_iso)
    }
  }

  if (!is.null(partner)) {
    if (!partner %in% countries$country_iso &
      table %in% partner_depending_queries
    ) {
      partner <- ots_country_code(partner)
      match.arg(partner, countries$country_iso)
    }
  }

  # Read from API -----------------------------------------------------------
  data <- dplyr::as_tibble(
    purrr::map_df(.x = seq_along(years),
                   ~ots_read_from_api(
                     table = table,
                     max_attempts = max_attempts,
                     years = years[.x],
                     reporter = reporter,
                     partner = partner,
                     product_code = product_code,
                     product_code_length = product_code_length
                   )
    )
  )

  # no data in API message
  if (nrow(data) == 0) {
    stop("No data available. Try changing years or trade classification.")
  }

  # Add attributes based on codes, etc (and join years, if applicable) ------

  # include countries data
  tables_with_reporter <- c("yrpc", "yrp", "yrc", "yr")

  if (table %in% tables_with_reporter) {
    if (table %in% tables_with_reporter[1:2]) {
      data <- data %>%
        dplyr::left_join(dplyr::select(
          countries,
          !!!rlang::syms(
            c("country_iso", "country_fullname_english")
          )
        ),
        by = c("reporter_iso" = "country_iso")
        ) %>%
        dplyr::rename(
          reporter_fullname_english = !!rlang::sym("country_fullname_english")
        ) %>%
        dplyr::select(
          !!!rlang::syms(c(
            "year",
            "reporter_iso",
            "partner_iso",
            "reporter_fullname_english"
          )),
          dplyr::everything()
        )
    } else {
      data <- data %>%
        dplyr::left_join(dplyr::select(
          countries,
          !!!rlang::syms(
            c("country_iso", "country_fullname_english")
          )
        ),
        by = c("reporter_iso" = "country_iso")
        ) %>%
        dplyr::rename(
          reporter_fullname_english = !!rlang::sym("country_fullname_english")
        ) %>%
        dplyr::select(
          !!!rlang::syms(c(
            "year",
            "reporter_iso",
            "reporter_fullname_english"
          )),
          dplyr::everything()
        )
    }
  }

  tables_with_partner <- c("yrpc", "yrp")

  if (table %in% tables_with_partner) {
    data <- data %>%
      dplyr::left_join(dplyr::select(
        countries,
        !!!rlang::syms(
          c("country_iso", "country_fullname_english")
        )
      ),
      by = c("partner_iso" = "country_iso")
      ) %>%
      dplyr::rename(
        partner_fullname_english = !!rlang::sym("country_fullname_english")
      ) %>%
      dplyr::select(
        !!!rlang::syms(c(
          "year",
          "reporter_iso",
          "partner_iso",
          "reporter_fullname_english",
          "partner_fullname_english"
        )),
        dplyr::everything()
      )
  }

  # include products data
  tables_with_product_code <- c("yrpc", "yrc", "yc")

  if (table %in% tables_with_product_code) {
    data <- data %>%
      dplyr::left_join(products, by = "product_code")

    if (table == "yrpc") {
      data <- data %>%
        dplyr::select(
          !!!rlang::syms(c(
            "year",
            "reporter_iso",
            "partner_iso",
            "reporter_fullname_english",
            "partner_fullname_english",
            "product_code",
            "product_code_length",
            "product_fullname_english",
            "group_code",
            "group_name"
          )),
          dplyr::everything()
        )
    }

    if (table == "yrc") {
      data <- data %>%
        dplyr::select(
          !!!rlang::syms(c(
            "year",
            "reporter_iso",
            "reporter_fullname_english",
            "product_code",
            "product_code_length",
            "product_fullname_english",
            "group_code",
            "group_name"
          )),
          dplyr::everything()
        )
    }

    if (table == "yc") {
      data <- data %>%
        dplyr::select(
          !!!rlang::syms(c(
            "year",
            "product_code",
            "product_code_length",
            "product_fullname_english",
            "group_code",
            "group_name"
          )),
          dplyr::everything()
        )
    }
  }

  return(data)
}