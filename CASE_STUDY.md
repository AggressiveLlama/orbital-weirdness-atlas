# Orbital Weirdness Atlas: Portfolio Case Study

## Overview

I analyzed approximately 1.55 million bound asteroid orbits from NASA/JPL’s Small-Body Database to investigate whether orbital “weirdness” could be represented by an interpretable scalar. The project combined data engineering, orbital geometry, statistics, visualization, and scientific model criticism.

## Problem

Raw orbital elements are physically meaningful but awkward to compare at a glance. An object may be unusual because of eccentricity, inclination, retrograde motion, or a combination. I wanted a transparent score that preserved those ingredients rather than hiding them inside a black-box model.

## Metric

The primary metric was

\[
W_{\mathrm{visible}}=\sqrt{e^2+\left(2\sin\frac{i}{2}\right)^2}.
\]

This is zero for a circular, coplanar, prograde orbit. The inclination term is the chord distance between the orbit’s unit angular-momentum direction and the reference ecliptic normal.

I also calculated

\[
H_{KL}=\sqrt{1-e^2}\cos i, 
\]

the z-component of the angular momentum vector.

## Data pipeline

The JPL data pull exposed several realistic engineering problems:

1. The Arrow installation lacked Zstandard support, so the pipeline was modified to detect available Parquet codecs and fall back safely.
2. Identifier fields such as provisional designations were inferred as numeric in some pages and text in others, producing incompatible schemas. The downloader was revised to convert only documented numeric fields.
3. The live database can change during pagination, so each run creates a timestamped snapshot and manifest rather than analyzing the endpoint directly.

The result was a resumable, reproducible workflow capable of processing the complete population rather than relying on a convenience sample.

## Global findings

The metric recovered an interpretable hierarchy of populations. Centaurs and Apollos were enriched by 52.4× and 48.4× in the global top 1%, while inner-main-belt objects were represented at only 0.066× their baseline share.

Class labels explained part, but far from all, of metric variation. This was desirable: the metric recognized population structure without simply reproducing the database’s class field.

## Class-relative anomaly detection

Global anomaly scores mainly return populations that are globally unusual. To identify unusual members of otherwise ordinary classes, I added:

- within-class percentile rank;
- robust z-score based on the class median and MAD;
- empirical rank surprisal.

This revealed different forms of orbital abnormality. The leading inner-main-belt object had low eccentricity but approximately 55° inclination. The leading Amor combined eccentricity near 1 with a strongly retrograde inclination.

## Component decomposition

Because

\[
W_{\mathrm{visible}}^2=e^2+\left(2\sin\frac{i}{2}\right)^2,
\]

the score can be decomposed exactly into eccentricity and inclination shares. Ordinary NEO populations were often eccentricity-dominated, but their class-relative extreme tails became inclination-dominated. Among the top 1%, inclination contributed 98.4% for Jupiter Trojans and 96.9% for inner-main-belt objects.

## Uncertainty and robustness

The metric uncertainties propagated from reported `sigma_e` and `sigma_i` were generally tiny compared with the observed high scores. Quality screening altered exact leaderboards, especially in classes containing many short-arc objects, but the principal population patterns survived.

The original Jaccard stability plot also produced a methodological lesson: comparing separate top-1% sets confounds rank stability with changes in sample size. Directional retention and fixed-k comparisons are better diagnostics.

## Negative result

The most important negative finding was that `W_visible` and signed `H_KL` were almost perfectly rank-correlated:

\[
\rho_S\approx -0.999977.
\]

For low eccentricity and inclination,

\[
H_{KL}\approx1-\frac{W_{\mathrm{visible}}^2}{2}.
\]

I therefore rejected the original interpretation of these quantities as independent weirdness dimensions. `W_visible` is the more intuitive descriptive index, while `H_KL` supplies physical interpretation.

## What I would do next

A journal-oriented continuation would:

1. benchmark against eccentricity alone, inclination alone, robust Mahalanobis distance, local density methods, and established orbital-similarity criteria;
2. introduce a direction-blind plane metric to separate plane tilt from retrograde motion;
3. Monte Carlo full JPL covariance matrices for top-ranked objects;
4. run N-body integrations on class-relative leaders and matched controls to test whether geometric weirdness predicts dynamical instability.

## Outcome

The project demonstrates that an explicitly constructed, interpretable metric can organize a very large astronomical catalog, recover physically sensible population differences, and identify compelling individual anomalies. It also demonstrates the more important scientific habit of revising the interpretation when a proposed second metric proves redundant.
