Overleaf project: "Revealing hidden jump strategies beyond conventional force-plate metrics"
IIMB Management Review / BAICONF 2026 (BAI2575). Upload this zip to Overleaf (New Project > Upload Project).
Compiler: pdfLaTeX (Menu > Settings). Bibliography: biblatex-apa (APA 7) with Biber, run automatically.
  main.tex        anonymised manuscript for double-anonymous review (set as Main document)
  titlepage.tex   separate title page (authors, affiliations, declarations) - not sent to reviewers
  highlights.tex  highlights (5 bullets, <= 85 characters each)
  exhibits.tex    separate exhibits file (Tables 1-7, Figs 1-5)
  numbers.tex     every number in the text, written by the R pipeline (do not edit by hand)
  tables/*.tex    table bodies from the R pipeline, laid out to fit the text width
  figures/*.pdf   Figs 1-5 from the R pipeline
  check_format.py format checker (IIMB guidelines + house rules); run "python3 check_format.py --build"
                  after editing. It needs poppler (pdftotext, pdftoppm, pdffonts) and Python 3 with Pillow.
