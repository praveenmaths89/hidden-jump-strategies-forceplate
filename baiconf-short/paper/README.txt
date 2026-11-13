Overleaf project: "Revealing hidden jump strategies beyond conventional force-plate metrics"
IIMB Management Review / BAICONF 2026 (submission BAI2575), short full-paper version

LOAD ON OVERLEAF
  1. Overleaf > New Project > Upload Project > choose IIMB_BAICONF2026_SHORT_overleaf.zip.
  2. Menu > Compiler: pdfLaTeX. Menu > TeX Live version: 2023 or later. Biber runs automatically.
  3. Main document: main.tex (the default). To build another file, open it and choose it as
     Menu > Main document.

FILES TO UPLOAD TO THE JOURNAL (each is its own main file)
  main.tex        Anonymised manuscript for double-anonymous review. Page 1 holds the front matter
                  in the IIMB order: title, short title, Abstract, Keywords, Extended summary.
                  The Introduction starts on page 2. Sections: 1 Introduction, 2 Literature review,
                  3 Methodology, 4 Findings, 5 Conclusion and implications, References.
  titlepage.tex   Title page: authors, affiliations, contact details, declarations, data and code
                  availability with the repository link. Not sent to reviewers.
  exhibits.tex    Separate exhibits file: Tables 1-4 and Figs 1-4, one per page.
  highlights.tex  Highlights (4 bullets, <= 85 characters). Optional.

SHARED INPUTS
  preamble.tex    packages and layout (Times 12 pt, double spacing, A4, 1-inch margins)
  frontmatter.tex title and short title
  abstract.tex, summary.tex, body.tex, captions.tex   the text
  references.bib  APA 7 references (biblatex-apa); only cited works, every DOI checked at doi.org
  numbers_fda.tex every number in the text, written by explore_fda/make_paper_outputs.R - do not edit
  tables/*.tex    Tables 1-4, written by the same script (booktabs + siunitx)
  figures/*.pdf   Figs 1-4 (greyscale), written by the same script

REBUILD THE NUMBERS, TABLES AND FIGURES
  cd ../explore_fda && Rscript run_all.R        (R 4.5; seed 2026; about 30 minutes)

COMPILE LOCALLY (TeX Live 2023+)
  latexmk            builds all four PDFs (settings in latexmkrc)
  latexmk -c         removes auxiliary files

CHECK BEFORE SUBMITTING
  python3 check_format.py --build
  Runs the IIMB checks (body <= 4,500 words, section order, abstract/summary limits, anonymity,
  fonts, references, DOIs, greyscale figures, table style, page fill, front-matter order,
  placeholders, wording). Needs poppler-utils and Python 3 with Pillow; --offline skips DOI lookups.

The only placeholder left is the ethics statement (bold, in brackets) in body.tex Section 3.1 and in
titlepage.tex. Fill both, then make \ethics{...} plain in preamble.tex.
