# Portfolio Copy

## One-sentence project description

Built a reproducible R pipeline that analyzed approximately 1.55 million NASA/JPL small-body orbits and developed an interpretable, class-relative anomaly score for identifying unusual orbital geometries.

## Resume bullets

- Designed an end-to-end R/Arrow pipeline to paginate, normalize, snapshot, and analyze approximately 1.55 million records from NASA/JPL’s Small-Body Database.
- Developed an interpretable orbital-anomaly metric from eccentricity and inclination, then validated it with class enrichment, robust within-class rankings, uncertainty propagation, and quality-screen sensitivity tests.
- Identified physically meaningful outlier populations and individual bodies; found that inclination dominates the extreme within-class tail across most orbital classes.
- Diagnosed and corrected real data-engineering failures involving unavailable compression codecs and inconsistent Parquet schemas across API pages.
- Demonstrated that a proposed companion metric was nearly rank-redundant (Spearman ρ ≈ −0.99998), and revised the scientific interpretation rather than overstating the result.

## Thirty-second interview explanation

I wanted to see whether “orbital weirdness” could be measured transparently rather than with a black-box model. I downloaded the full bound-asteroid population from JPL, built a Parquet pipeline, defined a geometric score from eccentricity and inclination, and tested it globally and within orbital classes. The score recovered sensible populations and found individual outliers, especially high-inclination objects hidden inside otherwise ordinary classes. I also found that my second proposed metric was almost completely redundant, which became an important negative result. The next phase would test whether the geometric score predicts dynamical instability through N-body integrations.

## Skills keywords

R · tidyverse · ggplot2 · Arrow · Parquet · REST APIs · scientific computing · orbital mechanics · anomaly detection · statistics · uncertainty propagation · data visualization · reproducible research

## Suggested repository tagline

**Interpretable anomaly detection across 1.55 million JPL small-body orbits.**

## Suggested LinkedIn/project-post opening

What does it mean for an orbit to be “weird”? I built an R pipeline around NASA/JPL’s Small-Body Database to turn that deliberately informal question into a testable geometric metric, then applied it to roughly 1.55 million small bodies. The result identifies sensible population differences, surfaces unusual objects within their own classes, and—just as importantly—revealed that one of my proposed companion metrics was almost entirely redundant.
