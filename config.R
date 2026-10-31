# Stephen Gray July 2026
# Synapse8087@proton.me
# Project configuration --------------------------------------------------------

SBDB_ENDPOINT <- "https://ssd-api.jpl.nasa.gov/sbdb_query.api"
SBDB_EXPECTED_API_VERSION <- "1.0"
SBDB_USER_AGENT <- paste(
  "orbital-weirdness-atlas/1.0",
  "(contact: Synapse8087@proton.me)",
  "R/httr2"
)

# JPL's public SBDB Query API does not currently document an API-key parameter.
# Leave authentication out unless JPL gives you endpoint-specific instructions.

PAGE_SIZE <- 50000L
REQUEST_PAUSE_SECONDS <- 0.20
MAX_RETRIES <- 6L

# Pull all bound, elliptical asteroids. Comets and e >= 1 objects should be
# studied separately because H_KL = sqrt(1 - e^2) cos(i) is not real for e > 1.
SB_KIND <- "a"
SB_CONSTRAINTS <- list(
  AND = c(
    "e|GE|0",
    "e|LT|1",
    "i|DF"
  )
)

SBDB_FIELDS <- c(
  "spkid", "full_name", "pdes", "name", "kind", "class", "neo", "pha",
  "t_jup", "moid", "moid_jup",
  "orbit_id", "epoch", "e", "a", "q", "i", "om", "w", "ma", "per", "ad",
  "sigma_e", "sigma_a", "sigma_q", "sigma_i", "sigma_om", "sigma_w",
  "condition_code", "data_arc", "n_obs_used", "two_body", "source",
  "soln_date", "H", "diameter", "albedo", "rot_per"
)

# Plotting uses a class-stratified sample; calculations use the complete dataset.
PLOT_N_PER_CLASS <- 15000L
TOP_N <- 100L
RANDOM_SEED <- 271828L
MIN_CLASS_N <- 100L


# Class-relative analysis ------------------------------------------------------

CLASS_TOP_FRACTION <- 0.01
TOP_PER_CLASS <- 10L
CLASS_PLOT_N_PER_CLASS <- 5000L
MIN_CLASS_ANALYSIS_N <- 100L
