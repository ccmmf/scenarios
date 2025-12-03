#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(yaml)
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
yaml_path <- if (length(args) >= 1) args[[1]] else "scenarios.yaml"
output_dir <- if (length(args) >= 2) args[[2]] else "."

config <- yaml::read_yaml(yaml_path)
years <- seq(config$years$start, config$years$end)
pecan_events_version <- if (is.null(config$pecan_events_version)) {
  "0.1.0"
} else {
  config$pecan_events_version
}
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

make_date <- function(year, mmdd) {
  sprintf("%04d-%s", year, mmdd)
}

build_irrigation_events <- function(year, template, site_id) {
  events <- list()
  if (template$type == "fixed_dates") {
    for (mmdd in template$dates) {
      events <- append(events, list(list(
        site_id = site_id,
        date = make_date(year, mmdd),
        event_type = "irrigation",
        amount_mm = template$amount_mm,
        method = template$method
      )))
    }
  } else if (template$type == "interval") {
    start_date <- as.Date(make_date(year, template$start))
    seq_dates <- start_date + seq(0, by = template$frequency_days, length.out = template$n_events)
    for (idx in seq_along(seq_dates)) {
      current_date <- seq_dates[[idx]]
      events <- append(events, list(list(
        site_id = site_id,
        date = format(current_date, "%Y-%m-%d"),
        event_type = "irrigation",
        amount_mm = template$amount_mm,
        method = template$method
      )))
    }
  } else {
    stop(sprintf("Unsupported irrigation template type: %s", template$type))
  }
  events
}

build_year_events <- function(year, spec, config) {
  events <- list()
  site_id <- config$site_id
  cal <- config$calendar
  if (!is.null(spec$compost)) {
    events <- append(events, list(list(
      site_id = site_id,
      date = make_date(year, cal$compost),
      event_type = "fertilization",
      org_c_kg_m2 = spec$compost$org_c_kg_m2,
      org_n_kg_m2 = spec$compost$org_n_kg_m2
    )))
  }
  events <- append(events, list(list(
    site_id = site_id,
    date = make_date(year, cal$tillage),
    event_type = "tillage",
    tillage_eff_0to1 = spec$tillage_eff_0to1
  )))
  if (!is.null(spec$min_n_kg_m2) && spec$min_n_kg_m2 > 0) {
    events <- append(events, list(list(
      site_id = site_id,
      date = make_date(year, cal$mineral_n),
      event_type = "fertilization",
      nh4_n_kg_m2 = spec$min_n_kg_m2
    )))
  }
  events <- append(events, list(list(
    site_id = site_id,
    date = make_date(year, cal$planting),
    event_type = "planting",
    leaf_c_kg_m2 = spec$planting_leaf_c_kg_m2
  )))
  irrigation_spec <- config$irrigation_templates[[spec$irrigation_template]]
  events <- append(events, build_irrigation_events(year, irrigation_spec, site_id))
  events <- append(events, list(list(
    site_id = site_id,
    date = make_date(year, cal$harvest$date),
    event_type = "harvest",
    frac_above_removed_0to1 = cal$harvest$frac_above_removed_0to1,
    frac_below_removed_0to1 = cal$harvest$frac_below_removed_0to1
  )))
  events
}

validator <- NULL
if (requireNamespace("PEcAn.data.land", quietly = TRUE)) {
  validator <- PEcAn.data.land::validate_events_json
} else {
  warning("Package 'PEcAn.data.land' not installed; skipping schema validation.")
}

for (scenario_name in names(config$scenarios)) {
  overrides <- config$scenarios[[scenario_name]]
  if (is.null(overrides)) {
    overrides <- list()
  }
  spec <- modifyList(config$baseline, overrides)
  if (is.null(spec$planting_leaf_c_kg_m2)) {
    default_leaf_c <- config$planting_leaf_c_kg_m2
    if (is.null(default_leaf_c)) {
      default_leaf_c <- 0
    }
    spec$planting_leaf_c_kg_m2 <- default_leaf_c
  }
  scenario_events <- unlist(
    lapply(years, function(year) build_year_events(year, spec, config)),
    recursive = FALSE
  )
  output_path <- file.path(output_dir, sprintf("events_%s.json", scenario_name))
  site_payload <- list(
    pecan_events_version = pecan_events_version,
    site_id = config$site_id,
    events = scenario_events
  )
  json_text <- jsonlite::toJSON(site_payload, pretty = TRUE, auto_unbox = TRUE)
  writeLines(json_text, output_path)
  message(sprintf("Wrote %s", output_path))
  if (!is.null(validator)) {
    is_valid <- validator(output_path, verbose = TRUE)
    if (!isTRUE(is_valid)) {
      stop(sprintf("Schema validation failed for %s", output_path))
    }
  }
}
