# Management Practice Priors for California Agriculture

This document specifies prior distributions for agricultural management parameters
used in the management scenario system. All priors are derived from peer-reviewed
literature, NRCS Conservation Practice Standards, CDFA program guidelines, and UC ANR
extension publications.

## Sources

All priors derive from official sources:

- **NRCS CPS 329** - Residue and Tillage Management, No Till (Sept 2016)
- **NRCS CPS 340** - Cover Crop (May 2024)
- **NRCS CPS 345** - Residue and Tillage Management, Reduced Till
- **NRCS CPS 449** - Irrigation Water Management (Oct 2024)
- **NRCS CPS 808** - Soil Carbon Amendment (Sept 2020)
- **CDFA Gravuer 2016** - Compost Application Rates for CA Croplands, EFA SAP White Paper
- **UC ANR Pub 3470** - Fertilizer guidelines
- **UC ANR Pub 3396** - Irrigation scheduling (Hanson et al. 2006)
- **USDA NASS 2022** - Census of Agriculture, California

## Tillage Intensity

### STIR Scale Background

NRCS uses the Soil Tillage Intensity Rating (STIR) on a **0-200 scale**:

> "The crop interval STIR value shall be no greater than 20" — NRCS CPS 329

| Practice     | STIR Range | Source           |
|--------------|------------|------------------|
| No-till      | <= 20      | CPS 329 criteria |
| Reduced till | 20-60      | CPS 345 criteria |
| Conventional | > 80       | General practice |

### Our Model Parameter

Our parameter `tillage_eff_0to1` represents SOM pool transfer fraction, not direct STIR. The conversion is approximately `tillage_eff ≈ STIR / 200`.

| System       | tillage_eff | Equivalent STIR | Justification                      |
|--------------|-------------|-----------------|------------------------------------|
| No-till      | 0.0         | 0-20            | CPS 329: no full-width disturbance |
| Reduced      | 0.10        | ~20             | CPS 345 lower threshold            |
| Conventional | 0.35        | ~70             | Mid-range conventional             |

### Why Beta Distribution?

We use Beta distributions because:
1. Parameter is bounded [0, 1]
2. Can be skewed to reflect clustering around typical practice
3. Beta(a, b) has mean = a/(a+b), easy to interpret

**Conventional tillage:** Beta(7, 13)
- Mean = 7/20 = 0.35
- 95% CI: [0.19, 0.53]
- Justification: Most conventional tillage falls in STIR 60-100 range

**Reduced tillage:** Beta(2, 18)
- Mean = 2/20 = 0.10
- 95% CI: [0.02, 0.24]
- Justification: CPS 345 specifies STIR 20-60; we use lower end conservatively

## Compost Application

### CDFA Official Rates

Source: Gravuer 2016, Table 2 (CDFA EFA SAP Subcommittee consensus)

| Crop Type | Compost Type         | Moist tons/ac | Dry tons/ac |
|-----------|----------------------|---------------|-------------|
| Annual    | Higher N (C:N <= 11) | 3-5           | 2.2-3.6     |
| Annual    | Lower N (C:N > 11)   | 6-8           | 4.0-5.3     |
| Tree      | Higher N (C:N <= 11) | 2-4           | 1.5-2.9     |
| Tree      | Lower N (C:N > 11)   | 6-8           | 4.0-5.3     |

### Unit Conversion

For **annual crops with lower N compost** (most common HSP scenario):

```
Midpoint: 4.7 dry tons/acre

Step 1: tons/ac to kg/m2
  4.7 tons/ac x 907.2 kg/ton = 4264 kg/ac
  4264 kg/ac / 4047 m2/ac = 1.05 kg dry compost/m2

Step 2: Apply carbon fraction
  Finished compost: 25-40% C (dry basis), typical 30-35%
  1.05 kg/m2 x 0.35 = 0.37 kg C/m2

Range: 4.0-5.3 dry tons/ac -> 0.31-0.41 kg C/m2
```

### Prior Distribution

**LogNormal** chosen because:
1. Rates are strictly positive
2. Right-skewed (some growers apply more)
3. Multiplicative uncertainty (+/-30%)

Parameters: `meanlog = -0.92, sdlog = 0.35`
- Median = exp(-0.92) = **0.40 kg C/m2**
- 95% CI: [0.22, 0.70] kg C/m2
- Encompasses both higher and lower N compost categories

### C:N Ratio

From Gravuer 2016:
> "The subcommittee agreed...dividing composts into two major categories: those with higher nitrogen (C:N <= 11) and those with lower nitrogen (C:N > 11)"

CalRecycle lab data (n=1364 samples) shows typical finished compost C:N = 14-20.

**Prior:** Normal(16, 3) -> 95% CI [10, 22]

## Nitrogen Fertilizer

### Annual Row Crops

Source: UC Davis Cost Studies (2023), Processing Tomatoes

| Item    | Value         | Source                |
|---------|---------------|-----------------------|
| Total N | 180-220 kg/ha | UC Davis cost study   |
| Timing  | March-April   | Pre-plant + sidedress |

**Prior:** TruncNorm(mean=180, sd=30, lower=100, upper=300) kg N/ha

Conversion: 180 kg N/ha = 0.018 kg N/m2

### Perennial Woody (Almonds)

Source: Almond Board of California, UC ANR Pub 3364

| Item    | Value                           | Source               |
|---------|---------------------------------|----------------------|
| Total N | 200-280 kg/ha                   | Split 3 applications |
| Timing  | Feb (20%), Apr (40%), Jun (40%) | Industry practice    |

**Prior:** TruncNorm(mean=240, sd=40) kg N/ha

## Irrigation

### Efficiency by Method

From NRCS CPS 449 references and Hanson et al. 2006:

| Method       | Application Efficiency |
|--------------|------------------------|
| Flood/furrow | 50-70%                 |
| Sprinkler    | 60-75%                 |
| Drip/micro   | 85-95%                 |

### Seasonal Totals

Source: Hanson et al. 2006 (UC ANR Pub 3396), processing tomato in SJV

| Method    | Seasonal mm | Events | Per-event |
|-----------|-------------|--------|-----------|
| Sprinkler | 500-600     | 5-7    | 80-100 mm |
| Drip      | 300-400     | 40+    | 6-10 mm   |

**Sprinkler prior:** Normal(550, 80) mm seasonal
**Drip prior:** Normal(350, 60) mm seasonal

Drip saves ~35% water due to higher efficiency and reduced evaporation.

## Cover Crops

### Timing

NRCS CPS 340 (May 2024) states:
> "Plant species selection, seedbed preparation, seeding rates, seeding dates...will be consistent with applicable local criteria and soil/site conditions"

For California Central Valley:
- **Planting:** After summer harvest (Sept-Oct), before winter rains (Oct-Nov)
- **Termination:** 2-4 weeks before cash crop planting (Mar-Apr)

| Parameter   | q25    | Median | q75    | Rationale                            |
|-------------|--------|--------|--------|--------------------------------------|
| Planting    | Oct 10 | Nov 1  | Nov 15 | Regional variation in harvest timing |
| Termination | Mar 1  | Mar 20 | Apr 10 | Depends on cash crop planting date   |

### Biomass

Source: Brennan & Boyd 2012 (UC organic vegetable trials)

Typical biomass at termination: 2000-5000 kg DM/ha

**Prior:** LogNormal(meanlog=8.0, sdlog=0.5)
- Median = exp(8) ~ 3000 kg/ha
- 95% CI: [1200, 7500] kg/ha

### N Fixation

NRCS CPS 340 specifies:
> "Legumes...are used to improve fertility by providing the subsequent crop with a minimum of 20% but not more than 100% of the crop's estimated nitrogen requirement"

For tomato (180 kg N/ha demand): 20-100% = 36-180 kg N/ha

**Prior:** TruncNorm(mean=80, sd=30, lower=20, upper=150) kg N/ha

## Regional Adoption Rates

Source: USDA NASS Census of Agriculture 2022, California tables

### San Joaquin Valley - Annual Row Crops

| Practice          | Adoption | Beta Prior  | 95% CI       |
|-------------------|----------|-------------|--------------|
| Conventional till | ~65%     | Beta(13, 7) | [0.45, 0.82] |
| Reduced till      | ~25%     | Beta(5, 15) | [0.10, 0.42] |
| No-till           | ~10%     | Beta(2, 18) | [0.02, 0.24] |
| Cover crop        | ~15%     | Beta(3, 17) | [0.04, 0.31] |
| Drip irrigation   | ~40%     | Beta(8, 12) | [0.22, 0.59] |
| Compost           | ~5%      | Beta(1, 19) | [0.00, 0.16] |

Adoption rates are uncertain, hence wide Beta priors. The CDFA HSP enrollment data suggests conservation practice adoption is increasing but still relatively low.

## Files

- `data/management_priors.yaml` - Machine-readable priors
- `R/sample_priors.R` - Sampling functions
- `scenarios.yaml` - Scenario configurations

## References

1. Brennan EB, Boyd NS. 2012. Winter cover crop seeding rate and variety affects during eight years of organic vegetables. Agronomy Journal 104:684-698.

2. Gravuer K. 2016. Compost Application Rates for California Croplands and Rangelands for a CDFA Healthy Soils Incentives Program. White Paper for CDFA Environmental Farming Act Science Advisory Panel.

3. Hanson BR, Schwankl LJ, Fulton A. 2006. Scheduling Irrigations: When and How Much Water to Apply. UC ANR Publication 3396.

4. UC Davis. 2023. Sample Costs to Produce Processing Tomatoes, San Joaquin Valley. UC Agricultural Issues Center.

5. USDA NASS. 2022. Census of Agriculture - California State and County Data.

6. USDA NRCS. 2016. Conservation Practice Standard 329 - Residue and Tillage Management, No Till.

7. USDA NRCS. 2024. Conservation Practice Standard 340 - Cover Crop.

8. USDA NRCS. 2024. Conservation Practice Standard 449 - Irrigation Water Management.
