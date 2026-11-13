# Orbital Weirdness Atlas: Portfolio Case Study

## Overview

In July 2026, I analyzed approximately 1.55 million bound asteroid orbits from NASA/JPL’s Small-Body Database to investigate whether orbital “weirdness” could be represented by an interpretable scalar. The project combined data engineering, orbital geometry, statistics, visualization, and scientific model criticism. The [README](README.md#project-summary) owns the canonical project description and setup instructions.

> Environment restoration and pipeline execution were validated in a clean clone. Exact reproduction of the July 2026 results still requires the original July inputs, archived with checksums and provenance tied to the matching code and configuration. The score describes orbital geometry; predictive utility for dynamical instability remains untested.

## Problem

Raw orbital elements are physically meaningful but awkward to compare at a glance. An object may be unusual because of eccentricity, inclination, retrograde motion, or a combination. I wanted a transparent score that preserved those ingredients rather than hiding them inside a black-box model.

## Metric

The primary metric was

\[
W_{\mathrm{visible}}=\sqrt{e^2+\left(2\sin\frac{i}{2}\right)^2}.
\]

This is zero for a circular, coplanar, prograde orbit. The inclination term is the chord distance between the orbit’s unit angular-momentum direction and the reference ecliptic normal; `i` is in radians in the formula.

I also calculated

\[
H_{KL}=\sqrt{1-e^2}\cos i, 
\]

the dimensionless normalized z-component of the specific orbital angular momentum:

\[
H_{KL}=\frac{h_z}{\sqrt{\mu a}},
\]

where `h_z` is the specific angular-momentum component normal to the reference ecliptic, `mu` is the gravitational parameter, and `a` is the semimajor axis.

## Data pipeline

The JPL data pull exposed several realistic engineering problems:

1. The Arrow installation lacked Zstandard support, so the pipeline was modified to detect available Parquet codecs and fall back safely.
2. Identifier fields such as provisional designations were inferred as numeric in some pages and text in others, producing incompatible schemas. The downloader was revised to convert only documented numeric fields.
3. The live database can change during pagination, so each run retains timestamped local data and a manifest. These record retrieval conditions; they do not freeze the upstream catalog or guarantee that all pages represent one catalog state.

The workflow processes the records returned by the configured bound-asteroid query (`0 <= e < 1`, with defined inclination), rather than using a convenience sample for the metric calculations. This scope excludes comets and unbound orbits.

The reproducibility repair merged on October 31, 2026, adding locked dependencies, a single pipeline entry point, resumable downloads, smoke tests, and GitHub Actions. Environment restoration and full execution were validated in a separate clean clone during September. The [setup report](SETUP_AND_REPRODUCIBILITY_REPORT.md) records that evidence and the remaining historical-data requirements; the committed July figures and tables were preserved.

## Global findings (July 2026)

The [July diagnostics](results/tables/metric_diagnostics.csv) contain 1,553,106 valid orbits and 1,381,626 after the screen retaining `condition_code <= 5` or missing codes. The enrichment, correlation, and class-relative results discussed below use the screened subset; retaining missing codes is a permissive screen, not a guarantee of orbit quality.

The metric recovered an interpretable hierarchy of populations. Centaurs and Apollos were enriched by 52.4× and 48.4× in the global top 1%, while inner-main-belt objects were represented at only 0.066× their baseline share.

Between-class differences accounted for approximately 18.5% of `W_visible` variance in the screened subset (one-way eta-squared ≈ 0.185 in the [metric diagnostics](results/tables/metric_diagnostics.csv)). This describes association with catalog classes; it does not establish anomaly-detection accuracy or an advantage over simpler scores.

## Class-relative anomaly detection

Global anomaly scores mainly return populations that are globally unusual. To identify unusual members of otherwise ordinary classes, I added:

- within-class percentile rank;
- robust z-score based on the class median and MAD;
- empirical rank surprisal.

For classes with at least 100 screened objects, this revealed different forms of unusual geometry. In the [July within-class table](results/tables/top_W_visible_within_each_class.csv), the leading inner-main-belt object had low eccentricity but approximately 55° inclination. The leading Amor combined eccentricity near 1 with a strongly retrograde inclination. These are ranked catalog objects, not claims of newly discovered bodies or dynamical instability.

## Component decomposition

Because

\[
W_{\mathrm{visible}}^2=e^2+\left(2\sin\frac{i}{2}\right)^2,
\]

the score can be decomposed exactly into eccentricity and inclination shares. The [class-specific table](results/tables/class_specific_weirdness_summary.csv) shows that Apollos, Amors, and Atens were eccentricity-dominated on average, while their within-class top 1% were inclination-dominated on average. Among the top 1% within each class, the mean inclination share was 98.4% for Jupiter Trojans and 96.9% for inner-main-belt objects.

## Uncertainty and robustness

The first-order uncertainties propagated from reported marginal `sigma_e` and `sigma_i` were generally small relative to the high scores. The calculation omits covariance between eccentricity and inclination; these are diagnostics, not complete orbital-uncertainty estimates. Full-covariance Monte Carlo analysis remains future work. Quality screening changed exact leaderboards, especially in classes containing many short-arc objects, so high scores alone do not establish robust individual anomalies.

The original Jaccard stability plot also produced a methodological lesson: comparing separate top-1% sets mixes selection changes with changes in set size. The [existing stability table](results/tables/class_rank_stability_quality_screen.csv) also reports directional retention (`all_top_retained_as_screened_top`), making its denominator explicit. Fixed-k comparisons on a defined comparison population remain a proposed improvement; the existing retention statistic still reflects the effects of the screen.

## Negative result

The most important negative finding was that `W_visible` and signed `H_KL` were almost perfectly inversely rank-correlated in the July quality-screened subset:

\[
\rho_S\approx -0.999977.
\]

For low eccentricity and inclination,

\[
H_{KL}\approx1-\frac{W_{\mathrm{visible}}^2}{2}.
\]

I therefore rejected the original interpretation of these quantities as independent weirdness dimensions for this catalog. Their near-redundancy is empirical; the small-angle relation is an approximation, not an identity for arbitrary eccentricity and inclination. `W_visible` supplies an interpretable descriptive index, while `H_KL` adds angular-momentum interpretation.

## What I would do next

The priorities are:

1. recover and archive the appropriate input files, with checksums and provenance tied to the matching code/configuration; exact July reproduction requires July inputs, while a newly archived download defines a new result set;
2. benchmark against eccentricity alone, inclination alone, class-aware robust Mahalanobis distance and local density methods, and established orbital-similarity criteria;
3. propagate full JPL covariance matrices through Monte Carlo sampling for top-ranked objects and add fixed-k ranking-stability comparisons;
4. run N-body integrations on class-relative leaders and matched controls to test whether geometric weirdness predicts dynamical instability.

Data archiving and benchmarking can proceed independently. A direction-blind plane metric separating plane tilt from retrograde motion is an optional research extension. No benchmark superiority or dynamical predictive performance has yet been established.

## Outcome

The project demonstrates a workflow for organizing a very large astronomical catalog, inspecting population differences, and surfacing candidate geometric outliers. It also demonstrates scientific model criticism: the observed redundancy of a proposed companion metric led to a narrower interpretation. The engineering evidence supports repeatable pipeline execution, while exact historical reproduction and dynamical validation remain separate tasks.

