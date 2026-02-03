---
title: "Scenario Specification Guide"
author: "Akash B V"
date: "2026-02-02"
---

# Scenario Specification for CARB Staff

This document describes how to configure management scenarios for the California
Carbon Management Model Framework (CCMMF). Scenarios define the adoption of
Healthy Soils Program (HSP) practices across California over time.


## Overview

CARB staff specify scenarios as YAML files that define:

1. What practices are adopted (compost, cover crop, no-till, etc.)
2. Where they are adopted (by county or climate region)
3. For which crops (annual row crops, orchards, etc.)
4. How adoption grows over time (trajectory from 2025-2045)

The system interpolates between specified years and converts the scenario
into model inputs for each of the approximately 600,000 agricultural fields
in California.


## Quick Start Example

```yaml
scenario_id: my_scenario
description: "Example HSP expansion scenario"
start_year: 2025
end_year: 2045
domain: california_counties

adoption:
  - county: Fresno
    crop_pft: annual_row_crop
    practice: compost
    trajectory:
      2025: 500
      2030: 2000
      2045: 10000
```

When using `domain: california_counties`, the `county:` key may be used as an
alias for `area:` for improved readability.


## Schema Reference

### Top-Level Fields

| Field          | Required | Type    | Description                                                |
|----------------|----------|---------|------------------------------------------------------------|
| scenario_id    | Yes      | string  | Unique identifier (e.g. "BAU_2025")                       |
| description    | Yes      | string  | Human-readable description                                 |
| start_year     | Yes      | integer | First year (minimum: 2025)                                 |
| end_year       | Yes      | integer | Final year (maximum: 2100)                                 |
| domain         | Yes      | string  | Geographic unit: california_counties or caladapt_climregions |
| adoption       | Yes      | array   | List of practice adoption entries                          |

### Adoption Entry Fields

| Field       | Required | Type   | Description                                                    |
|-------------|----------|--------|----------------------------------------------------------------|
| area        | Yes      | string | County or region name (alias: county)                          |
| crop_pft    | Yes      | string | Plant functional type or crop                                  |
| practice    | Yes      | string | HSP practice code                                              |
| trajectory  | Yes      | object | Year to acres mapping                                          |
| unit_type   | No       | string | Unit specification: acres (default) or fraction                |
| notes       | No       | string | Optional documentation                                         |


## Valid Practices

The following 31 practices are supported, organized by category. Each practice
has specific eligibility requirements based on land type.

### Soil Amendments

| Practice                 | NRCS Code | Eligible Land Types              | Notes                                    |
|--------------------------|-----------|----------------------------------|------------------------------------------|
| compost                  | CPS 336   | Annual, Perennial, Grazing       | Application rate 3-8 tons/ac             |
| biochar                  | --        | Annual, Perennial                | Requires TAP certification               |
| mulching                 | CPS 484   | Annual, Perennial                | Natural materials or wood chips          |
| whole_orchard_recycling  | CPS 336   | Perennial (orchards only)        | Trees must be 10 years or older          |

### Tillage Management

| Practice      | NRCS Code | Eligible Land Types   | Notes                                      |
|---------------|-----------|----------------------|---------------------------------------------|
| no_till       | CPS 329   | Annual, Perennial    | STIR value below 20; prior tillage required |
| reduced_till  | CPS 345   | Annual               | STIR value 20-60; prior tillage required    |

### Cover and Vegetation

| Practice                    | NRCS Code | Eligible Land Types | Notes                               |
|-----------------------------|-----------|---------------------|-------------------------------------|
| cover_crop                  | CPS 340   | Annual, Perennial   | Perennial limited to alleys         |
| conservation_cover          | CPS 327   | Annual              | Permanent cover; converts cropland  |
| orchard_floor_cover         | CPS 327   | Perennial           | Alleys or whole field               |
| conservation_crop_rotation  | CPS 328   | Annual              | Planned crop sequence               |

### Agroforestry

| Practice                 | NRCS Code | Eligible Land Types    | Notes                                |
|--------------------------|-----------|------------------------|--------------------------------------|
| alley_cropping           | CPS 311   | Annual                 | Trees in rows with crop alleys       |
| multistory_cropping      | CPS 379   | Annual                 | Forest farming; trees as overstory   |
| silvopasture             | CPS 381   | Grazing                | Trees and forages combined           |
| tree_shrub_establishment | CPS 612   | Annual, Grazing        | Woody plants on cropland or grassland|

### Linear and Edge-of-Field Practices

| Practice                  | NRCS Code | Eligible Land Types         | Notes                              |
|---------------------------|-----------|-----------------------------|------------------------------------|
| hedgerow                  | CPS 422   | Annual, Perennial, Grazing  | Dense woody vegetation; min 3 spp  |
| windbreak                 | CPS 380   | Annual, Perennial, Grazing  | Single row of trees or shrubs      |
| field_border              | CPS 386   | Annual                      | Herbaceous vegetation at field edge|
| filter_strip              | CPS 393   | Annual, Perennial           | Removes contaminants from runoff   |
| contour_buffer_strips     | CPS 332   | Annual                      | Hillslope erosion control          |
| grassed_waterway          | CPS 412   | Annual                      | Gully erosion control              |
| herbaceous_wind_barrier   | CPS 603   | Annual                      | Herbaceous strips within field     |
| vegetative_barrier        | CPS 601   | Annual                      | Stiff vegetation on contour        |
| strip_cropping            | CPS 585   | Annual                      | Alternating erosion-resistant crops|

### Riparian Practices

| Practice                  | NRCS Code | Eligible Land Types | Notes                                 |
|---------------------------|-----------|---------------------|---------------------------------------|
| riparian_forest_buffer    | CPS 391   | Annual, Grazing     | Trees and shrubs adjacent to water    |
| riparian_herbaceous_cover | CPS 390   | Annual              | Herbaceous cover near watercourse     |

### Grazing Land Practices

| Practice             | NRCS Code | Eligible Land Types | Notes                                  |
|----------------------|-----------|---------------------|----------------------------------------|
| prescribed_grazing   | CPS 528   | Grazing             | Requires certified range manager plan  |
| range_planting       | CPS 550   | Grazing             | Perennial vegetation on rangeland      |
| pasture_hay_planting | CPS 512   | Annual              | Converts cropland to pasture or hay    |

### Special and Regional Practices

| Practice    | NRCS Code | Eligible Land Types | Notes                                    |
|-------------|-----------|---------------------|------------------------------------------|
| delta_rice  | --        | Annual              | Delta peat soils only; converts to rice  |


## Valid Crop and PFT Codes

| Code              | Description                    |
|-------------------|--------------------------------|
| annual_row_crop   | All annual field crops         |
| perennial_woody   | Orchards and vineyards         |
| grazing_land      | Pasture and rangeland          |
| all_cropland      | Any agricultural land          |
| processing_tomato | Specific crop                  |
| almond            | Specific perennial crop        |
| walnut            | Specific perennial crop        |
| grape             | Specific perennial crop        |
| rice              | Specific annual crop           |
| corn              | Specific annual crop           |
| wheat             | Specific annual crop           |
| alfalfa           | Specific perennial forage      |


## Practice Eligibility Matrix

The following matrix summarizes which practices can be applied to each land type.
See individual practice entries above for specific constraints.

| Practice                    | Annual Cropland | Perennial | Grazing Land |
|-----------------------------|-----------------|-----------|--------------|
| compost                     | Yes             | Yes       | Yes          |
| biochar                     | Yes             | Yes       | No           |
| mulching                    | Yes             | Yes       | No           |
| whole_orchard_recycling     | No              | Yes       | No           |
| no_till                     | Yes             | Yes       | No           |
| reduced_till                | Yes             | No        | No           |
| cover_crop                  | Yes             | Yes       | No           |
| conservation_cover          | Yes             | No        | No           |
| orchard_floor_cover         | No              | Yes       | No           |
| conservation_crop_rotation  | Yes             | No        | No           |
| alley_cropping              | Yes             | No        | No           |
| multistory_cropping         | Yes             | No        | No           |
| silvopasture                | No              | No        | Yes          |
| tree_shrub_establishment    | Yes             | No        | Yes          |
| hedgerow                    | Yes             | Yes       | Yes          |
| windbreak                   | Yes             | Yes       | Yes          |
| field_border                | Yes             | No        | No           |
| filter_strip                | Yes             | Yes       | No           |
| contour_buffer_strips       | Yes             | No        | No           |
| grassed_waterway            | Yes             | No        | No           |
| herbaceous_wind_barrier     | Yes             | No        | No           |
| vegetative_barrier          | Yes             | No        | No           |
| strip_cropping              | Yes             | No        | No           |
| riparian_forest_buffer      | Yes             | No        | Yes          |
| riparian_herbaceous_cover   | Yes             | No        | No           |
| prescribed_grazing          | No              | No        | Yes          |
| range_planting              | No              | No        | Yes          |
| pasture_hay_planting        | Yes             | No        | No           |
| delta_rice                  | Yes             | No        | No           |


## Incompatible Practice Combinations

The following practice pairs cannot be combined on the same field:

| Practice A          | Practice B            | Reason                         |
|---------------------|-----------------------|--------------------------------|
| no_till             | reduced_till          | Mutually exclusive tillage     |
| conservation_cover  | cover_crop            | Both establish vegetation      |
| conservation_cover  | pasture_hay_planting  | Both convert cropland          |


## Trajectory Specification

### Units

Trajectories can be specified in two units:

1. **Acres** (default): Absolute area of practice implementation. Values
   typically range from hundreds to tens of thousands.
   
2. **Fraction**: Proportion of eligible land (0.0 to 1.0). Use `unit_type:
   fraction` to specify this mode.

### Interpolation

The system automatically interpolates between specified years using linear
interpolation:

```yaml
trajectory:
  2025: 1000
  2035: 5000
  2045: 10000
```

This results in linear growth from 1000 acres in 2025 to 10000 acres in 2045.

### Constraints

- Trajectories should be monotonically non-decreasing
- Values must be non-negative
- Years must be integers within the start_year to end_year range


## Validation

Run validation before submission:

```r
source("R/validate_scenario.R")
scenario <- load_scenario("my_scenario.yaml")
result <- validate_scenario(scenario)

if (result$valid) {
  message("Scenario is valid")
} else {
  message("Errors found:")
  print(result$errors)
}
```


## RFP Alignment

This schema supports the RFP requirements for future projection modeling:

> "CARB staff, for both the BAU and alternative management scenario, shall
> be able to define the amount of healthy soils practices occur on an annual
> basis on, at least, the county scale within the model."

The system enables:

- 8 future projections: 2 GCMs x 2 emissions scenarios x 2 management scenarios
- County-scale adoption: Defined per-county, per-practice
- Annual trajectories: Interpolated to each year through 2045
- Multiple scenarios: BAU plus alternative scenarios supported


## Files

| File                             | Purpose                    |
|----------------------------------|----------------------------|
| data/scenario_schema.yaml        | Schema definition          |
| R/validate_scenario.R            | Validation functions       |
| R/scenario_to_boolean.R          | Boolean table generation   |
| R/scenario_to_events.R           | events.json generation     |
| examples/scenario_bau.yaml       | BAU example                |
| examples/scenario_hsp_high.yaml  | High adoption example      |


## References

1. CDFA Healthy Soils Program 2026 Practice Guidelines
2. USDA NRCS Conservation Practice Standards
3. CARB Contract RFP - Task 4: Future Projection Modeling