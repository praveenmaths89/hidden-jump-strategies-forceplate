# Replication package: *Revealing hidden jump strategies beyond conventional force-plate metrics*

BAICONF 2026 (IIM Bangalore) full paper, submission BAI2575, formatted for *IIMB Management Review*.
Authors: Praveen Chougale (Koita Centre for Digital Health, IIT Bombay) and Usha Ananthakumar (SJMSOM, IIT Bombay).
Package built 13 November 2026.

> **Raw VALD data are NOT included in this copy (13 Nov 2026, at the authors' request).** `raw/` contains only a
> README. The original VALD ForceDecks export and the pseudonym key identify athletes (many under 18) and are covered by
> the non-disclosure / data-sharing agreement with PhysioQinesis / Performance Lab; the authors hold them separately.
> To rerun from raw, copy the export into `raw/vald/` and the keys into `raw/private_keys/`; otherwise run
> `SKIP_RAW=1 Rscript R/00_run_all.R`, which starts from the de-identified file `data/cmj_trials_deidentified.csv`.

## One command, raw data to every number in the paper

```bash
cd <this folder>
Rscript install_packages.R      # once
Rscript R/00_run_all.R          # about 35 s: raw/ -> data/ -> output/
SKIP_RAW=1 Rscript R/00_run_all.R   # optional: start from the de-identified file (no raw data needed)
```
All paths are relative to this folder. The console output is saved to `output/run_log.txt`.

## What the run checks (13 Nov 2026 result)
| Check | Result |
|---|---|
| Step 01: football test list rebuilt from raw (`tests.csv`, `profiles.json`, sport map) vs. the table the original Python pipeline wrote | 2,213 of 2,213 rows identical |
| Step 02: trial file rebuilt from the raw recordings vs. the file the paper was analysed from | same shape, max absolute difference 0, identical codes and missing-value pattern |
| Step 03: 42 values printed in the BAICONF analysis report (`validation/baiconf_report_values.csv`) | 42 of 42 reproduced exactly (`output/reproduction_check.csv`) |
| Step 03 vs. the paper repository (`hidden-jump-strategies-forceplate`) | in-text numbers (`numbers.tex`) and all CSV tables identical |

Known differences (documented, not fixed by changing numbers):
- The **submitted BAICONF abstract** (`paper/original/BAICONF2026_submitted_abstract_BAI2575.docx`) came from an earlier analysis whose code was not found: 817 trials / 213 athletes, 71% variance, 5–17% R². This pipeline gives 805 / 212, 74.8%, 2.7–13.1%. The manuscript reports only this pipeline's numbers.
- **Bug fixed in this package:** the original LaTeX Table 1 printed `5%` unescaped, so LaTeX dropped the rest of row R2 (813 trials) in the original PDFs. `R/03_analysis.R` line 427 now escapes it; no numbers change.
- **Figure numbering:** the pipeline diagram (old Figure 1) was removed from the IIMB manuscript. The R script still writes the files under their original names `Fig2_`–`Fig6_`; in the IIMB manuscript and Overleaf project they are Figures 1–5 (Fig2→Fig. 1, Fig3→Fig. 2, Fig4→Fig. 3, Fig5→Fig. 4, Fig6→Fig. 5).
- `overleaf/` (in the zip package: `paper/iimb_formatted/overleaf/`) is the Overleaf-ready LaTeX source (pdfLaTeX + Biber) of the manuscript, title page, highlights and exhibits.

## Folder map
| Path | Contents |
|---|---|
| `raw/vald/` | **Unmodified** VALD export used by the paper: `<testId>.parquet` (dual-plate force, 1000/500 Hz) and `<testId>_trials.json` (vendor trial results) for the 333 male football CMJ tests; `tests.csv` (all tests, body mass); `profiles.json` (names, DOB, sex – identifiable); `groups.json` |
| `raw/private_keys/` | `codebook.json` (VALD id → pseudonymous code) and `03_athlete_sports_gender_mapping.csv` (sport and sex by athlete, from the Azure Databricks backup; contains names) |
| `R/00_run_all.R` | Runner: steps 01–03 in order, writes `output/run_log.txt` |
| `R/01_build_test_list.R` | R port of the Python `athlete_table()` + de-identification: football tests with sex and age (0.1 y) → `data/interim/tests_coverage.csv` |
| `R/02_extract_trials_from_raw.R` | The paper's extraction script (paths changed only): raw recordings → `data/cmj_trials_deidentified.csv` (833 trials, 101-point take-off, 1-s landing and lowest-COM landing curves, vendor metrics, QC helpers) |
| `R/03_analysis.R` | The paper's single analysis script (`run_all.R`; output folders renamed; % fix): QC, body-weight and phase normalisation, PCA, interpretation, matched bands, regression, athlete-grouped CV, bootstrap, variance decomposition, figures, LaTeX tables, in-text numbers, reproduction check |
| `data/` | De-identified files written by steps 01–02 |
| `output/main_lowest_com/`, `output/sensitivity_1s/` | Tables (CSV), figures (PNG), intermediate curves for the main and 1-s landing analyses |
| `output/paper_figures/`, `output/paper_figures_eps/` | Manuscript Figures 2–6 (PDF, EPS) |
| `output/paper_tables_latex/`, `output/paper_numbers/numbers.tex` | Manuscript Tables 1–6 and every in-text number |
| `output/reproduction_check.csv`, `run_log.txt`, `sessionInfo.txt` | Checks, console log, software versions |
| `validation/` | Reference files the run compares against (original de-identified trial file, Python coverage table, BAICONF report values) |
| `paper/iimb_formatted/` | IIMB MR submission files: anonymised manuscript (DOCX, PDF), separate title page, exhibits file (tables + figures), highlights |
| `paper/original/` | Submitted BAICONF abstract, the BAICONF analysis report (PDF), and the full LaTeX source + PDFs of the journal manuscript the IIMB version was built from |
| `paper/build_scripts/` | Scripts that convert the LaTeX source + `output/` into the IIMB files (pandoc 3.14, APA 7 CSL, python-docx, tectonic) |

## Software
R 4.5.3 (conda-forge build) with dplyr 1.2.1, tidyr 1.3.2, ggplot2 4.0.3, patchwork 1.3.2, nlme 3.1.170, arrow 25.0.1, jsonlite 2.0.0 (`packages.csv`; full `sessionInfo()` in `output/sessionInfo.txt`). Figures use Arial via Cairo; without Arial, R substitutes a similar font (numbers are unaffected). Random steps (CV folds, one-trial draw, 2,000 athlete bootstraps) use `set.seed(2026)`.

## Licence
Code: MIT (`LICENSE`). Data and outputs: not MIT; review and reproduction only (`DATA_LICENSE.md`). Raw data: private, see warning above.
