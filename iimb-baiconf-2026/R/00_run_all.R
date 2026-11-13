# =============================================================================
# 00_run_all.R -- raw VALD export -> every table, figure and number in the paper
# Usage (from the package root):  Rscript R/00_run_all.R
#   Step 01  raw/ -> data/interim/tests_coverage.csv   (football tests, sex, age)
#   Step 02  raw/ -> data/cmj_trials_deidentified.csv  (833 male CMJ trials, curves)
#   Step 03  data/ -> output/  (QC, PCA, matched bands, regression, robustness,
#            variance decomposition, figures, tables, in-text numbers,
#            reproduction check against the BAICONF report)
# Set SKIP_RAW=1 to start at step 03 from the committed de-identified file.
# =============================================================================
if (!dir.exists("R")) stop("Run from the package root: Rscript R/00_run_all.R")
dir.create("output", showWarnings = FALSE)
log_con <- file("output/run_log.txt", open = "wt")
run <- function(f) {
  cat("\n================", f, "================\n")
  t0 <- Sys.time()
  sys.source(f, envir = new.env(parent = globalenv()))
  cat(sprintf("---- %s finished in %.1f s\n", f, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
sink(log_con, split = TRUE)
if (Sys.getenv("SKIP_RAW") != "1") {
  run("R/01_build_test_list.R")
  run("R/02_extract_trials_from_raw.R")
} else {
  src <- if (file.exists("validation/original_cmj_trials_deidentified.csv")) "validation/original_cmj_trials_deidentified.csv" else "../data/cmj_trials_deidentified.csv"
  file.copy(src, "data/cmj_trials_deidentified.csv", overwrite = TRUE)
}
run("R/03_analysis.R")
sink()
close(log_con)
