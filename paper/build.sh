#!/usr/bin/env bash
# Build every manuscript variant with tectonic (same as `make` where make is available).
# Run `Rscript R/run_all.R` from the repository root first.
set -euo pipefail
cd "$(dirname "$0")"
for f in main main_submission main_anonymous title_page; do tectonic -X compile "$f.tex"; done
(cd floats && tectonic -X compile fig_pipeline_standalone.tex && mv fig_pipeline_standalone.pdf ../submission_figures/Fig1_pipeline.pdf)
pdftops -eps submission_figures/Fig1_pipeline.pdf submission_figures/Fig1_pipeline.eps
