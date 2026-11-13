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
SKIP_RAW=1 Rscript R/00_run_all.R   # about 8-9 min (2,000 bootstrap refits): de-identified data/ -> output/
Rscript R/00_run_all.R          # only with the raw export in raw/: raw/ -> data/ -> output/
```
All paths are relative to this folder. The console output is saved to `output/run_log.txt`. From the de-identified file the run ends with "42 of 42 report values reproduced exactly".

## What the run checks (13 Nov 2026 result; steps 01-02 need the raw export)
| Check | Result |
|---|---|
| Step 01: football test list rebuilt from raw (`tests.csv`, `profiles.json`, sport map) vs. the table the original Python pipeline wrote | 2,213 of 2,213 rows identical |
| Step 02: trial file rebuilt from the raw recordings vs. the file the paper was analysed from | same shape, max absolute difference 0, identical codes and missing-value pattern |
| Step 03: 42 values from an earlier, independent run of the same analysis (`validation/baiconf_report_values.csv`) | 42 of 42 reproduced exactly (`output/reproduction_check.csv`; SKIP_RAW=1 run of 13 Nov 2026) |
| Repeat run | a second SKIP_RAW=1 run gave identical `numbers.tex` and LaTeX tables |

Notes:
- **Bug fixed in this package:** the original LaTeX Table 1 printed `5%` unescaped, so LaTeX dropped the rest of row R2. `R/03_analysis.R` now escapes it; no numbers change.
- **Additions for the IIMB version (13 Nov 2026):** section 13b of `R/03_analysis.R` adds bootstrap CIs and an age-adjusted fit for the variance decomposition (Table 6), block variance shares, landing-descriptor R², Spearman-Brown reliability, the PC3 check under relative-peak-force matching (Table 7) and counts used in the text. Figures are greyscale and named `Fig1_`-`Fig5_` as in the manuscript.
- `overleaf/` is the Overleaf-ready LaTeX source (pdfLaTeX + Biber) of the manuscript, title page, highlights and exhibits. `./check_format.sh --build` compiles it and checks it against the IIMB guidelines (54 checks).

## Manuscript exhibits and the files that produce them
| Manuscript | File written by `R/03_analysis.R` |
|---|---|
| Fig. 1 Mean curve and scree plot | `output/paper_figures/Fig1_mean_curve_scree.pdf` |
| Fig. 2 Reconstructions of PC1-PC4 (main analysis) | `output/paper_figures/Fig2_pc_reconstructions_main.pdf` |
| Fig. 3 Jump-height matched band and SD ratios | `output/paper_figures/Fig3_matched_band.pdf` |
| Fig. 4 Variance explained by the vendor metrics, age and body mass | `output/paper_figures/Fig4_variance_explained.pdf` |
| Fig. 5 Reconstructions under the 1-s landing window | `output/paper_figures/Fig5_pc_reconstructions_1s.pdf` |
| Tables 1-7 | `output/paper_tables_latex/tab1_qc.tex`, `tab2_descriptives.tex`, `tab3_components.tex`, `tab4_bands.tex`, `tab5_r2.tex`, `tab6_variance.tex`, `tab7_windows.tex` |
| Every number in the text | `output/paper_numbers/numbers.tex` (copied unchanged to `overleaf/numbers.tex`) |

EPS copies of the figures are in `output/paper_figures_eps/`. The Overleaf project lays the R tables out with `paper/build_scripts/mktab.py`; the numbers are not edited.

## Data and code availability
The R code and the de-identified trial-level file `data/cmj_trials_deidentified.csv` (833 trials; pseudonymous athlete, session and trial codes; age to 0.1 year; no names, dates or vendor identifiers) are in this folder. The raw force-time recordings, athlete profiles and the pseudonym key are held by PhysioQinesis / Performance Lab under a non-disclosure agreement and are not included. The manuscript's data statement says the same.

## Folder map
| Path | Contents |
|---|---|
| `raw/vald/` | Not included (NDA). To rerun steps 01-02, place the unmodified VALD export here: `<testId>.parquet` force recordings (1,000 or 500 Hz), `<testId>_trials.json`, `tests.csv`, `profiles.json`, `groups.json` |
| `raw/private_keys/` | Not included (identifiable). Pseudonym codebook and sport/sex mapping used by step 01 |
| `R/00_run_all.R` | Runner: steps 01–03 in order, writes `output/run_log.txt` |
| `R/01_build_test_list.R` | R port of the Python `athlete_table()` + de-identification: football tests with sex and age (0.1 y) → `data/interim/tests_coverage.csv` |
| `R/02_extract_trials_from_raw.R` | The paper's extraction script (paths changed only): raw recordings → `data/cmj_trials_deidentified.csv` (833 trials, 101-point take-off, 1-s landing and lowest-COM landing curves, vendor metrics, QC helpers) |
| `R/03_analysis.R` | The paper's single analysis script (`run_all.R`; output folders renamed; % fix): QC, body-weight and phase normalisation, PCA, interpretation, matched bands, regression, athlete-grouped CV, bootstrap, variance decomposition, figures, LaTeX tables, in-text numbers, reproduction check |
| `data/` | De-identified files: `cmj_trials_deidentified.csv` (input for `SKIP_RAW=1`) and `interim/` (written by steps 01–02) |
| `output/main_lowest_com/`, `output/sensitivity_1s/` | Tables (CSV), figures (PNG), intermediate curves for the main and 1-s landing analyses |
| `output/paper_figures/`, `output/paper_figures_eps/` | Manuscript Figures 1–5 (PDF, EPS, greyscale) |
| `output/paper_tables_latex/`, `output/paper_numbers/numbers.tex` | Manuscript Tables 1–7 and every in-text number |
| `output/reproduction_check.csv`, `run_log.txt`, `sessionInfo.txt` | Checks, console log, software versions |
| `validation/` | Reference files the run compares against (original de-identified trial file, Python coverage table, reference values from the earlier independent run) |
| `overleaf/`, `check_format.sh` | Overleaf project of the IIMB submission and its format checker |
| `paper/iimb_formatted/` | IIMB MR submission files: anonymised manuscript (DOCX, PDF), separate title page, exhibits file (tables + figures), highlights |
| `paper/original/` | Conference submission documents, for the authors' records (not part of the IIMB submission). The zip package also holds the LaTeX source of the authors' earlier manuscript draft; in the Git repository that draft is the top-level `paper/` folder |
| `paper/build_scripts/` | Scripts that convert the LaTeX source + `output/` into the IIMB files (`mktab.py` lays out the R tables; `flatten.py` + `build_docx.py` + `docxlib.py` make the DOCX files with pandoc 3.14, APA 7 CSL and python-docx; `overlap.py` is the n-gram overlap check; PDFs via pdfLaTeX/latexmk + Biber in TeX Live/TinyTeX; paths inside the scripts are absolute and must be edited) |

## Software
R 4.5.3 (conda-forge build) with dplyr 1.2.1, tidyr 1.3.2, ggplot2 4.0.3, patchwork 1.3.2, nlme 3.1.170, arrow 25.0.1, jsonlite 2.0.0 (`packages.csv`; full `sessionInfo()` in `output/sessionInfo.txt`). Figures use Arial via Cairo; without Arial, R substitutes a similar font (numbers are unaffected). Random steps (CV folds, one-trial draw, 2,000 athlete bootstraps) use `set.seed(2026)`.

## Licence
Code: MIT (`LICENSE`). Data and outputs: not MIT; review and reproduction only (`DATA_LICENSE.md`). Raw data: private, see warning above.
