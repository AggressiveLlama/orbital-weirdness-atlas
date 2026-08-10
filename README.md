# Orbital Weirdness Atlas

**An interpretable anomaly-detection analysis of approximately 1.55 million JPL small-body orbits in R.**

> Stephen Gray 
> Synapse8087@proton.me
> https://github.com/AggressiveLlama/orbital-weirdness-atlas

## Project summary

This project asks whether departure from a circular, coplanar, prograde orbit can be summarized with a useful geometric index:

```text
W_visible = sqrt(e^2 + (2 sin(i/2))^2)
```

I built a resilient pipeline to download a frozen snapshot from the JPL Small-Body Database Query API, normalize its schema, store it in Parquet, calculate orbital metrics, quality-screen the results, and perform global and class-relative anomaly analysis.

## Selected findings

- Centaurs were **52.4× enriched** and Apollos **48.4× enriched** among the global top 1% of `W_visible`.
- Inner-main-belt objects were only **0.066× represented**, consistent with a tightly constrained population.
- Among the weirdest 1% inside each class, inclination supplied **98.4%** of `W_visible²` for Jupiter Trojans and **96.9%** for inner-main-belt objects.
- `W_visible` and `H_KL` were almost perfectly rank-correlated (Spearman ρ = **-0.999977**), revealing that they are complementary interpretations rather than independent anomaly dimensions.
- Class-relative ranking found individual outliers with distinct geometries: high-inclination, low-eccentricity main-belt objects and high-eccentricity retrograde Centaurs/TNOs.

## View the case study

Open [`index.html`](index.html) in a browser. It is a static, portable portfolio page.

## Skills demonstrated

- R, tidyverse, ggplot2, Arrow/Parquet
- API pagination and snapshotting
- large-dataset schema and compression troubleshooting
- statistics and class-conditional anomaly scoring
- uncertainty propagation and quality sensitivity
- scientific visualization and interpretation

## Repository structure

```text
index.html                 visual portfolio page
CASE_STUDY.md              editable scientific narrative
PORTFOLIO_COPY.md          resume and interview-ready wording
assets/                    selected figures
data/                      derived tables used in the analysis
src/                       add the R pipeline scripts here
```


## Scope and limitations

`W_visible` is currently supported as an interpretable **descriptive index of orbital geometry**. The analysis does not yet demonstrate that it predicts long-term dynamical instability. The strongest follow-up is to benchmark against simpler anomaly measures and run N-body integrations on class-relative leaders and matched controls.

## Data source

NASA/JPL Small-Body Database Query API: <https://ssd-api.jpl.nasa.gov/doc/sbdb_query.html>
