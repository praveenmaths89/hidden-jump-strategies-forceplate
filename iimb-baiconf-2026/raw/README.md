# raw/ (not in Git)
The original VALD ForceDecks export (`vald/<testId>.parquet`, `vald/<testId>_trials.json`, `vald/tests.csv`,
`vald/profiles.json`, `vald/groups.json`) and the private keys (`private_keys/codebook.json`,
`private_keys/03_athlete_sports_gender_mapping.csv`) identify athletes, many of them minors, and are never committed.
They are kept in the private replication package (`IIMB_BAICONF2026_package.zip`). Copy them here to run
`Rscript R/00_run_all.R` from raw; otherwise run `SKIP_RAW=1 Rscript R/00_run_all.R`, which starts from `../data/cmj_trials_deidentified.csv`.
