#!/usr/bin/env Rscript
# Runs the whole BAICONF short-paper pipeline end to end (seed 2026 in every script).
# Usage (from explore_fda/):  Rscript run_all.R      [CMJ_DATA=/path/to/cmj_trials_deidentified.csv]
steps <- c("audit_sampling.R", "time_norm_sensitivity.R", "run_explore.R", "srvf_landing.R", "within_between_check.R", "make_paper_outputs.R")
if (file.exists("srvf_landing_fit.rds") && Sys.getenv("KEEP_SRVF_CACHE") != "1") file.remove("srvf_landing_fit.rds")   # refit SRVF unless asked to keep the cache
t0 <- Sys.time()
for (s in steps) {
  cat(sprintf("\n===== %s (%s) =====\n", s, format(Sys.time(), "%H:%M:%S")))
  st <- system2(file.path(R.home("bin"), "Rscript"), s)
  if (st != 0) stop(s, " failed with status ", st)
}
cat(sprintf("\nAll steps finished in %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
