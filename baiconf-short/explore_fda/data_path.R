# Locates the de-identified trial file (env var CMJ_DATA overrides).
# Repository layout: baiconf-short/explore_fda/ -> ../../iimb-baiconf-2026/data/
# Workspace layout:  explore_fda/               -> ../github-branch/iimb-baiconf-2026/data/
cmj_data_path <- function() {
  p <- Sys.getenv("CMJ_DATA", "")
  if (nzchar(p)) return(p)
  cand <- c("../../iimb-baiconf-2026/data/cmj_trials_deidentified.csv",
            "../github-branch/iimb-baiconf-2026/data/cmj_trials_deidentified.csv",
            "../../github-branch/iimb-baiconf-2026/data/cmj_trials_deidentified.csv")
  hit <- cand[file.exists(cand)]
  if (!length(hit)) stop("cmj_trials_deidentified.csv not found; set CMJ_DATA")
  hit[1]
}
