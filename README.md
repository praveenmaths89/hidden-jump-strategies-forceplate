# Hidden jump strategies beyond conventional force-plate metrics

Code, de-identified data, outputs and the *Sports Biomechanics* manuscript (LaTeX) for:

> Chougale, P., & Ananthakumar, U. *Same jump height, different jump: Principal component analysis of take-off and landing force–time curves reveals movement strategies that conventional force-plate metrics do not capture.* Manuscript prepared for *Sports Biomechanics*.

This repository **extends the BAICONF 2026 submission** (IIM Bangalore, submission BAI2575, *Revealing Hidden Jump Strategies Beyond Conventional Force-Plate Metrics*). It turns the conference analysis into a journal article and replaces the earlier set of scripts with one end-to-end R script.

## IIMB Management Review / BAICONF 2026 paper (branch `iimb-baiconf-2026`)
The folder [`iimb-baiconf-2026/`](iimb-baiconf-2026/) holds the code, de-identified data, outputs and LaTeX source of the paper *Revealing hidden jump strategies beyond conventional force-plate metrics* (IIMB Management Review). To reproduce every table, figure and in-text number from the de-identified data:

```bash
cd iimb-baiconf-2026
Rscript install_packages.R          # once
SKIP_RAW=1 Rscript R/00_run_all.R   # about 8-9 minutes
```
See [`iimb-baiconf-2026/README.md`](iimb-baiconf-2026/README.md) for the folder map and the mapping from manuscript Figures 1-5 and Tables 1-7 to output files. The raw force-time recordings are held by PhysioQinesis / Performance Lab under a non-disclosure agreement and are not in this repository.

## Aim
Do countermovement jumps (CMJ) with similar conventional force-plate scores share the same force–time curve? How much of the curve-shape variation do those scores leave unexplained? Each trial's take-off phase (movement onset to take-off) and landing phase (touch-down to the lowest point of the centre of mass) are normalised to body weight. Each phase is time-normalised to 101 points, and the two are joined end to end with flight left out. The curves are analysed with PCA. There are three aims:

1. Find the modes of variation.
2. Compare score dispersion among trials matched on jump height or relative peak force with dispersion in the full sample.
3. Estimate how much of each component the four vendor metrics, age and body mass explain. This is checked in-sample, with athlete-grouped CV, with one trial per athlete and with athlete means.

Two further analyses were added for the journal version:
- a variance decomposition across athlete, session and trial levels;
- landing duration as an interpretive descriptor.

The landing-window definition is tested in a sensitivity analysis that ends the landing 1 s after touch-down.

## Repository layout
| Path | Contents |
|---|---|
| `R/00_extract_from_raw_private.R` | Record of the private extraction step (raw VALD export -> de-identified trial file); not runnable without the private data |
| `R/run_all.R` | **The single end-to-end pipeline** (sections 0-16: setup, load, QC, normalisation, PCA, interpretation, matched bands, regression, robustness, variance decomposition, descriptives, figures, reproduction check, manuscript figures, LaTeX tables, in-text numbers, software record) |
| `data/cmj_trials_deidentified.csv` | 833 male football CMJ trials, before QC. Pseudonymous `athlete`, `test_code` (session) and `trial_code`; age (0.1 y), body mass, sampling rate, vendor metrics, QC helpers and 101-point force curves in N (`to_*` take-off, `ld_*` landing to touch-down + 1 s, `ldc_*` landing to lowest COM) |
| `outputs/main_lowest_com/` | Main analysis: tables (CSV, including de-identified PC scores) and figures (PNG) |
| `outputs/sensitivity_1s/` | The same outputs for the 1-s landing window |
| `outputs/reproduction_check.csv` | 42 numbers from an earlier, independent run of the same analysis next to this run's values |
| `outputs/reference_check.txt` | Crossref verification of every reference (`tools/verify_references.py`) |
| `outputs/run_log.txt`, `outputs/sessionInfo.txt`, `packages.csv` | Console log, full `sessionInfo()` and package versions |
| `validation/baiconf_report_values.csv` | Values printed in the BAICONF report, used by the reproduction check |
| `paper/` | LaTeX manuscript (T&F Interact class, T&F APA references via `tfapacite.bst`). It contains `main.pdf` (reading version, floats in the text) and `main_submission.pdf` (journal order: tables on separate pages, then figures, then a list of figure captions). It also has `main_anonymous.pdf` with `title_page.pdf` for double-anonymous review, and `GUIDELINES_CHECKLIST.md` (the 9 Nov 2026 *Sports Biomechanics* instructions, checked point by point) |
| `paper/figures/`, `paper/tables/`, `paper/generated/numbers.tex` | Vector figures, LaTeX tables and every in-text number as a LaTeX macro. All are written by `R/run_all.R`, and nothing is typed by hand |
| `paper/submission_figures/` | Separate figure files for submission (EPS; Figure 1 also PDF) |

## How to run
Requirements: R 4.5.3 (used here; any recent R ≥ 4.3 should work) with dplyr, tidyr, ggplot2, patchwork and nlme. Exact versions are in `packages.csv`. The figures use the Arial font through Cairo. For the paper you also need [tectonic](https://tectonic-typesetting.github.io) and `pdftops` (poppler).

```bash
Rscript install_packages.R      # once
Rscript R/run_all.R             # about 10 s: all outputs, paper figures, tables and numbers
cd paper && make                # or ./build.sh : builds the four PDFs and the Figure 1 files
python3 tools/verify_references.py   # optional: re-check every DOI against Crossref
```

The only random steps are the CV folds, the one-trial-per-athlete draw and the 2,000-sample athlete bootstrap. They run in a fixed order after `set.seed(2026)`.

The de-identified trial file was built from the private raw VALD export by the extraction script of the BAICONF analysis; a copy is kept here as `R/00_extract_from_raw_private.R` for the record. It needs the raw recordings and the code key (`RAW_ROOT`), which are not in this repository, so it cannot be run from here and is not part of the pipeline. Everyone else starts at `R/run_all.R` with `data/cmj_trials_deidentified.csv`.

## Reproduction of the BAICONF 2026 analysis
`R/run_all.R` reproduces all 42 values checked against the delivered BAICONF analysis report, exactly at the printed precision (`outputs/reproduction_check.csv`). Every table of the earlier multi-script analysis was also compared at full precision, for both landing windows, and the maximum absolute difference was 0.

The changes are additions only:
- a `sessions` column in the QC table;
- descriptive rows for landing duration, trials per session and sessions per athlete;
- landing duration as a correlation descriptor;
- the variance decomposition (`R5_variance_decomposition.csv`).

Adding landing duration changes one interpretation. The strongest correlate of PC1 is landing duration (r = −0.75), not peak landing force (r = 0.39), which was the strongest among the earlier descriptors.

The manuscripts report only the numbers produced by this script.

## Data and privacy
- Only de-identified data are included. Athletes, sessions and trials are pseudonymous codes. There are no names, team names, VALD profile, test or trial IDs, emails, dates of birth or test dates; age is given at test, rounded to 0.1 year.
- The raw VALD export and the key from codes to athletes are private and are not in this repository.
- Many athletes were minors. Ethics approval and consent details are being added to the manuscripts by the authors.
- Before the first push, a PII scan checked every committed file against tokens from the private profile files (names, VALD IDs, emails, dates of birth) and against generic e-mail, UUID and date patterns. No matches were found.

## Licence
Code: MIT (`LICENSE`). The data and outputs are **not** MIT-licensed. They are shared for review and reproduction only (`DATA_LICENSE.md`).
