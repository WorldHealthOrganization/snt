#' @title Fuzzy match
#' @description Fuzzy match function, check this answer for more details:
#' https://stackoverflow.com/a/41560524/886198
#'
#' @param df Dataframe
#' @param col Column to match
#' @param method Method for fuzzy match
#' @param threshold Threshold for fuzzy match
#' @return Dataframe
#' @export
sn_check_fuzzy <- function(
  source, target = NULL, col, threshold = 0.1, method = "jw",
  export = NULL
) {
  source_col <- source[, .SD, .SDcols = col] |>
    unique()
  if (is.null(target)) {
    fuzzy <- fuzzyjoin::stringdist_join(
      source_col, source_col, distance_col = "dist", method = method,
      max_dist = threshold
    )
  } else {
    target_col <- target[, .SD, .SDcols = col] |>
      unique()
    fuzzy <- fuzzyjoin::stringdist_join(
      source_col, target_col, distance_col = "dist", method = method,
      max_dist = threshold
    )
  }
  setDT(fuzzy)
  setkey(fuzzy, dist)
  if (!(is.null(target))) {
    # get the first column name and the second column name
    col.x <- names(fuzzy)[1]
    col.y <- names(fuzzy)[2]
    fuzzy <- fuzzy[col.x != col.y, env = list(col.x = col.x, col.y = col.y)]
    col.x.in.target <- fuzzy[target_col, on = c(col.x = col),
      nomatch = NULL]
    col.y.in.target <- fuzzy[target_col, on = c(col.y = col),
      nomatch = NULL]
    fuzzy[col.x.in.target, on = col.x, col.x.in := TRUE]
    fuzzy[col.y.in.target, on = col.y, col.y.in := TRUE]
    if (!is.null(export)) {
      to_fix <- fuzzy[col.x.in == FALSE & col.y.in == TRUE]
      fwrite(to_fix, export)
    }
  }
}
#' Check laps
#' @param df data frame generated by fuzzy_match
#' @return data frame
#' @importFrom dplyr mutate if_else
#' @importFrom lubridate make_date
#' @importFrom rlang .data
#' @export
sn_check_laps <- function(df) {
  df |>
    dplyr::mutate(
      min_date.x = make_date(year = .data$min_year.x, month = .data$min_month.x),
      max_date.x = make_date(year = .data$max_year.x, month = .data$max_month.x),
      min_date.y = make_date(year = .data$min_year.y, month = .data$min_month.y),
      max_date.y = make_date(year = .data$max_year.y, month = .data$max_month.y)
    ) |>
    dplyr::mutate(
      laps_x_lt_y = if_else(.data$max_date.x < .data$min_date.y, "Y", "N"),
      laps_y_lt_x = if_else(.data$max_date.y < .data$min_date.x, "Y", "N"),
      laps = if_else(
        .data$laps_x_lt_y == "Y" | .data$laps_y_lt_x ==
          "Y", "Y", "N"
      ),
      laps = if_else(
        is.na(.data$laps),
        "Y", "N"
      )
    ) |>
    select(
      -laps_x_lt_y, -laps_y_lt_x, -min_year.x, -max_year.x,
      -min_month.x, -max_month.x, -min_year.y, -max_year.y,
      -min_month.y, -max_month.y, -min_date.x, -max_date.x,
      -min_date.y, -max_date.y
    )
}
#' Fuzzy match result
#' Identify and remove duplicate reports
#' @param df Dataframe
#' df: dataframe to be checked for duplicates
#' @param col column to be used for fuzzy matching
#' @param threshold minimum match level for fuzzy matching, default is 1.1
#' @param method fuzzy matching method, default is 'lv'
#' @param ... group_by columns to get the report status and duration for each group
#' @return Dataframe
#' @export
fuzzy_match_enhanced <- function(df, col, threshold = 1.1, method = "lv", ...) {
  # col: column to be used for fuzzy matching threshold:
  # minimum match level for fuzzy matching method: fuzzy
  # matching method report_id: name of report id column
  # report_start: name of report start date column
  # report_end: name of report end date column
  # report_status: name of report status column
  # report_status_type: status value to indicate report is
  # current report_status_date: name of report status date
  # column report_status_col: name of report status column
  # fuzzy_match: name of fuzzy match column overlap: name
  # of overlap column
  args <- enquos(...)  # get arguments
  # exclude year and month columns from args get report
  # duration
  report_duration_df <- df |>
    report_status(!!!args) |>
    get_report_duration(!!!args)
  fuzzy_matched_df <- df |>
    fuzzy_match(col, threshold, method, !!!args)
  overlapped <- fuzzy_matched_df |>
    left_join(report_duration_df, by = col) |>
    left_join(report_duration_df, by = c(match = col)) |>
    check_laps()
  fuzzy_matched_df <- fuzzy_matched_df |>
    left_join(overlapped, by = c(col, "match"))
  return(fuzzy_matched_df)
}
