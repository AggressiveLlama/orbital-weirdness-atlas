# Orbital Weirdness Atlas

**An interpretable anomaly-detection analysis of approximately 1.55 million JPL small-body orbits in R.**

Stephen Gray<br>
[Synapse8087@proton.me](mailto:Synapse8087@proton.me)<br>
[github.com/AggressiveLlama/orbital-weirdness-atlas](https://github.com/AggressiveLlama/orbital-weirdness-atlas)

## Project summary

This project asks whether departure from a circular, coplanar, prograde orbit can be summarized with a useful geometric index:

```text
W_visible = sqrt(e^2 + (2 sin(i/2))^2)
```

The pipeline downloads a timestamped snapshot from the NASA/JPL Small-Body Database Query API, normalizes its schema, stores it in Parquet, calculates orbital metrics, quality-screens the results, and performs both global and class-relative anomaly analysis.

## Selected findings

- Centaurs were **52.4× enriched** and Apollos **48.4× enriched** among the global top 1% of `W_visible`.
- Inner-main-belt objects were only **0.066× represented**, consistent with a tightly constrained population.
- Among the weirdest 1% inside each class, inclination supplied **98.4%** of `W_visible²` for Jupiter Trojans and **96.9%** for inner-main-belt objects.
- `W_visible` and `H_KL` were almost perfectly rank-correlated (Spearman rho = **-0.999977**), showing that they are complementary interpretations rather than independent anomaly dimensions.
- Class-relative ranking found individual outliers with distinct geometries: high-inclination, low-eccentricity main-belt objects and high-eccentricity retrograde Centaurs/TNOs.

## View the case study

Open [`index.html`](index.html) in a browser. It is a static, portable portfolio page backed by the committed plots in [`results/figures`](results/figures).

## Reproduce the analysis

For a detailed account of the repository repair, validation evidence, and a reusable setup recipe, see [`SETUP_AND_REPRODUCIBILITY_REPORT.md`](SETUP_AND_REPRODUCIBILITY_REPORT.md).

### Requirements

- R 4.3.3 or a compatible newer R release;
- a C/C++ build toolchain if a prebuilt Arrow package is unavailable;
- enough local storage for the full JPL snapshot and processed Parquet file.

### 1. Restore the locked environment

From the repository root:

```bash
Rscript 00_install_packages.R
```

This uses `renv.lock`; it does not silently upgrade packages to whatever happens to be current.

### 2. Run the fast, network-free checks

```bash
Rscript tests/smoke_test.R
```

The smoke test parses every R script, checks known values of `W_visible` and `H_KL`, protects mixed-format SBDB identifiers, and performs a Parquet round trip using an available compression codec.

### 3. Run the complete pipeline

```bash
Rscript run_all.R
```

The full run downloads the current bound-asteroid population. Because the JPL catalog changes continuously, a new snapshot will not be byte-for-byte identical to the July 2026 results committed here.

To rerun only the analysis stages against the most recent local snapshot:

```bash
Rscript run_all.R --skip-download
```

To resume an interrupted download, reuse its snapshot identifier:

```bash
SBDB_SNAPSHOT_ID=20260919T120000Z Rscript 01_download_sbdb.R
```

Completed Parquet pages are written atomically and skipped on the resumed run.

## Repository structure

```text
index.html                         static visual case study
CASE_STUDY.md                      scientific narrative
PORTFOLIO_COPY.md                  resume and interview wording
config.R                           API and analysis settings
R/functions.R                     shared pipeline and metric functions
00_install_packages.R             locked-environment restoration
01_download_sbdb.R                paginated, resumable SBDB snapshot
02_compute_metrics.R              metrics and global leaderboards
03_visualize_and_diagnose.R       global plots and diagnostics
04_class_specific_analysis.R      within-class anomaly analysis
run_all.R                          complete pipeline entry point
renv.lock                          exact R dependency versions
data/                              local raw/processed data (not committed)
results/figures/                   committed analysis figures
results/tables/                    committed compact result tables
tests/smoke_test.R                 deterministic network-free checks
.github/workflows/                 clean-room CI validation
```

## Skills demonstrated

- R, tidyverse, ggplot2, Arrow/Parquet;
- API pagination, retry/backoff, snapshotting, and resume behavior;
- large-dataset schema and compression troubleshooting;
- statistics and class-conditional anomaly scoring;
- uncertainty propagation and quality sensitivity;
- scientific visualization and interpretation;
- reproducible environments and automated checks.

## Scope and limitations

`W_visible` is currently supported as an interpretable **descriptive index of orbital geometry**. The analysis does not yet demonstrate that it predicts long-term dynamical instability. The strongest follow-up is to benchmark it against simpler anomaly measures and run N-body integrations on class-relative leaders and matched controls.

## Data source

NASA/JPL Small-Body Database Query API: <https://ssd-api.jpl.nasa.gov/doc/sbdb_query.html>
