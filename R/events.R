#!/usr/bin/env Rscript

`%||%` <- rlang::`%||%`

yaml_path <- here::here("scenarios.yaml")
output_dir <- here::here("data")

config <- yaml::read_yaml(yaml_path)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

years <- seq(
  as.integer(config$start_year),
  as.integer(config$end_year)
)

pecan_events_version <- config$pecan_events_version %||% "0.1.0"

format_date <- function(year, value) {
  lubridate::ymd(paste(year, value))
}

event_key <- function(event_cfg) {
  if (is.null(event_cfg$name)) {
    event_cfg$event_type
  } else {
    # TODO determine how to implement
    # (illustrative implementation, not currently used)
    # need to uniquely identify each event to allow merge_events
    # to handle multiple instances of the same event_type within a year
    # not clear if 'name' is the way to do this
    # or if building scenarios
    # off of a baseline is the way to do this
    stringr::str_c(
      event_cfg$event_type,
      event_cfg$name,
      sep = "::"
    )
  }
}

merge_events <- function(baseline_events, overrides) {
  baseline_events <- baseline_events %||% list()
  overrides <- overrides %||% list()

  if (length(overrides) == 0) {
    return(baseline_events)
  }

  baseline_keys <- purrr::map_chr(baseline_events, event_key)

  purrr::reduce(overrides, function(acc, override) {
    key <- event_key(override)
    idx <- match(key, baseline_keys)
    if (is.na(idx)) {
      baseline_keys <<- c(baseline_keys, key)
      append(acc, list(override))
    } else {
      acc[[idx]] <- modifyList(acc[[idx]], override, keep.null = TRUE)
      acc
    }
  }, .init = baseline_events)
}

expand_event_config <- function(event_cfg, year) {
  event_fields <- event_cfg
  event_fields$name <- NULL
  event_fields$date <- NULL
  event_fields <- purrr::compact(event_fields)

  date_spec <- event_cfg$date
  dates <- if (is.list(date_spec) && !is.null(date_spec$start)) {
    start_date <- format_date(year, date_spec$start)
    seq_dates <- start_date +
      lubridate::days(
        seq(0, by = date_spec$every_days, length.out = date_spec$n_events)
      )
    format(seq_dates, "%Y-%m-%d")
  } else {
    purrr::map_chr(date_spec, ~ format(format_date(year, .x), "%Y-%m-%d"))
  }

  tibble::tibble(date = dates) |>
    dplyr::mutate(!!!event_fields)
}

purrr::iwalk(
  config$scenarios,
  function(overrides, scenario_name) {
    overrides <- overrides %||% list()
    scenario_events_config <- merge_events(config$baseline$events, overrides$events)

    scenario_events <- tidyr::crossing(
      year = years, event_cfg = scenario_events_config
    ) |>
      dplyr::mutate(
        events = purrr::map2(event_cfg, year, expand_event_config)
      ) |>
      dplyr::select(events) |>
      tidyr::unnest(events) |>
      dplyr::arrange(date, event_type)

    output_path <- file.path(
      output_dir, glue::glue("events_{scenario_name}.json")
    )
    site_payload <- list(
      pecan_events_version = pecan_events_version,
      site_id = config$site_id,
      events = jsonlite::fromJSON(jsonlite::toJSON(scenario_events, auto_unbox = TRUE))
    )

    json_text <- jsonlite::toJSON(site_payload, pretty = TRUE, auto_unbox = TRUE)
    writeLines(json_text, output_path)
    PEcAn.logger::logger.info(glue::glue("Wrote {output_path}"))

    is_valid <- PEcAn.data.land::validate_events_json(output_path, verbose = TRUE)
    if (!isTRUE(is_valid)) {
      PEcAn.logger::logger.severe(
        glue::glue("Schema validation failed for {output_path}")
      )
    }
  }
)
