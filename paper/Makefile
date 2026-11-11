# Build all manuscript variants with tectonic (https://tectonic-typesetting.github.io)
# Run `Rscript R/run_all.R` from the repository root first: it writes figures/, tables/, generated/ and submission_figures/.
SRC = preamble.tex title.tex title_authors.tex body.tex captions.tex references.bib generated/numbers.tex $(wildcard floats/*.tex tables/*.tex figures/*.pdf)
all: main.pdf main_submission.pdf main_anonymous.pdf title_page.pdf submission_figures/Fig1_pipeline.pdf
%.pdf: %.tex $(SRC)
	tectonic -X compile $<
# Figure 1 as a separate file for submission
submission_figures/Fig1_pipeline.pdf: floats/fig_pipeline_standalone.tex floats/pipeline_tikz.tex
	cd floats && tectonic -X compile fig_pipeline_standalone.tex && mv fig_pipeline_standalone.pdf ../submission_figures/Fig1_pipeline.pdf
	pdftops -eps submission_figures/Fig1_pipeline.pdf submission_figures/Fig1_pipeline.eps
clean:
	rm -f *.aux *.log *.bbl *.blg *.out *.fff *.ttt
