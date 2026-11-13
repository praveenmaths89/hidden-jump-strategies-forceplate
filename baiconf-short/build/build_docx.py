import subprocess, os
from docx import Document
from docx.enum.text import WD_BREAK, WD_ALIGN_PARAGRAPH
from flatten import O
from docxlib import style_doc, add_page_numbers, PD, OUT, booktabs, apa_captions
BIB = O + 'references.bib'
os.makedirs(OUT, exist_ok=True)
TITLE = 'Revealing hidden jump strategies beyond conventional force-plate metrics'
def pandoc(src, dst, cite=False):
    a = [PD, src, '-f', 'latex', '-t', 'docx', '-o', dst] + (['--number-sections'] if cite else [])
    if cite: a += ['--citeproc', '--bibliography=' + BIB, '--csl=apa.csl', '-M', 'reference-section-title=References']
    subprocess.run(a, check=True)
def brk(p): p.insert_paragraph_before('').add_run().add_break(WD_BREAK.PAGE)
pandoc('manuscript.tex', 'ms_raw.docx', cite=True)
d = Document('ms_raw.docx')
for p in d.paragraphs:
    t = p.text.strip()
    if t == TITLE: p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if p.style.name.startswith('Heading') and t in ('Introduction', 'References'): brk(p)
style_doc(d); booktabs(d); apa_captions(d); add_page_numbers(d)
d.core_properties.author = ''; d.core_properties.last_modified_by = ''; d.core_properties.title = TITLE
d.save(f'{OUT}/IIMB_BAICONF2026_SHORT_Manuscript_anonymised.docx')
pandoc('exhibits.tex', 'ex_raw.docx')
e = Document('ex_raw.docx'); style_doc(e, double=False); booktabs(e); apa_captions(e); add_page_numbers(e)
e.core_properties.author = ''; e.core_properties.last_modified_by = ''
e.save(f'{OUT}/IIMB_BAICONF2026_SHORT_Exhibits_Tables_Figures.docx')
for name, out in [('titlepage', 'Title_Page'), ('highlights', 'Highlights')]:
    pandoc(name + '.tex', name + '_raw.docx')
    t = Document(name + '_raw.docx'); style_doc(t, double=False)
    t.save(f'{OUT}/IIMB_BAICONF2026_SHORT_{out}.docx')
print('docx built')
