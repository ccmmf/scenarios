#!/usr/bin/env Rscript
#
# Convert scenario adoption to boolean site x practice table
#
# Assigns practices to individual fields based on county-level adoption targets.
# Returns a boolean matrix where each row is a field and each column is a practice.
#

`%||%` <- rlang::`%||%`


#' Convert scenario to boolean table of site x practice
#'
#' Takes a validated scenario with adoption trajectories and assigns practices
#' to individual fields based on county-level targets.
#'
#' @param scenario Validated scenario object from load_scenario()
#' @param fields_sf sf object or data.frame with fields, must have 'field_id' 
#'   and 'county' columns
#' @param year Integer year to evaluate (practices assigned as of this year)
#' @param seed Random seed for reproducible assignment (default NULL = random)
#'
#' @return Data frame with columns:
#'   - field_id: Field identifier
#'   - county: County name
#'   - crop_pft: Plant functional type
#'   - One boolean column per practice in the scenario
#'
#' @details
#' For each (county, crop_pft, practice) combination in the scenario:
#' 1. Find eligible fields in that county with matching PFT
#' 2. Calculate how many fields should have this practice (from trajectory)
#' 3. Randomly assign practice to that many fields
#'
#' Field areas are used to weight selection when 'area_ha' column exists.
#'
#' @examples
#' \dontrun{
#' scenario <- load_scenario("examples/scenario_bau.yaml")
#' fields <- data.frame(
#'   field_id = paste0("f_", 1:1000),
#'   county = sample(c("Fresno", "Kern", "Tulare"), 1000, replace = TRUE),
#'   crop_pft = sample(c("annual_row_crop", "perennial_woody"), 1000, replace = TRUE),
#'   area_ha = runif(1000, 5, 50)
#' )
#' bool_table <- scenario_to_boolean_table(scenario, fields, year = 2030, seed = 42)
#' }
#'
#' @export
scenario_to_boolean_table <- function(scenario, fields_sf, year, seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  # Validate scenario
  validation <- validate_scenario(scenario)
  if (!validation$valid) {
    PEcAn.logger::logger.severe(
      "Cannot convert invalid scenario to boolean table:\n",
      paste(validation$errors, collapse = "\n")
    )
  }
  
  # Convert sf to data.frame if needed
  if (inherits(fields_sf, "sf")) {
    fields_df <- sf::st_drop_geometry(fields_sf)
  } else {
    fields_df <- as.data.frame(fields_sf)
  }
  
  # Check required columns
  required_cols <- c("field_id", "county")
  missing_cols <- setdiff(required_cols, names(fields_df))
  if (length(missing_cols) > 0) {
    PEcAn.logger::logger.severe(
      "fields_sf missing required columns: ", 
      paste(missing_cols, collapse = ", ")
    )
  }
  
  # Default crop_pft if missing
  if (!"crop_pft" %in% names(fields_df)) {
    fields_df$crop_pft <- "all_cropland"
  }
  
  # Get practices in scenario
  all_practices <- unique(sapply(scenario$adoption, function(e) e$practice))
  
  # Initialize result
  result <- data.frame(
    field_id = fields_df$field_id,
    county = fields_df$county,
    crop_pft = fields_df$crop_pft,
    stringsAsFactors = FALSE
  )
  
  for (practice in all_practices) {
    result[[practice]] <- FALSE
  }
  
  # Process each adoption entry
  for (entry in scenario$adoption) {
    target_county <- entry$area %||% entry$county
    target_pft <- entry$crop_pft
    practice <- entry$practice
    
    # Interpolate trajectory
    annual_values <- interpolate_trajectory(
      entry$trajectory,
      scenario$start_year,
      scenario$end_year
    )
    
    year_idx <- which(annual_values$year == year)
    if (length(year_idx) == 0) next
    
    target_value <- annual_values$value[year_idx]
    if (is.na(target_value) || target_value <= 0) next
    
    # Find eligible fields
    eligible_mask <- (result$county == target_county)
    if (target_pft != "all_cropland") {
      eligible_mask <- eligible_mask & (result$crop_pft == target_pft)
    }
    
    eligible_idx <- which(eligible_mask)
    n_eligible <- length(eligible_idx)
    if (n_eligible == 0) next
    
    # Determine assignment count
    unit_type <- entry$unit_type %||% "acres"
    
    if (unit_type == "fraction") {
      n_assign <- round(n_eligible * target_value)
    } else {
      if ("area_ha" %in% names(fields_df)) {
        eligible_areas_ha <- fields_df$area_ha[eligible_idx]
        eligible_areas_ac <- eligible_areas_ha * 2.471
        
        perm <- sample(seq_along(eligible_idx))
        cumsum_area <- cumsum(eligible_areas_ac[perm])
        
        n_assign <- sum(cumsum_area <= target_value)
        if (n_assign == 0 && target_value > 0) {
          n_assign <- 1
        }
      } else {
        # Assume average field size of 40 acres (CA average from USDA NASS)
        avg_field_acres <- 40
        n_assign <- round(target_value / avg_field_acres)
      }
    }
    
    n_assign <- min(n_assign, n_eligible)
    
    if (n_assign > 0) {
      if (unit_type != "fraction" && "area_ha" %in% names(fields_df)) {
        selected_idx <- eligible_idx[perm[1:n_assign]]
      } else {
        selected_idx <- sample(eligible_idx, n_assign)
      }
      result[[practice]][selected_idx] <- TRUE
    }
  }
  
  result
}


#' Convert boolean table to long format
#'
#' @param bool_table Boolean table from scenario_to_boolean_table()
#' @param include_false Whether to include FALSE assignments (default FALSE)
#'
#' @return Data frame with columns: field_id, county, crop_pft, practice, assigned
#' @export
boolean_table_to_long <- function(bool_table, include_false = FALSE) {
  
  standard_cols <- c("field_id", "county", "crop_pft")
  practice_cols <- setdiff(names(bool_table), standard_cols)
  practice_cols <- practice_cols[sapply(bool_table[practice_cols], is.logical)]
  
  if (length(practice_cols) == 0) {
    return(data.frame(
      field_id = character(0),
      county = character(0),
      crop_pft = character(0),
      practice = character(0),
      assigned = logical(0)
    ))
  }
  
  long_df <- tidyr::pivot_longer(
    bool_table,
    cols = tidyselect::all_of(practice_cols),
    names_to = "practice",
    values_to = "assigned"
  )
  
  if (!include_false) {
    long_df <- long_df[long_df$assigned, ]
  }
  
  as.data.frame(long_df)
}


#' Get summary statistics from boolean table
#'
#' @param bool_table Boolean table from scenario_to_boolean_table()
#' @return Data frame with practice adoption counts by county
#' @export
summarize_boolean_table <- function(bool_table) {
  standard_cols <- c("field_id", "county", "crop_pft")
  practice_cols <- setdiff(names(bool_table), standard_cols)
  practice_cols <- practice_cols[sapply(bool_table[practice_cols], is.logical)]
  
  summary_df <- bool_table |>
    dplyr::group_by(county) |>
    dplyr::summarise(
      n_fields = dplyr::n(),
      dplyr::across(
        tidyselect::all_of(practice_cols),
        ~ sum(.x, na.rm = TRUE),
        .names = "{.col}_count"
      ),
      .groups = "drop"
    )
  
  as.data.frame(summary_df)
}
