#!/usr/bin/env Rscript
#
# Scenario Validation Functions
#
# Validates user-provided scenario YAML files against schema and
# HSP practice eligibility rules.
#
# See also: data/scenario_schema.yaml for schema definition

`%||%` <- rlang::`%||%`


#' California county names (58 counties)
#' Used for domain = "california_counties" validation
CALIFORNIA_COUNTIES <- c(

"Alameda", "Alpine", "Amador", "Butte", "Calaveras", "Colusa",
  "Contra Costa", "Del Norte", "El Dorado", "Fresno", "Glenn", "Humboldt",
  "Imperial", "Inyo", "Kern", "Kings", "Lake", "Lassen", "Los Angeles",
  "Madera", "Marin", "Mariposa", "Mendocino", "Merced", "Modoc", "Mono",
  "Monterey", "Napa", "Nevada", "Orange", "Placer", "Plumas", "Riverside",
  "Sacramento", "San Benito", "San Bernardino", "San Diego", "San Francisco",
  "San Joaquin", "San Luis Obispo", "San Mateo", "Santa Barbara", "Santa Clara",
  "Santa Cruz", "Shasta", "Sierra", "Siskiyou", "Solano", "Sonoma", "Stanislaus",
  "Sutter", "Tehama", "Trinity", "Tulare", "Tuolumne", "Ventura", "Yolo", "Yuba"
)

#' Cal-Adapt climate regions (10 regions)
CALADAPT_REGIONS <- c(
  "Central Valley", "North Coast", "Sierra Nevada", "South Coast",
  "Inland Deserts", "San Francisco Bay Area", "Central Coast",
  "North Interior", "South Interior", "Sacramento Valley"
)

#' Valid plant functional types
VALID_PFTS <- c(
  "annual_row_crop", "perennial_woody", "grazing_land", "all_cropland",
  "processing_tomato", "almond", "walnut", "grape", "rice", "corn",
  "wheat", "alfalfa"
)

#' Valid HSP practices
#' Complete list from HSP 2026 Practice Guidelines (31 practices)
VALID_PRACTICES <- c(
  # Soil amendments
  "compost", "biochar", "mulching", "whole_orchard_recycling",
  # Tillage management
  "no_till", "reduced_till",
  # Cover and vegetation
  "cover_crop", "conservation_cover", "orchard_floor_cover", "conservation_crop_rotation",
  # Agroforestry
  "alley_cropping", "multistory_cropping", "silvopasture", "tree_shrub_establishment",
  # Linear and edge-of-field practices
  "hedgerow", "windbreak", "field_border", "filter_strip", "contour_buffer_strips",
  "grassed_waterway", "herbaceous_wind_barrier", "vegetative_barrier", "strip_cropping",
  # Riparian practices
  "riparian_forest_buffer", "riparian_herbaceous_cover",
  # Grazing land practices
  "prescribed_grazing", "range_planting", "pasture_hay_planting",
  # Special and regional
  "delta_rice"
)

#' Practice eligibility by PFT
#' Mapping from HSP 2026 Practice Guidelines
PRACTICE_ELIGIBILITY <- list(
  # Soil amendments
  compost = c("annual_row_crop", "perennial_woody", "grazing_land", "all_cropland"),
  biochar = c("annual_row_crop", "perennial_woody"),
  mulching = c("annual_row_crop", "perennial_woody"),
  whole_orchard_recycling = c("perennial_woody"),
  
  # Tillage management
  no_till = c("annual_row_crop", "perennial_woody"),
  reduced_till = c("annual_row_crop"),
  
  # Cover and vegetation
  cover_crop = c("annual_row_crop", "perennial_woody"),
  conservation_cover = c("annual_row_crop"),
  orchard_floor_cover = c("perennial_woody"),
  conservation_crop_rotation = c("annual_row_crop"),
  
  # Agroforestry
  alley_cropping = c("annual_row_crop"),
  multistory_cropping = c("annual_row_crop"),
  silvopasture = c("grazing_land"),
  tree_shrub_establishment = c("annual_row_crop", "grazing_land"),
  
  # Linear and edge-of-field practices
  hedgerow = c("annual_row_crop", "perennial_woody", "grazing_land"),
  windbreak = c("annual_row_crop", "perennial_woody", "grazing_land"),
  field_border = c("annual_row_crop"),
  filter_strip = c("annual_row_crop", "perennial_woody"),
  contour_buffer_strips = c("annual_row_crop"),
  grassed_waterway = c("annual_row_crop"),
  herbaceous_wind_barrier = c("annual_row_crop"),
  vegetative_barrier = c("annual_row_crop"),
  strip_cropping = c("annual_row_crop"),
  
  # Riparian practices
  riparian_forest_buffer = c("annual_row_crop", "grazing_land"),
  riparian_herbaceous_cover = c("annual_row_crop"),
  
  # Grazing land practices
  prescribed_grazing = c("grazing_land"),
  range_planting = c("grazing_land"),
  pasture_hay_planting = c("annual_row_crop"),
  
  # Special and regional
  delta_rice = c("annual_row_crop")
)

#' Incompatible practice pairs
INCOMPATIBLE_PRACTICES <- list(
  c("no_till", "reduced_till"),
  c("conservation_cover", "cover_crop"),
  c("conservation_cover", "pasture_hay_planting")
)


# --- Loading functions ---

#' Load and parse a scenario YAML file
#'
#' @param path Path to scenario YAML file
#' @return Parsed scenario list
#' @export
load_scenario <- function(path) {
  if (!file.exists(path)) {
    PEcAn.logger::logger.severe("Scenario file not found: ", path)
  }
  scenario <- yaml::read_yaml(path)
  scenario
}


# --- Validation fuctions ---
#' Validate a complete scenario specification
#'
#' Checks all required fields, valid values, and practice eligibility.
#'
#' @param scenario Parsed scenario list from load_scenario()
#' @param stop_on_error If TRUE, stop on first error. If FALSE, collect all errors.
#' @return List with $valid (logical) and $errors (character vector)
#' @export
validate_scenario <- function(scenario, stop_on_error = FALSE) {
  errors <- character(0)
  
  # Required top-level fields
  required_fields <- c("scenario_id", "description", "start_year", "end_year", 
                       "domain", "adoption")
  
  for (field in required_fields) {
    if (is.null(scenario[[field]])) {
      errors <- c(errors, paste0("Missing required field: ", field))
    }
  }
  
  if (length(errors) > 0 && stop_on_error) {
    PEcAn.logger::logger.severe(paste(errors, collapse = "\n"))
  }
  
  # Validate temporal scope
  if (!is.null(scenario$start_year) && !is.null(scenario$end_year)) {
    if (scenario$start_year < 2025) {
      errors <- c(errors, "start_year must be >= 2025")
    }
    if (scenario$end_year < scenario$start_year) {
      errors <- c(errors, "end_year must be >= start_year")
    }
  }
  
  # Validate domain
  valid_domains <- c("california_counties", "caladapt_climregions")
  if (!is.null(scenario$domain) && !scenario$domain %in% valid_domains) {
    errors <- c(errors, paste0(
      "Invalid domain: ", scenario$domain,
      ". Must be one of: ", paste(valid_domains, collapse = ", ")
    ))
  }
  
  # Validate each adoption entry
  if (!is.null(scenario$adoption)) {
    for (i in seq_along(scenario$adoption)) {
      entry <- scenario$adoption[[i]]
      entry_errors <- validate_adoption_entry(entry, scenario$domain, i)
      errors <- c(errors, entry_errors)
    }
    
    # Check for incompatible practice combinations
    incompatible_errors <- check_practice_compatibility(scenario$adoption)
    errors <- c(errors, incompatible_errors)
  }
  
  list(valid = length(errors) == 0, errors = errors)
}


#' Validate a single adoption entry
#'
#' @param entry Single adoption list item
#' @param domain Domain type for area validation
#' @param index Index of entry in adoption list (for error messages)
#' @return Character vector of error messages (empty if valid)
#' @keywords internal
validate_adoption_entry <- function(entry, domain, index) {
  errors <- character(0)
  prefix <- paste0("adoption[", index, "]: ")
  
  # Support 'county' as alias for 'area' when domain is california_counties
  if (is.null(entry$area) && !is.null(entry$county)) {
    if (domain == "california_counties") {
      entry$area <- entry$county
    } else {
      errors <- c(errors, paste0(
        prefix, "'county' alias only valid when domain is 'california_counties'"
      ))
    }
  }
  
  # Required fields
  if (is.null(entry$area)) {
    errors <- c(errors, paste0(prefix, "missing 'area'"))
  }
  if (is.null(entry$crop_pft)) {
    errors <- c(errors, paste0(prefix, "missing 'crop_pft'"))
  }
  if (is.null(entry$practice)) {
    errors <- c(errors, paste0(prefix, "missing 'practice'"))
  }
  if (is.null(entry$trajectory)) {
    errors <- c(errors, paste0(prefix, "missing 'trajectory'"))
  }
  
  # Validate area against domain
  if (!is.null(entry$area) && !is.null(domain)) {
    valid_areas <- if (domain == "california_counties") {
      CALIFORNIA_COUNTIES
    } else if (domain == "caladapt_climregions") {
      CALADAPT_REGIONS
    } else {
      character(0)
    }
    
    if (length(valid_areas) > 0 && !entry$area %in% valid_areas) {
      errors <- c(errors, paste0(
        prefix, "invalid area '", entry$area, "' for domain '", domain, "'"
      ))
    }
  }
  
  # Validate crop_pft
  if (!is.null(entry$crop_pft) && !entry$crop_pft %in% VALID_PFTS) {
    errors <- c(errors, paste0(prefix, "invalid crop_pft '", entry$crop_pft, "'"))
  }
  
  # Validate practice
  if (!is.null(entry$practice) && !entry$practice %in% VALID_PRACTICES) {
    errors <- c(errors, paste0(prefix, "invalid practice '", entry$practice, "'"))
  }
  
  # Validate practice eligibility for crop_pft
  if (!is.null(entry$practice) && !is.null(entry$crop_pft)) {
    if (entry$practice %in% names(PRACTICE_ELIGIBILITY)) {
      eligible <- PRACTICE_ELIGIBILITY[[entry$practice]]
      if (!entry$crop_pft %in% eligible && entry$crop_pft != "all_cropland") {
        errors <- c(errors, paste0(
          prefix, "practice '", entry$practice, 
          "' is not eligible for crop_pft '", entry$crop_pft, "'"
        ))
      }
    }
  }
  
  # Validate trajectory
  if (!is.null(entry$trajectory)) {
    traj_errors <- validate_trajectory(entry$trajectory, prefix)
    errors <- c(errors, traj_errors)
  }
  
  errors
}


#' Validate trajectory specification
#'
#' @param trajectory Trajectory list (year -> value)
#' @param prefix Error message prefix
#' @return Character vector of error messages
#' @keywords internal
validate_trajectory <- function(trajectory, prefix = "") {
  errors <- character(0)
  
  if (length(trajectory) == 0) {
    return(c(errors, paste0(prefix, "trajectory is empty")))
  }
  
  # Extract years and values
  years <- as.integer(names(trajectory))
  values <- unlist(trajectory)
  
  # Check years are valid integers
  if (any(is.na(years))) {
    errors <- c(errors, paste0(prefix, "trajectory keys must be integer years"))
  }
  
  # Check values are numeric and non-negative
  if (!all(is.numeric(values))) {
    errors <- c(errors, paste0(prefix, "trajectory values must be numeric"))
  } else if (any(values < 0)) {
    errors <- c(errors, paste0(prefix, "trajectory values must be non-negative"))
  }
  
  errors
}


#' Check for incompatible practice combinations
#'
#' @param adoption List of adoption entries
#' @return Character vector of error messages
#' @keywords internal
check_practice_compatibility <- function(adoption) {
  errors <- character(0)
  
  # Group by area and crop_pft
  groups <- list()
  for (entry in adoption) {
    area <- entry$area %||% entry$county
    key <- paste(area, entry$crop_pft, sep = "||")
    if (is.null(groups[[key]])) {
      groups[[key]] <- character(0)
    }
    groups[[key]] <- c(groups[[key]], entry$practice)
  }
  
  # Check each group for incompatible pairs
  for (key in names(groups)) {
    practices <- groups[[key]]
    for (pair in INCOMPATIBLE_PRACTICES) {
      if (all(pair %in% practices)) {
        errors <- c(errors, paste0(
          "Incompatible practices in ", gsub("\\|\\|", " / ", key), ": ",
          paste(pair, collapse = " + ")
        ))
      }
    }
  }
  
  errors
}


# --- Interpolation functions ---

#' Interpolate trajectory to annual values
#'
#' Fills gaps between specified years with linear interpolation.
#' 
#' @param trajectory Named list with year -> value mapping
#' @param start_year First year of output
#' @param end_year Last year of output
#' @return Data frame with columns: year, value
#' @export
interpolate_trajectory <- function(trajectory, start_year, end_year) {
  # Extract and sort by year
  years <- as.integer(names(trajectory))
  values <- unlist(trajectory)
  ord <- order(years)
  years <- years[ord]
  values <- values[ord]
  
  # Generate full year sequence
  all_years <- seq(start_year, end_year)
  
  # Linear interpolation
  interpolated <- approx(
    x = years,
    y = values,
    xout = all_years,
    rule = 2
  )
  
  data.frame(
    year = interpolated$x,
    value = interpolated$y
  )
}


#' Expand full scenario to annual adoption table
#'
#' @param scenario Validated scenario object
#' @return Data frame with columns: year, area, crop_pft, practice, value, unit
#' @export
expand_scenario <- function(scenario) {
  validation <- validate_scenario(scenario)
  if (!validation$valid) {
    PEcAn.logger::logger.severe(
      "Cannot expand invalid scenario. Errors:\n",
      paste("  -", validation$errors, collapse = "\n")
    )
  }
  
  expanded <- purrr::map_dfr(scenario$adoption, function(entry) {
    interp <- interpolate_trajectory(
      entry$trajectory,
      scenario$start_year,
      scenario$end_year
    )
    
    area_value <- entry$area %||% entry$county
    
    data.frame(
      area = area_value,
      crop_pft = entry$crop_pft,
      practice = entry$practice,
      year = interp$year,
      value = interp$value,
      unit = entry$unit_type %||% "acres",
      stringsAsFactors = FALSE
    )
  })
  
  expanded
}