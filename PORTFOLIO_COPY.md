# Portfolio Copy

## Canonical project description

Reuse the description maintained in the [README project summary](README.md#project-summary):

Orbital Weirdness Atlas is an R/Arrow project analyzing approximately 1.55 million NASA/JPL bound asteroid orbits with an interpretable geometric score and class-relative rankings. It combines resumable API ingestion, Parquet storage, locked dependencies, and automated checks with a meaningful negative result: a proposed companion metric supplied almost no independent rank information in the analyzed catalog.

## Status and evidence

> Environment restoration and pipeline execution were validated in a clean clone. Exact reproduction of the July 2026 results still requires the original July inputs, archived with checksums and provenance tied to the matching code and configuration. The score describes orbital geometry; predictive utility for dynamical instability remains untested.

The approximately 1.55 million orbits refer to the July analysis. The quoted July correlation is from the subset retaining `condition_code <= 5` or missing codes; these descriptive checks do not establish superiority over baselines. The separate September validation processed 1,565,665 rows with no missing or duplicate SPK IDs. Those ID checks do not establish that every retrieved page represents one frozen catalog state. See the [case study](CASE_STUDY.md) for scientific evidence and the [setup report](SETUP_AND_REPRODUCIBILITY_REPORT.md) for dated execution evidence.

## Resume bullets

- Built an R/Arrow pipeline to ingest and analyze approximately 1.55 million NASA/JPL bound asteroid records, with resumable pagination, schema normalization, and compression fallback.
- Established reproducible execution with `renv`, a single pipeline entry point, and automated smoke tests in GitHub Actions; documented clean-clone restoration and full pipeline validation.
- Developed an interpretable eccentricity–inclination score with global and class-relative rankings; evaluated population enrichment, component contributions, propagated uncertainties, and quality-screen sensitivity.
- Found near-redundancy between two proposed metrics (Spearman ρ ≈ −0.99998 in the July screened subset) and revised the scientific interpretation to reflect their overlapping rank information.

## Thirty-second interview explanation

I built an R/Arrow pipeline to analyze roughly 1.55 million JPL bound asteroid orbits using an interpretable geometric score and within-class rankings. I addressed schema and compression failures and documented clean-clone execution. A proposed companion metric proved nearly rank-redundant, so I revised the interpretation. Exact July reproduction still needs the original inputs; the next scientific step is benchmarking against simpler scores before testing dynamical predictions.

## Interview talking points

- **Engineering:** Mixed identifier types and unavailable compression codecs broke ingestion. Schema handling and codec selection addressed those failures; locked dependencies, an explicit entry point, smoke tests, and GitHub Actions support repeatable execution.
- **Scientific judgment:** Within-class rankings surfaced unusual geometry inside ordinary populations. The companion metric was nearly rank-redundant, which narrowed its claimed contribution. For a concrete result, mean inclination shares in the within-class top 1% were 98.4% for Jupiter Trojans and 96.9% for inner-main-belt objects.
- **Limits and next step:** Archive the appropriate inputs with matching code/configuration and benchmark against simpler, class-aware scores. Full-covariance uncertainty analysis and fixed-k stability comparisons would strengthen interpretation before N-body integrations of leaders and matched controls.

## Skills keywords

R · tidyverse · ggplot2 · Arrow · Parquet · REST APIs · renv · automated testing · GitHub Actions · scientific computing · orbital mechanics · anomaly scoring · statistics · uncertainty propagation · data visualization · reproducible execution

## Suggested repository tagline

**Interpretable anomaly scoring across approximately 1.55 million NASA/JPL bound asteroid orbits in R.**

## Suggested LinkedIn/project-post opening

What does it mean for an orbit to be “weird”? I built an R/Arrow pipeline to explore roughly 1.55 million NASA/JPL bound asteroid orbits with a transparent geometric score. Class-relative rankings surfaced unusual geometries, and a nearly redundant companion metric prompted me to revise the interpretation. The project now includes locked dependencies and automated checks; baseline benchmarking is the next scientific step.

