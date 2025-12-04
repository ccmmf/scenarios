# Agronomic Management Scenarios

This directory contains a generic set of management events representing
different agronomic scenarios for herbaceous annual systems over the 
years 2016–2024.

These JSON files are compliant with the PEcAn events schema and are 
intended to be used by `PEcAn.SIPNET::write.configs.SIPNET` to generate SIPNET 
`events.in` files.

For initial MVP, these files are intended to be reused across all
sites to represent management scenarios for herbaceous systems. Later 
iterations of the pipeline will produce site-specific management events 
for both inventories and projections.

## Scenarios

The agronomic management events described below broadly reflect common practices in 
CA for annual row crops, based on UC ANR and CDFA-FREP guidance.

### Overview

| Scenario           | Changes from baseline                                                            |
| ------------------ | -------------------------------------------------------------------------------- |
| baseline           | Following conventional practices                                                 |
| compost            | Adds compost (0.25 kg C/m2, 0.015 kg N/m2); remove mineral N fertilizer          |
| reduced_till       | Reduce tillage intensity to 0.10.                                                |
| zero_till          | No tillage with tillage_eff_0to1 = 0.00.                                         |
| reduced_irrig_drip | Replace canopy irrigation schedule with 40 drip events (8 mm each, soil method). |
| stacked            | Combine compost, reduced_till, and reduced_irrig treatments.                     |

### Scenario Details

- baseline
  - Compost: none
  - Tillage: conventional, tillage_eff_0to1 = 0.35
  - Mineral N: 0.020 kg N/m2 per year (200 kg N/ha), pre-plant
  - Irrigation: 6 sprinkler/overhead events (method = "canopy"),
    90 mm each, May–September (seasonal total = 540 mm)

- compost
  - Compost: 0.25 kg C/m2 and 0.015 kg N/m2 each year (late February): ~10 tons/acre compost at ~35% C and C:N = 16
  - Mineral N: 0 (orgN replaces mineral N)

- reduced_till
  - Tillage: reduced intensity, tillage_eff_0to1 = 0.10

- zero_till
  - Tillage: no tillage, tillage_eff_0to1 = 0.00

- reduced_irrig_drip
  - Irrigation: drip: 40 applications of 8 mm
    (~3x/week from May through late August, seasonal total ~320 mm)

- stacked
  - Compost: 0.25 kg C/m2 and 0.015 kg N/m2 per year
  - Tillage: reduced intensity, tillage_eff_0to1 = 0.10
  - Irrigation: as reduced_irrig_drip (40 x 8 mm, soil)

### Timing of Events

Annually (2016–2024):

- Compost: Feb 20
- Tillage: Mar 20
- Mineral N: Mar 25
- Planting: Apr 10
- Irrigation:
  - baseline / compost / reduced_till / zero_till:
    - May 15, Jun 15, Jul 15, Aug 15, Sep 1, Sep 15
    - 90 mm each, method = "canopy"
  - reduced_irrig_drip / stacked:
    - 40 events, 8 mm every 3 days starting May 1
- Harvest: Oct 10

All events use site_id = "herb_site_1" and are sorted by date.

## Files

- data/events_baseline.json
- data/events_compost.json
- data/events_reduced_till.json
- data/events_zero_till.json
- data/events_reduced_irrig_drip.json
- data/events_stacked.json

## References

**OM Application**
- [CDFA Compost Application Rate White Paper](https://www.cdfa.ca.gov/oefi/healthysoils/docs/CompostApplicationRate_WhitePaper.pdf)

**Fertilization**
- [USDA Nutrient Management in Organic Systems Western States Implementation Guide](https://www.nrcs.usda.gov/sites/default/files/2024-07/Nutrient-Management-in-Organic-Systems-Western-States-Implementation-Guide.pdf)
- [UCANR Fertilization Guidelines](https://ucanr.edu/sites/default/files/2019-03/301161.pdf)

**Irrigation**
- [UCANR Irrigation of Processing Tomatoes](https://ipm.ucanr.edu/agriculture/tomato/irrigation-of-processing-tomatoes/)
- [Inouye "Crop Water Requirements Imperial Valley"](https://pecanproject.slack.com/archives/C06M2FKU69W/p1764715950101759?thread_ts=1764637090.986109&cid=C06M2FKU69W)