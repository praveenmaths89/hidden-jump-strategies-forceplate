Overleaf project: "Revealing hidden jump strategies beyond conventional force-plate metrics"
IIMB Management Review / BAICONF 2026 (submission BAI2575)

LOAD ON OVERLEAF
  1. Overleaf > New Project > Upload Project > choose IIMB_BAICONF2026_overleaf.zip.
  2. Menu > Compiler: pdfLaTeX. Menu > TeX Live version: 2023 or later. Biber runs automatically.
  3. Main document: main.tex (the default). To build another file, open it and click
     Menu > Main document, or use "Recompile" with that file selected as main.

FILES TO UPLOAD TO THE JOURNAL (each is its own main file)
  main.tex        Anonymised manuscript for double-anonymous review. Page 1 holds the front matter
                  in the IIMB order: title, short title, Abstract, Keywords, Extended summary.
                  The Introduction starts on page 2.
  titlepage.tex   COVER PAGE (title page): authors, affiliations, contact details, declarations,
                  data and code availability with the repository link. Not sent to reviewers.
  exhibits.tex    Separate exhibits file: Tables 1-7 and Figs 1-5, one per page.
  highlights.tex  Highlights (5 bullets, <= 85 characters). OPTIONAL: upload only if the
                  submission portal asks for highlights.

SHARED INPUTS (edit these, not the generated ones)
  preamble.tex    packages and layout (Times 12 pt, double spacing, A4, 1-inch margins)
  frontmatter.tex title and short title
  abstract.tex, summary.tex, body.tex, captions.tex   the text
  references.bib  APA 7 references (biblatex-apa)
  numbers.tex     every number in the text, written by the R pipeline - do not edit by hand
  tables/*.tex    Tables 1-7, generated from the R output (booktabs + siunitx); regenerate rather than edit
  figures/*.pdf   Figs 1-5 (greyscale), from the R pipeline

COMPILE LOCALLY (TeX Live 2023+)
  latexmk            builds all four PDFs (settings in latexmkrc)
  latexmk main.tex   builds one
  latexmk -c         removes auxiliary files

CHECK BEFORE SUBMITTING
  python3 check_format.py --build
  Runs the IIMB guideline checks (word limits, anonymity, fonts, references, DOIs, greyscale
  figures, table style, page fill, front-matter order, placeholders). Needs poppler-utils
  (pdftotext, pdftoppm, pdffonts) and Python 3 with Pillow; use --offline to skip DOI lookups.
  Overleaf cannot run it; run it on a local copy.

The only placeholder left is the ethics statement (bold, in brackets) in body.tex Section 3.1 and in
titlepage.tex. Fill both, then remove \ethics{...} (or make it plain) in preamble.tex.
