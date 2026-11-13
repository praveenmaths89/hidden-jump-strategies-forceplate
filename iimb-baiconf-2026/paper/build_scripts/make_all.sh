#!/bin/bash
# Rebuilds the IIMB-format manuscript files from the paper source + package outputs
set -e
cd /workspace/iimb-baiconf-2026/build
PKG=/workspace/iimb-baiconf-2026/package; SRC=/workspace/hidden-jump-strategies-forceplate/paper
PD=/home/box/envs/pandoc/bin/pandoc; BIB=$SRC/references.bib
rm -f fig/*; mkdir -p fig
for f in $PKG/output/paper_figures/*.pdf $SRC/submission_figures/Fig1_pipeline.pdf; do pdftoppm -png -r 300 -singlefile $f fig/$(basename $f .pdf); done
python3 prep.py $SRC $PKG/output/paper_numbers/numbers.tex $PWD/fig $PKG/output/paper_tables_latex
python3 front_tex.py
python3 build_docs.py
python3 - <<'PY'
s=open('manuscript_pre.tex').read()
s=s.replace('\\begin{document}\n','\\begin{document}\n'+open('front.tex').read()+'\n',1)
s=s.replace('\\subsection{Practical applications}','\\subsection{Practical and managerial implications}')
open('manuscript_pdf.tex','w').write(s)
e=open('exhibits_pre.tex').read(); open('exhibits_pdf.tex','w').write(e)
PY
OPTS=(-V mainfont=texgyretermes -V "mainfontoptions=Extension=.otf,UprightFont=*-regular,BoldFont=*-bold,ItalicFont=*-italic,BoldItalicFont=*-bolditalic" -V fontsize=12pt -V geometry:a4paper,margin=1in)
$PD manuscript_pdf.tex -f latex -t latex -s --citeproc --bibliography=$BIB --csl=/tmp/apa.csl -M reference-section-title=References "${OPTS[@]}" -V linestretch=2 -o ms_out.tex
sed -i 's/\\section{References}/\\clearpage\\section*{References}/' ms_out.tex
sed -i "s/^\\\\section{Introduction}/\\\\clearpage\\\\section{Introduction}/" ms_out.tex
$PD exhibits_pdf.tex -f latex -t latex -s "${OPTS[@]}" -o ex_out.tex
/home/box/.local/bin/tectonic -X compile ms_out.tex >/tmp/tect1.log 2>&1
/home/box/.local/bin/tectonic -X compile ex_out.tex >/tmp/tect2.log 2>&1
cd ..
cp build/ms_out.pdf IIMB_BAICONF2026_Manuscript_anonymised.pdf
cp build/ex_out.pdf IIMB_BAICONF2026_Exhibits_Tables_Figures.pdf
soffice --headless --convert-to pdf --outdir . IIMB_BAICONF2026_Title_Page.docx IIMB_BAICONF2026_Highlights.docx >/dev/null 2>&1
echo built-all
