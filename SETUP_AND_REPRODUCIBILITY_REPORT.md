# Orbital Weirdness Atlas: Setup and Reproducibility Report

**Prepared:** 2026-09-19

**Merged:** 2026-10-31, [PR #1](https://github.com/AggressiveLlama/orbital-weirdness-atlas/pull/1)

**Merge commit:** [`4804830`](https://github.com/AggressiveLlama/orbital-weirdness-atlas/commit/48048300f87a9d8eeaa48753cf5309648b3a1881)

**Repository:** `AggressiveLlama/orbital-weirdness-atlas`

**Historical repair branch:** `codex/reproducible-setup`

**Starting commit:** `a5144c4` (`Add files via upload`)

## Outcome

The October 31 merge established a runnable R project with locked package dependencies. The repair provides:

- a conventional project layout with working paths;
- an R 4.3.3 `renv` lockfile containing 57 packages;
- a single full-pipeline entry point plus resumable data downloads;
- deterministic, network-free smoke tests;
- a GitHub Actions workflow for clean-room checks;
- documentation for setup, execution, data, results, and limitations;
- a documented successful end-to-end validation against the September 2026 JPL SBDB catalog.

The committed July 2026 scientific outputs were preserved and reorganized. The September validation run was performed in a separate clean clone so a live-data refresh could not silently rewrite the published case study.

> Environment restoration and pipeline execution were validated in a clean clone. Exact reproduction of the July 2026 results still requires the original July inputs, archived with checksums and provenance tied to the matching code and configuration. The score describes orbital geometry; predictive utility for dynamical instability remains untested.

The [README](README.md#project-summary) owns the canonical project description and quick start; the [case study](CASE_STUDY.md) owns scientific interpretation and research priorities. This report records the repair and its dated execution evidence.

## 1. What the audit found

| Finding | Why it mattered | Repair |
|---|---|---|
| Every file had been uploaded at repository root | Script and website paths referred to directories that did not exist | Created `R/`, `data/`, `results/figures/`, `results/tables/`, `tests/`, and `.github/workflows/`; moved files and updated references |
| Analysis scripts sourced `R/functions.R`, but only `functions.R` existed at root | The analysis stopped immediately | Moved the helper file to `R/functions.R` |
| `index.html` expected images below `assets/` | The case-study page displayed broken images | Pointed the page to `results/figures/` and corrected its repository map |
| No project-local dependency specification existed | A future package update could change behavior or break the code | Added `renv.lock`, `.Rprofile`, `renv/activate.R`, and project settings |
| The package installer always targeted current package versions | Setup was not repeatable | Replaced it with an `renv::restore()` bootstrap |
| There was no command that ran the whole analysis | Users had to infer script order and shared state could leak between stages | Added `run_all.R`, which runs each stage in a fresh R process and stops on the first failure |
| Download names were always based on the current timestamp | An interrupted download could not be resumed predictably | Added validated `SBDB_SNAPSHOT_ID` support and documented it |
| API responses were not checked against an expected API version | An upstream response-contract change could be mistaken for valid data | Added response-signature validation, an explicit user agent, and manifest metadata |
| A retry option was incompatible with the locked `httr2` version | The download failed with the reproducible environment | Used the retry interface supported by `httr2` 1.0.0 |
| Large generated data had no ignore policy | A routine run could accidentally add roughly a gigabyte to Git | Added a focused `.gitignore` for raw data, processed data, Parquet, temporary files, and R state |
| There were no automated tests or CI checks | Path, parsing, metric, or storage regressions could go unnoticed | Added a smoke test and a GitHub Actions workflow |

## 2. Repository layout after repair

```text
orbital-weirdness-atlas/
├── .github/workflows/r-smoke-test.yml
├── R/functions.R
├── data/README.md
├── renv/
├── results/
│   ├── figures/
│   ├── tables/
│   └── README.md
├── tests/smoke_test.R
├── 00_install_packages.R
├── 01_download_sbdb.R
├── 02_compute_metrics.R
├── 03_visualize_and_diagnose.R
├── 04_class_specific_analysis.R
├── config.R
├── run_all.R
├── renv.lock
├── OrbitalWeirdnessAtlas.Rproj
└── index.html
```

This layout gives each kind of file one predictable home:

- reusable R functions live in `R/`;
- executable stages remain obvious at repository root;
- large, local-only data lives in `data/`;
- compact publishable outputs live in `results/`;
- automated checks live in `tests/` and `.github/workflows/`.

## 3. Environment initialization

The project was initialized around R 4.3.3 and locked with `renv` 1.2.4. The lockfile records 57 packages, including Arrow 25.0.1 and the analysis stack (`dplyr`, `ggplot2`, `httr2`, `jsonlite`, `purrr`, `readr`, `rlang`, `scales`, `stringr`, `tibble`, and `tidyr`).

For a new clone, the complete restore command is:

```bash
Rscript 00_install_packages.R
```

That script performs only three setup jobs:

1. supplies a CRAN mirror if R has none configured;
2. installs `renv` if the machine does not already have it;
3. runs `renv::restore(prompt = FALSE)` to install the versions in `renv.lock`.

The project-local library is excluded from Git. The small activation scripts and lockfile are committed; downloaded package binaries and source trees are not.

## 4. Pipeline and data-snapshot controls

The complete analysis now runs with:

```bash
Rscript run_all.R
```

`run_all.R` executes the four numbered scripts in order. Each stage receives a clean R session, so the run cannot succeed accidentally because an object was left in an interactive workspace.

To reuse the newest local download and rerun only computation and visualization:

```bash
Rscript run_all.R --skip-download
```

To resume an interrupted download, supply the same identifier used on its first attempt:

```bash
SBDB_SNAPSHOT_ID=20260919T120000Z Rscript 01_download_sbdb.R
```

The downloader:

- sorts by stable `spkid` before offset pagination;
- writes each page to a temporary file and then atomically renames it;
- skips complete pages when resuming;
- keeps identifier columns as text, including designations such as `2005 TQ11`;
- selects a Parquet compression codec supported by the installed Arrow build;
- validates the SBDB API signature version;
- sends an identifiable user agent;
- records start/end counts, fields, constraints, API version, and retrieval time in `manifest.json`;
- warns visibly if the live catalog count changes during pagination.

The query targets asteroids with `0 <= e < 1` and a defined inclination. Timestamped local files and manifests preserve the retrieved pages and their metadata; they do not freeze the live API. Stable sorting, atomic writes, and resume behavior do not guarantee a single consistent catalog state across pages.

## 5. Automated checks added

Run the local test with:

```bash
Rscript tests/smoke_test.R
```

It checks:

- every R file parses;
- mixed-format JPL designations remain character values;
- known metric values are correct:
  - circular prograde orbit: `W_visible = 0`, `H_KL = 1`;
  - circular retrograde orbit: `W_visible = 2`, `H_KL = -1`;
  - eccentric coplanar orbit with `e = 0.6`: `W_visible = 0.6`, `H_KL = 0.8`;
- ranking direction is correct;
- eccentricity and inclination component shares sum to one for nonzero scores;
- a Parquet write/read round trip preserves rows and identifiers.

The GitHub Actions workflow is configured to restore R 4.3.3 and the locked package library, check `renv::status()`, and run the same smoke test on pushes and pull requests. Dependency restoration can require network access; the smoke test itself is network-free. The workflow does not run the full JPL download or analysis. The full live-data execution below was a separate validation run; its success is not evidence that every later CI run passed.

## 6. Validation evidence

In September 2026, validation was performed first in the repaired working tree, then in a fresh clone containing only committed files. The table records those historical checks, not a new run on the October merge date.

| Check | Result |
|---|---|
| Local smoke test | Passed; Arrow selected Zstandard compression |
| `renv::status()` | Passed; project reported a consistent state |
| Clean-clone dependency restore | Passed; 57 locked packages restored |
| Clean-clone smoke test | Passed |
| Full four-stage live-data pipeline (separate September run) | Passed |
| Processed asteroid rows | 1,565,665 |
| Missing/blank `spkid` values | 0 |
| Duplicate `spkid` rows | 0 |
| Raw snapshot size | 253 MB |
| Processed Parquet size | 720 MB |
| September all-valid Spearman correlation, `W_visible` vs. `H_KL` | -0.9999753095 |

The September validation download began when the JPL query reported 1,565,664 matching objects and ended at 1,565,665. That one-object change was recorded as `count_changed_during_download: true`. The final processed data contained 1,565,665 unique, nonblank SPK IDs. These ID checks do not establish that all pages represent one consistent state of the live catalog; count checks also cannot detect every change to existing orbital solutions.

The committed [July metric diagnostics](results/tables/metric_diagnostics.csv) instead contain 1,553,106 valid orbits and 1,381,626 after retaining `condition_code <= 5` or missing codes. The July summary correlation of approximately −0.999977 refers to that screened subset. The September all-valid statistic and row count describe a different run and must not silently replace the July findings.

This is a useful real-world distinction:

- **environment reproducibility** means the same code and package versions can be restored;
- **data reproducibility** means the same input bytes remain available;
- **result reproducibility** requires both.

The repair documents successful restoration of the package environment and pipeline execution. The lockfile does not pin every operating-system or compiled-library detail, so it alone cannot promise byte-identical outputs across platforms. The live JPL endpoint cannot supply historical input bytes on demand. Exact result reproduction also requires the matching code, configuration, and relevant runtime details.

## 7. Preserving exact historical results

The repository intentionally ignores the raw and processed Parquet files because the validation copy alone occupied about 973 MB. Ignoring large data protects normal Git workflows, but exact historical reproduction needs a separate data-release strategy.

Exact reproduction of the committed July results requires the original July input files, which are not included in this repository. Archiving the September validation inputs would preserve that run; it would not reconstruct July's inputs. If the original files cannot be recovered, archive a newly dated result set and keep exact July reproduction explicitly unresolved.

For a publication-grade data release:

1. identify the target run, retain its original input files and `manifest.json`, and document any known catalog drift;
2. compute SHA-256 checksums for every raw part and processed dataset;
3. upload the frozen files to durable, versioned storage such as Zenodo, an institutional repository, or versioned object storage;
4. record the release URL, DOI or object version, checksums, provenance, license, and download/verification instructions in `data/README.md`;
5. bind the release to the matching code commit, configuration, and lockfile, recording relevant runtime/platform details and tagging the code version.

A manifest records what the code requested and observed. Checksums identify retained bytes; an archive makes them retrievable. Connecting those files to the actual analysis run requires provenance and the matching code/configuration.

Data archiving can proceed independently of the next scientific step, baseline benchmarking. Full-covariance uncertainty analysis, fixed-k ranking-stability comparisons, and N-body tests follow in the [case-study roadmap](CASE_STUDY.md#what-i-would-do-next).

## 8. Day-to-day command sheet

```bash
# First setup
Rscript 00_install_packages.R

# Fast confidence check
Rscript tests/smoke_test.R
Rscript -e 'renv::status()'

# Complete refresh from JPL
Rscript run_all.R

# Recompute from the newest local snapshot
Rscript run_all.R --skip-download

# Resume one named snapshot
SBDB_SNAPSHOT_ID=my_snapshot_20260919 Rscript 01_download_sbdb.R
Rscript run_all.R --skip-download
```

Always run these commands from the repository root.

## 9. Troubleshooting notes

### `R/functions.R` or another relative path cannot be found

Confirm the shell's current directory is the repository root. The pipeline deliberately uses project-relative paths.

### Arrow fails to install

Use R 4.3.3 where practical and ensure a C/C++ build toolchain is available if no suitable binary exists. Rerun `Rscript 00_install_packages.R`; `renv` will continue toward the locked state.

### Parquet compression fails

The helper probes codecs and selects a supported one. The September validation environment selected `zstd`. If all preferred codecs fail, check the Arrow installation rather than changing the analysis code first.

### The download stopped midway

Rerun `01_download_sbdb.R` with the same `SBDB_SNAPSHOT_ID`. Existing completed page files are skipped. Do not point a new query definition at an old snapshot directory.

### Results differ from the committed figures

First compare available input manifests, checksums, and code/configuration versions. The JPL catalog is live; row counts and orbital solutions change. Exact July comparison requires the original July inputs. A small result change is not automatically an environment failure.

### The API version check fails

Treat it as a schema-review prompt. Compare the current JPL documentation with `SBDB_EXPECTED_API_VERSION` and the parser before updating the expected version.

## 10. Choices made deliberately

- The July figures and tables were reorganized, not replaced with the September validation outputs.
- Raw and processed Parquet data were not committed to Git.
- The metrics remain descriptive geometry measures; no new claim of dynamical stability or causal prediction was added.
- The September validation outputs were excluded from the merged repair; the committed scientific figures and tables remain the July results.

Those boundaries keep infrastructure repair, data refresh, and scientific revision as three distinct decisions.

## Appendix A: Repeatable repair recipe for future repositories

### Step A: protect and inventory

```bash
git status --short --branch
git switch -c setup/reproducible-project
rg --files
rg -n 'source\(|read_|write_|\.png|\.csv|\.parquet' --glob '*.R' --glob '*.html' --glob '*.md'
```

Before moving anything, map every path that code or documentation expects. Work on a branch so file moves, generated changes, and accidental deletions remain reviewable.

### Step B: choose a boring, predictable layout

Put reusable code, local data, published outputs, tests, and automation in separate directories. Update code and HTML references in the same commit as the moves. Git will normally recognize unchanged binary files as renames.

### Step C: pin the environment

Initialize `renv`, install the actual dependencies, snapshot them, and verify `renv::status()`. Restore into an empty library at least once; a lockfile copied from somewhere else is not evidence that it works.

From the repository root:

```r
install.packages("renv")
renv::init(bare = TRUE)
renv::install(c("arrow", "dplyr", "ggplot2"))
renv::snapshot()
```

Commit `renv.lock`, `.Rprofile`, and `renv/activate.R`. Do not commit `renv/library/`.

When changing a dependency later, make the change intentionally and snapshot it:

```r
renv::install("package-name@version")
renv::snapshot()
renv::status()
```

Review the lockfile diff before committing it. A lockfile is useful because it makes dependency changes visible, not merely because it exists.

### Step D: create one entry point

Provide one documented command that executes stages in a defined order and exits nonzero on failure. Prefer isolated processes for analysis stages unless shared in-memory state is an explicit design choice.

### Step E: separate source data from Git

Ignore large or regenerable files. Keep small result tables, figures, manifests, and documentation when they help reviewers understand the work. If exact data is essential, archive it externally and record checksums.

### Step F: test the risky assumptions

For a data-analysis project, useful fast tests include:

- parsing every script;
- known-value tests for formulas;
- identifiers that look both numeric and nonnumeric;
- missing-value behavior;
- sort/rank direction;
- one storage-format round trip;
- configuration and API-schema expectations.

Avoid putting a full million-row network download in the ordinary CI job. Keep CI deterministic and fast, then run the expensive integration test separately.

### Step G: validate from a clean clone

```bash
git status --short
git clone --no-local . /tmp/project-cleanroom
cd /tmp/project-cleanroom
Rscript 00_install_packages.R
Rscript tests/smoke_test.R
Rscript -e 'renv::status()'
```

Then run the full pipeline in that clone when time, storage, and API load permit. A clean clone exposes uncommitted helper files, accidental global-library dependencies, case-sensitive path mistakes, and undeclared setup steps.

### Step H: review generated changes before publishing

```bash
git status --short
git diff --stat
git diff --check
git log --oneline --decorate -3
```

Generated output changes may be scientifically valid, but they should never slip into a setup commit without review.

