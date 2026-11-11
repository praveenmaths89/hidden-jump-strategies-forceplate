# =============================================================================
# 00_extract_from_raw.R
# PRIVATE STEP: builds the de-identified analysis file from raw VALD data.
#
# This script needs the raw ForceDecks exports (recordings + trial results),
# which identify athletes and are NOT part of the repository. Everyone else
# starts at script 01, using data/cmj_trials_deidentified.csv.
#
# Input (private, outside the repo; set RAW_ROOT to override):
#   <RAW_ROOT>/raw/<testId>.parquet          1000 Hz dual-plate recording
#   <RAW_ROOT>/raw/<testId>_trials.json      VALD trial results (vendor metrics)
#   <RAW_ROOT>/raw/tests.csv                 VALD test list (body mass)
#   <RAW_ROOT>/interim/codebook.json         VALD id -> pseudonymous code key
#   <RAW_ROOT>/processed/tests_coverage.csv  football tests with sex and age
# Output:
#   data/cmj_trials_deidentified.csv         one row per CMJ trial (male)
#
# Curve blocks in the output (force in Newtons, 101 points per phase):
#   to_000..to_100   take-off phase: VALD movement onset -> take-off
#   ld_000..ld_100   landing phase:  touch-down -> VALD trial end (+1 s)
#   ldc_000..ldc_100 landing phase, sensitivity: touch-down -> lowest
#                    centre-of-mass point (velocity back to zero)
# =============================================================================

library(arrow)
library(jsonlite)
library(dplyr)

RAW_ROOT <- Sys.getenv("RAW_ROOT")   # path to the private VALD export (not distributed)
if (RAW_ROOT == "") stop("Set RAW_ROOT to the private VALD export folder")
N_GRID   <- 101   # points per phase (0, 1, ..., 100 % of the phase)
G        <- 9.81  # gravity (m/s^2)

# --- 1. Which tests: male football CMJ tests -------------------------------
coverage <- read.csv(file.path(RAW_ROOT, "processed", "tests_coverage.csv"))
cmj_tests <- coverage %>% filter(testType == "CMJ", sex == "Male")

# --- 2. Key from pseudonymous test code back to the VALD test id -----------
codebook <- fromJSON(file.path(RAW_ROOT, "interim", "codebook.json"))
test_key <- data.frame(testId    = names(codebook$test),
                       test_code = unlist(codebook$test))
trial_key <- data.frame(trialId    = names(codebook$trial),
                        trial_code = unlist(codebook$trial))
cmj_tests <- cmj_tests %>% left_join(test_key, by = "test_code")

# --- 3. Body mass recorded by VALD for each test ---------------------------
vald_tests <- read.csv(file.path(RAW_ROOT, "raw", "tests.csv"))
cmj_tests <- cmj_tests %>%
  left_join(vald_tests %>% select(testId, weight), by = "testId")

# --- 4. Helper: read one VALD result value from a trial --------------------
get_result <- function(results, code) {
  row <- results[results$limb == "Trial" & results$definition$result == code, ]
  if (nrow(row) == 0) return(NA_real_)
  row$value[1]
}

# --- 5. Helper: resample a force segment to N_GRID points ------------------
resample_phase <- function(time, force, t_start, t_end) {
  keep <- time >= t_start & time <= t_end
  approx(x = time[keep], y = force[keep],
         xout = seq(t_start, t_end, length.out = N_GRID), rule = 2)$y
}

# --- 6. Go through the tests one at a time ---------------------------------
rows <- list()
for (i in seq_len(nrow(cmj_tests))) {
  test <- cmj_tests[i, ]

  # 6a. raw recording: total vertical force = left plate + right plate
  rec   <- read_parquet(file.path(RAW_ROOT, "raw", paste0(test$testId, ".parquet")))
  time  <- rec$Time
  force <- rec$`Z Left` + rec$`Z Right`
  native_fs <- round(1 / median(diff(time)))

  # 6b. VALD trial results for this test
  trials <- fromJSON(file.path(RAW_ROOT, "raw", paste0(test$testId, "_trials.json")))
  trials <- trials[order(trials$startTime), ]

  for (j in seq_len(nrow(trials))) {
    res <- trials$results[[j]]

    # vendor events (seconds from start of recording)
    onset   <- get_result(res, "START_OF_MOVEMENT")
    takeoff <- onset + get_result(res, "CONTRACTION_TIME")   # stored in s
    landing <- takeoff + get_result(res, "FLIGHT_TIME")      # stored in s
    trial_end <- trials$endTime[j]                           # VALD: landing + 1 s

    # quiet stance before the movement (for body-weight QC)
    quiet <- time >= trials$startTime[j] & time < onset - 0.03
    # force while airborne (should be ~0 N)
    airborne <- time > takeoff + 0.02 & time < landing - 0.02

    # end of landing for the SENSITIVITY version: lowest centre-of-mass
    # point after touch-down (vertical velocity back to zero). Velocity at
    # touch-down is -g * flight_time / 2; then integrate (F - mg) / m.
    lowcom_end <- NA_real_
    if (!is.na(test$weight) && test$weight > 0) {
      after <- time >= landing & time <= trial_end
      dt    <- c(0, diff(time[after]))
      v     <- -G * (landing - takeoff) / 2 +
               cumsum((force[after] - test$weight * G) / test$weight * dt)
      if (any(v >= 0)) lowcom_end <- time[after][which(v >= 0)[1]]
    }

    # phase curves in Newtons, each resampled to 0-100 %
    takeoff_curve <- resample_phase(time, force, onset, takeoff)
    landing_curve <- resample_phase(time, force, landing, trial_end)
    names(takeoff_curve) <- sprintf("to_%03d", 0:100)
    names(landing_curve) <- sprintf("ld_%03d", 0:100)
    # sensitivity landing curve: touch-down -> lowest centre of mass
    if (is.na(lowcom_end)) {
      lowcom_curve <- rep(NA_real_, N_GRID)
    } else {
      lowcom_curve <- resample_phase(time, force, landing, lowcom_end)
    }
    names(lowcom_curve) <- sprintf("ldc_%03d", 0:100)

    rows[[length(rows) + 1]] <- data.frame(
      athlete      = test$athlete,
      test_code    = test$test_code,
      trial_code   = trial_key$trial_code[match(trials$id[j], trial_key$trialId)],
      trial_no     = j,
      age          = test$age,
      body_mass_kg = test$weight,
      native_fs    = native_fs,
      # the four conventional vendor metrics
      jump_height_cm         = get_result(res, "JUMP_HEIGHT"),
      conc_peak_force_n      = get_result(res, "PEAK_CONCENTRIC_FORCE"),
      ecc_braking_impulse_ns = get_result(res, "ECCENTRIC_BRAKING_IMPULSE"),
      conc_impulse_100ms_ns  = get_result(res, "CONCENTRIC_IMPULSE_100MS"),
      # extra vendor values used only to interpret the components
      peak_landing_force_n   = get_result(res, "PEAK_LANDING_FORCE"),
      cm_depth_cm            = get_result(res, "COUNTERMOVEMENT_DEPTH"),
      contraction_time_s     = get_result(res, "CONTRACTION_TIME"),
      flight_time_s          = get_result(res, "FLIGHT_TIME"),
      # QC helpers
      quiet_mass_kg    = mean(force[quiet]) / G,
      quiet_n_samples  = sum(quiet),
      flight_force_n   = mean(force[airborne]),
      landing_to_lowcom_s = lowcom_end - landing,
      t(round(takeoff_curve, 2)), t(round(landing_curve, 2)),
      t(round(lowcom_curve, 2))
    )
  }
}
trials_out <- bind_rows(rows)

# --- 7. Save (no names, no VALD ids, no dates) ------------------------------
write.csv(trials_out, "data/cmj_trials_deidentified.csv", row.names = FALSE)
cat("Wrote", nrow(trials_out), "trials from",
    length(unique(trials_out$athlete)), "athletes\n")
