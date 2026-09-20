# Local data

The pipeline creates two untracked directories here:

- `raw/`: timestamped, resumable SBDB snapshots and their manifests;
- `processed/`: metric-enriched Parquet datasets and pointer files.

These files are intentionally excluded from Git because a complete snapshot is large and the live JPL catalog changes over time. The small, publication-facing outputs derived from the July 2026 analysis are committed under `results/`.
