# Orbital Weirdness Atlas

**Interpretable anomaly scoring across approximately 1.55 million NASA/JPL bound asteroid orbits in R.**

Stephen Gray<br>
[Synapse8087@proton.me](mailto:Synapse8087@proton.me)<br>
[github.com/AggressiveLlama/orbital-weirdness-atlas](https://github.com/AggressiveLlama/orbital-weirdness-atlas)

## Project summary

Orbital Weirdness Atlas is an R/Arrow project analyzing approximately 1.55 million NASA/JPL bound asteroid orbits with an interpretable geometric score and class-relative rankings. It combines resumable API ingestion, Parquet storage, locked dependencies, and automated checks with a meaningful negative result: a proposed companion metric supplied almost no independent rank information in the analyzed catalog.

This project asks whether departure from a circular, coplanar, prograde orbit can be summarized with a useful geometric index:

```text
W_visible = sqrt(e^2 + (2 sin(i/2))^2)
```

The pipeline downloads timestamped local data from the NASA/JPL Small-Body Database Query API, normalizes its schema, stores it in Parquet, calculates orbital metrics, quality-screens the results, and performs both global and class-relative anomaly analysis. The query selects asteroids with `0 <= e < 1` and a defined inclination; see [`config.R`](config.R). A timestamp and manifest document retrieval, but do not guarantee that every API page represents one frozen catalog state.

## Selected findings (July 2026)

The July analysis contains 1,553,106 valid orbits. The findings below use the 1,381,626-object subset retaining `condition_code <= 5` or missing codes; within-class summaries require at least 100 screened objects. These are historical results, distinct from the September pipeline validation.

- Centaurs were **52.4× enriched** and Apollos **48.4× enriched** among the global top 1% of `W_visible`.
- Inner-main-belt objects were only **0.066× represented** relative to their share of the screened catalog.
- Among the highest-scoring 1% inside each class, the mean inclination share of `W_visible²` was **98.4%** for Jupiter Trojans and **96.9%** for inner-main-belt objects.
- `W_visible` and signed `H_KL` were almost perfectly inversely rank-correlated (Spearman rho ≈ **-0.999977**) in the July screened subset, indicating nearly redundant rankings in that sample.
- Class-relative ranking found individual outliers with distinct geometries: high-inclination, low-eccentricity main-belt objects and high-eccentricity retrograde Centaurs/TNOs.

Source tables: [global enrichment](results/tables/top_1pct_W_visible_class_enrichment.csv), [class-specific summaries](results/tables/class_specific_weirdness_summary.csv), and [metric diagnostics](results/tables/metric_diagnostics.csv).

## View the case study

Read [`CASE_STUDY.md`](CASE_STUDY.md) for the scientific reasoning and [`PORTFOLIO_COPY.md`](PORTFOLIO_COPY.md) for resume and interview wording. Open [`index.html`](index.html) in a browser for the static visual case study backed by the committed plots in [`results/figures`](results/figures).

## Reproduce the analysis

> Environment restoration and pipeline execution were validated in a clean clone. Exact reproduction of the July 2026 results still requires the original July inputs, archived with checksums and provenance tied to the matching code and configuration. The score describes orbital geometry; predictive utility for dynamical instability remains untested.

The repair merged on October 31, 2026. For dated validation evidence, archive requirements, and setup details, see [`SETUP_AND_REPRODUCIBILITY_REPORT.md`](SETUP_AND_REPRODUCIBILITY_REPORT.md). The documented full live-data validation ran in September; it did not regenerate the committed July results.

### Requirements

- R 4.3.3, the validated version; newer releases require separate compatibility checks;
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

The full run downloads the live bound-asteroid records matching the configured query and regenerates outputs from those inputs. The live catalog cannot supply the original July inputs on demand; this command does not establish exact historical reproduction.

To rerun only the analysis stages against the most recent local snapshot, which need not be the July dataset:

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
- first-order uncertainty propagation and quality-screen sensitivity;
- scientific visualization and interpretation;
- `renv` dependency locking, automated smoke tests, and GitHub Actions.

## Scope and limitations

`W_visible` is an interpretable **descriptive index of orbital geometry**. Class enrichment and sensitivity checks evaluate its behavior; they do not establish superiority over simpler scores or predictive performance for dynamical instability. Current uncertainty diagnostics use marginal `sigma_e` and `sigma_i`, without their covariance.

The next priorities are:

1. recover and archive the inputs for the intended result set, with checksums, provenance, and matching code/configuration;
2. benchmark against eccentricity, inclination, and class-aware anomaly baselines;
3. improve uncertainty estimates with full covariance and add fixed-k ranking-stability comparisons;
4. test dynamical utility with N-body integrations of class-relative leaders and matched controls.

Data archiving and benchmarking can proceed independently. See the [case study](CASE_STUDY.md#what-i-would-do-next) for research details.

## Data source

NASA/JPL Small-Body Database Query API: <https://ssd-api.jpl.nasa.gov/doc/sbdb_query.html>

