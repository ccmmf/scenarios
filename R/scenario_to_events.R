#!/usr/bin/env Rscript
#
# Convert boolean practice assignments to events.json files
#
# Takes a field's practice assignments and priors to generate a
# management event time series in PEcAn events.json format.
#
#
# See also:
#   - R/sample_priors.R for sampling functions
#   - R/scenario_to_boolean.R for practice assignment
#   - data/management_priors.yaml for parameter distributions

`%||%` <- rlang::`%||%`


#' Convert field practice assignment to events.json
#'
#' Given a field's assigned practices and parameter priors, generates
#' a complete events.json file.
#'
#' @param field_id Character. Unique field identifier.
#' @param practices Character vector. Practices assigned to this field.
#'   Empty vector means baseline management only.
#' @param crop_pft Character. Crop plant functional type (e.g., "annual_row_crop").
#' @param priors List. Management priors from load_priors().
#' @param years Integer vector. Years to generate events for.
#' @param sample_params Logical. If TRUE, sample from priors; if FALSE, use means.
#' @param seed Random seed for reproducibility.
#'
#' @return List in events.json format with structure:
#'   - pecan_events_version: "0.1.0"
#'   - site_id: field_id
#'   - events: data frame of events
#'
#' @details
#' For each year:
#' 1. Get baseline events for crop_pft (tillage, fertilization, planting, irrigation, harvest)
#' 2. Apply practice modifications:
#'    - compost: Add organic fertilization event
#'    - no_till: Set tillage_eff to 0
#'    - reduced_till: Set tillage_eff to 0.10
#'    - cover_crop: Add planting and termination events
#'
#' @examples
#' \dontrun{
#' priors <- load_priors()
#' events <- field_to_events_json(
#'   field_id = "field_001",
#'   practices = c("compost", "reduced_till"),
#'   crop_pft = "annual_row_crop",
#'   priors = priors,
#'   years = 2025:2030,
#'   sample_params = TRUE,
#'   seed = 42
#' )
#' jsonlite::write_json(events, "events_field_001.json", pretty = TRUE, auto_unbox = TRUE)
#' }
#'
#' @export
field_to_events_json <- function(field_id,
                                  practices,
                                  crop_pft,
                                  priors,
                                  years,
                                  sample_params = TRUE,
                                  seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  if (is.null(priors) || !is.list(priors)) {
    PEcAn.logger::logger.severe("priors must be a valid list from load_priors()")
  }
  
  if (is.null(priors$practices)) {
    PEcAn.logger::logger.severe("priors missing 'practices' key")
  }
  
  practices <- as.character(practices)
  practices <- practices[!is.na(practices) & practices != ""]
  
  crop_baseline <- get_crop_baseline(crop_pft, priors)
  
  all_events <- lapply(years, function(yr) {
    build_year_events(
      year = yr,
      crop_baseline = crop_baseline,
      practices = practices,
      priors = priors,
      sample_params = sample_params
    )
  })
  
  all_events <- do.call(rbind, all_events)
  all_events <- all_events[order(all_events$date), ]
  rownames(all_events) <- NULL
  
  list(
    pecan_events_version = "0.1.0",
    site_id = field_id,
    events = all_events
  )
}


#' Get baseline configuration for a crop type
#'
#' @param crop_pft Plant functional type
#' @param priors Loaded priors
#' @return Baseline configuration list
#' @keywords internal
get_crop_baseline <- function(crop_pft, priors) {
  if (!is.null(priors$crop_baselines[[crop_pft]])) {
    return(priors$crop_baselines[[crop_pft]])
  }
  
  pft_to_default <- list(
    annual_row_crop = "processing_tomato",
    perennial_woody = "almond",
    grazing_land = NULL,
    all_cropland = "processing_tomato"
  )
  
  default_crop <- pft_to_default[[crop_pft]]
  
  if (!is.null(default_crop) && !is.null(priors$crop_baselines[[default_crop]])) {
    return(priors$crop_baselines[[default_crop]])
  }
  
  # Generic baseline
  list(
    pft = crop_pft,
    events = list(
      tillage = list(practice = "conventional_tillage"),
      fertilization = list(practice = "synthetic_fertilizer_annual"),
      irrigation = list(practice = "irrigation_sprinkler"),
      harvest = list(practice = "harvest_grain")
    )
  )
}


#' Build events for a single year
#'
#' @param year Integer year
#' @param crop_baseline Baseline config for crop
#' @param practices Character vector of assigned practices
#' @param priors Full priors list
#' @param sample_params Whether to sample or use means
#'
#' @return Data frame of events for this year
#' @keywords internal
build_year_events <- function(year, crop_baseline, practices, priors, sample_params) {
  
  events <- list()
  
  # Tillage
  tillage_eff <- if ("no_till" %in% practices) {
    0.0
  } else if ("reduced_till" %in% practices) {
    get_param_value(
      priors$practices$reduced_tillage$parameters$tillage_eff_0to1,
      sample_params,
      default = 0.10
    )
  } else {
    get_param_value(
      priors$practices$conventional_tillage$parameters$tillage_eff_0to1,
      sample_params,
      default = 0.35
    )
  }
  
  if (tillage_eff > 0) {
    tillage_date <- get_param_value(
      priors$practices$conventional_tillage$parameters$date,
      sample_params,
      default = "03-20"
    )
    events$tillage <- data.frame(
      date = format_event_date(year, tillage_date),
      event_type = "tillage",
      tillage_eff_0to1 = tillage_eff,
      stringsAsFactors = FALSE
    )
  }
  
  # Fertilization
  if ("compost" %in% practices) {
    compost_params <- priors$practices$compost_application$parameters
    
    org_c <- get_param_value(compost_params$org_c_kg_m2, sample_params, default = 0.40)
    cn_ratio <- get_param_value(compost_params$cn_ratio, sample_params, default = 16)
    org_n <- org_c / cn_ratio
    compost_date <- get_param_value(compost_params$date, sample_params, default = "02-20")
    
    events$fertilization_compost <- data.frame(
      date = format_event_date(year, compost_date),
      event_type = "fertilization",
      org_c_kg_m2 = org_c,
      org_n_kg_m2 = org_n,
      stringsAsFactors = FALSE
    )
  } else if ("biochar" %in% practices) {
    # Default: 2 tons/ac dry biochar at 70% C = ~0.31 kg C/m2
    biochar_c <- get_param_value(NULL, sample_params, default = 0.31)
    biochar_date <- "02-15"
    
    events$fertilization_biochar <- data.frame(
      date = format_event_date(year, biochar_date),
      event_type = "fertilization",
      org_c_kg_m2 = biochar_c,
      org_n_kg_m2 = biochar_c / 100,
      stringsAsFactors = FALSE
    )
  } else {
    synth_params <- priors$practices$synthetic_fertilizer_annual$parameters
    
    nh4_n <- get_param_value(synth_params$nh4_n_kg_m2, sample_params, default = 0.018)
    fert_date <- get_param_value(synth_params$date, sample_params, default = "03-25")
    
    events$fertilization <- data.frame(
      date = format_event_date(year, fert_date),
      event_type = "fertilization",
      nh4_n_kg_m2 = nh4_n,
      stringsAsFactors = FALSE
    )
  }
  
  # Cover crop
  if ("cover_crop" %in% practices) {
    cc_params <- priors$practices$cover_crop_annual$parameters
    
    plant_date <- get_param_value(cc_params$planting_date, sample_params, default = "11-01")
    term_date <- get_param_value(cc_params$termination_date, sample_params, default = "03-20")
    
    events$cover_crop_plant <- data.frame(
      date = format_event_date(year, plant_date),
      event_type = "planting",
      leaf_c_kg_m2 = 0.001,
      stringsAsFactors = FALSE
    )
    
    events$cover_crop_terminate <- data.frame(
      date = format_event_date(year, term_date),
      event_type = "harvest",
      frac_above_removed_0to1 = 0,
      frac_below_removed_0to1 = 0,
      stringsAsFactors = FALSE
    )
  }
  
  # Main crop planting
  planting_cfg <- crop_baseline$events$planting
  
  plant_date <- if (!is.null(planting_cfg$date)) {
    get_param_value(planting_cfg$date, sample_params, default = "04-15")
  } else {
    "04-15"
  }
  
  leaf_c <- if (!is.null(planting_cfg$leaf_c_kg_m2)) {
    get_param_value(planting_cfg$leaf_c_kg_m2, sample_params, default = 0.0034)
  } else {
    0.0034
  }
  
  events$planting <- data.frame(
    date = format_event_date(year, plant_date),
    event_type = "planting",
    leaf_c_kg_m2 = leaf_c,
    stringsAsFactors = FALSE
  )
  
  # Irrigation
  irrig_practice_name <- if ("irrigation_drip" %in% practices) {
    "irrigation_drip"
  } else {
    "irrigation_sprinkler"
  }
  
  irrig_params <- priors$practices[[irrig_practice_name]]$parameters
  
  n_events_spec <- irrig_params$n_events
  n_events <- if (!is.null(n_events_spec)) {
    val <- get_param_value(n_events_spec, sample_params, default = 6)
    as.integer(round(val))
  } else {
    6L
  }
  n_events <- max(1L, min(n_events, 12L))
  
  seasonal_total <- get_param_value(
    irrig_params$seasonal_total_mm,
    sample_params,
    default = if (irrig_practice_name == "irrigation_drip") 350 else 550
  )
  amount_per_event <- seasonal_total / n_events
  
  method <- irrig_params$method$value %||% 
    (if (irrig_practice_name == "irrigation_drip") "soil" else "canopy")
  
  irrig_start_doy <- 135
  irrig_end_doy <- 260
  irrig_interval <- (irrig_end_doy - irrig_start_doy) / (n_events - 1)
  
  for (i in seq_len(n_events)) {
    doy <- round(irrig_start_doy + (i - 1) * irrig_interval)
    irrig_date <- format(as.Date(doy - 1, origin = paste0(year, "-01-01")), "%Y-%m-%d")
    
    events[[paste0("irrigation_", i)]] <- data.frame(
      date = irrig_date,
      event_type = "irrigation",
      amount_mm = round(amount_per_event, 1),
      method = method,
      stringsAsFactors = FALSE
    )
  }
  
  # Harvest
  harvest_params <- priors$practices$harvest_grain$parameters
  
  harvest_date <- get_param_value(harvest_params$date, sample_params, default = "10-10")
  frac_removed <- get_param_value(
    harvest_params$frac_above_removed_0to1,
    sample_params,
    default = 0.5
  )
  
  events$harvest <- data.frame(
    date = format_event_date(year, harvest_date),
    event_type = "harvest",
    frac_above_removed_0to1 = frac_removed,
    frac_below_removed_0to1 = 0,
    stringsAsFactors = FALSE
  )
  
  # Combine events
  events <- events[!sapply(events, is.null)]
  
  if (length(events) == 0) {
    return(data.frame(
      date = character(0),
      event_type = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  dplyr::bind_rows(events)
}


#' Get parameter value from prior specification
#'
#' @param param_spec Prior specification (may be constant, distribution, or direct value)
#' @param sample If TRUE, sample from distribution; if FALSE, return mean/mode
#' @param default Default value if param_spec is NULL or invalid
#' @return Single value (numeric or character)
#' @keywords internal
get_param_value <- function(param_spec, sample, default = NA) {
  
  if (is.null(param_spec)) {
    return(default)
  }
  
  if (!is.list(param_spec)) {
    return(param_spec)
  }
  
  dist <- param_spec$distribution
  
  if (is.null(dist)) {
    return(param_spec$value %||% default)
  }
  
  if (sample) {
    result <- tryCatch(
      sample_distribution(param_spec, n = 1),
      error = function(e) default
    )
    return(result)
  }
  
  central_value <- switch(dist,
    constant = param_spec$value,
    normal = param_spec$mean,
    truncnorm = param_spec$mean,
    beta = param_spec$a / (param_spec$a + param_spec$b),
    lognormal = exp(param_spec$meanlog),
    categorical = {
      if (!is.null(param_spec$probabilities)) {
        param_spec$choices[which.max(param_spec$probabilities)]
      } else {
        param_spec$choices[1]
      }
    },
    quantiles = param_spec$median,
    default
  )
  
  if (is.null(central_value) || length(central_value) == 0) {
    return(default)
  }
  
  central_value
}


#' Format date string for event
#'
#' @param year Integer year
#' @param date_spec Date specification (MM-DD format or full date)
#' @return ISO date string (YYYY-MM-DD)
#' @keywords internal
format_event_date <- function(year, date_spec) {
  if (is.null(date_spec) || is.na(date_spec)) {
    return(paste0(year, "-01-01"))
  }
  
  date_spec <- as.character(date_spec)
  
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", date_spec)) {
    return(date_spec)
  }
  
  if (grepl("^\\d{2}-\\d{2}$", date_spec)) {
    return(paste0(year, "-", date_spec))
  }
  
  tryCatch(
    as.character(as.Date(date_spec)),
    error = function(e) paste0(year, "-01-01")
  )
}


#' Batch convert scenario to events.json files for all fields
#'
#' Combines scenario_to_boolean_table() and field_to_events_json() to generate
#' events.json files for all fields in a scenario.
#'
#' @param scenario Validated scenario from load_scenario()
#' @param fields_sf Spatial fields data with field_id, county, crop_pft
#' @param year Year for boolean table evaluation
#' @param priors Management priors from load_priors()
#' @param output_dir Directory for output files
#' @param sample_params Whether to sample from priors (default TRUE)
#' @param seed Random seed for reproducibility
#' @param n_cores Number of cores for parallel processing (default 1)
#'
#' @return Character vector of output file paths (invisibly)
#'
#' @examples
#' \dontrun{
#' scenario <- load_scenario("examples/scenario_bau.yaml")
#' priors <- load_priors()
#' fields <- load_fields_data()
#' 
#' output_files <- scenario_to_events_batch(
#'   scenario = scenario,
#'   fields_sf = fields,
#'   year = 2030,
#'   priors = priors,
#'   output_dir = "output/events",
#'   seed = 42
#' )
#' }
#'
#' @export
scenario_to_events_batch <- function(scenario,
                                      fields_sf,
                                      year,
                                      priors,
                                      output_dir,
                                      sample_params = TRUE,
                                      seed = NULL,
                                      n_cores = 1L) {
  
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  
  bool_table <- scenario_to_boolean_table(scenario, fields_sf, year, seed)
  
  standard_cols <- c("field_id", "county", "crop_pft")
  practice_cols <- setdiff(names(bool_table), standard_cols)
  practice_cols <- practice_cols[sapply(bool_table[practice_cols], is.logical)]
  
  event_years <- seq(scenario$start_year, scenario$end_year)
  
  process_field <- function(i) {
    row <- bool_table[i, ]
    field_id <- row$field_id
    crop_pft <- row$crop_pft
    
    assigned_practices <- practice_cols[unlist(row[practice_cols])]
    
    field_seed <- if (!is.null(seed)) seed + i else NULL
    
    events_json <- field_to_events_json(
      field_id = field_id,
      practices = assigned_practices,
      crop_pft = crop_pft,
      priors = priors,
      years = event_years,
      sample_params = sample_params,
      seed = field_seed
    )
    
    output_path <- file.path(output_dir, paste0("events_", field_id, ".json"))
    json_text <- jsonlite::toJSON(events_json, pretty = TRUE, auto_unbox = TRUE)
    writeLines(json_text, output_path)
    
    output_path
  }
  
  n_fields <- nrow(bool_table)
  
  if (n_cores > 1L && requireNamespace("parallel", quietly = TRUE)) {
    output_files <- parallel::mclapply(
      seq_len(n_fields),
      process_field,
      mc.cores = n_cores
    )
    output_files <- unlist(output_files)
  } else {
    output_files <- character(n_fields)
    for (i in seq_len(n_fields)) {
      output_files[i] <- process_field(i)
    }
  }
  
  invisible(output_files)
}