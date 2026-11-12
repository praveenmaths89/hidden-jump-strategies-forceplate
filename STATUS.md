# STATUS — pickup note (12 November 2026)

**Paper:** *Same jump height, different jump: Principal component analysis of take-off and landing force–time curves
reveals movement strategies that conventional force-plate metrics do not capture* (Chougale & Ananthakumar)
**Venue:** *Sports Biomechanics* (Taylor & Francis), manuscript prepared, not submitted
**Repository:** https://github.com/praveenmaths89/hidden-jump-strategies-forceplate — **private** (keep private)
**Snapshot commit:** `9e561f3` (code, data, outputs and manuscript as of 12 Nov 2026; later commits only touch this note)

This is the force–time curve (PCA of CMJ take-off and landing curves) paper finished on 11 Nov 2026. It is not
any of the older FDA/JSHS folders on the box; do not merge those into this repository.

## What is in the repository
- `R/run_all.R` — single end-to-end pipeline (sections 0–16), about 10 s.
- `R/00_extract_from_raw_private.R` — record of the private extraction step (needs the raw export; not runnable here).
- `data/cmj_trials_deidentified.csv` — 833 male CMJ trials with pseudonymous athlete/session/trial codes.
- `outputs/main_lowest_com/`, `outputs/sensitivity_1s/`, `reproduction_check.csv` (42 BAICONF values), `reference_check.txt`, `run_log.txt`, `sessionInfo.txt`.
- `validation/baiconf_report_values.csv`, `tools/verify_references.py`, `tools/pii_scan.py`.
- `paper/` — T&F Interact LaTeX source, `main.pdf`, `main_submission.pdf`, `main_anonymous.pdf`, `title_page.pdf`,
  `figures/`, `submission_figures/` (EPS), `tables/`, `generated/numbers.tex`, `GUIDELINES_CHECKLIST.md`.
- `packages.csv`, `install_packages.R`, `LICENSE` (MIT, code), `DATA_LICENSE.md` (data/outputs).

## How to rebuild (from README)
```
Rscript install_packages.R
Rscript R/run_all.R               # all outputs, paper figures, tables and in-text numbers
cd paper && make                  # or ./build.sh; tectonic + pdftops; builds the four PDFs
python3 tools/verify_references.py   # optional
```

## Still open (`\todo` in the manuscript; to be filled by Praveen, no wording has been invented)
- [ ] Ethics committee, approval number, athlete consent and parental/guardian consent for those under 18 (or waiver), Declaration of Helsinki statement.
- [ ] Name or describe the centre/programme, testing period and data-sharing agreement.
- [ ] Protocol details: warm-up, instructions (arm position, landing), trials requested, rest, trial-acceptance criteria.
- [ ] Status of the BAICONF 2026 conference paper (accepted/presented/published) and whether to tell the journal in the cover letter.
- [ ] Acknowledgements; competing interests (`\todo{confirm}`); funding source or no-funding statement.
- [ ] Data availability: repository URL or DOI (two places), data owner and terms for raw-data requests.
- [ ] Generative-AI use declaration (suggested wording is in the `\todo`, still to be confirmed).
- [ ] Usha Ananthakumar's ORCID; CRediT contributions to be confirmed (`title_page.tex`).

## Related but separate
- BAICONF 2026 (IIM Bangalore, abstract BAI2575): a full-paper extension was requested to Fri 13 Nov 2026. That
  IIMB-format conference version is a separate, earlier folder on the box and is **not** this repository; this repo is
  the *Sports Biomechanics* journal version.

## Never commit
- The raw VALD export (parquet recordings, `*_trials.json`, `tests.csv`, `profiles.json`), the code key / codebook, `.env` files,
  `outputs/*/intermediate/`, LaTeX aux/log files (all covered by `.gitignore`).

## Cited papers
- `papers/` holds legally available copies (open access, preprints, accepted manuscripts, official manuals) of the works cited in the paper. `papers/README.md` lists every cited work with its DOI, what version is stored, and why any item is link-only (paywalled or a book).
