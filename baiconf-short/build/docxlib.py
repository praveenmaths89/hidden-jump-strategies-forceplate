import re, copy, subprocess, os
from docx import Document
from docx.shared import Pt, Inches
from docx.enum.text import WD_LINE_SPACING, WD_BREAK, WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
import os
HERE_ = os.path.dirname(os.path.abspath(__file__))
OUT = os.environ.get('DOCX_OUT', os.path.join(HERE_, 'out'))
PD = '/home/box/envs/pandoc/bin/pandoc'
BIB = '/workspace/hidden-jump-strategies-forceplate/paper/references.bib'

def style_doc(d, double=True):
    for st in d.styles:
        try:
            f = st.font
        except Exception:
            continue
        if f is None: continue
        f.name = 'Times New Roman'; f.size = Pt(12)
        try:
            st.element.rPr.rFonts.set(qn('w:eastAsia'), 'Times New Roman')
            st.element.rPr.rFonts.set(qn('w:cs'), 'Times New Roman')
        except Exception: pass
        if st.name.startswith('Heading'):
            f.bold = True; f.italic = st.name in ('Heading 2', 'Heading 3') and st.name == 'Heading 3'
            from docx.shared import RGBColor; f.color.rgb = RGBColor(0, 0, 0)
        try:
            pf = st.paragraph_format
            if st.type == 1:
                if double and st.name not in ('Compact', 'Table', 'Image Caption', 'Table Caption', 'Captioned Figure'):
                    pf.line_spacing_rule = WD_LINE_SPACING.DOUBLE
                pf.space_after = Pt(0) if double else Pt(6)
        except Exception: pass
    for p in d.paragraphs:
        for r in p.runs:
            r.font.name = 'Times New Roman'
            if r.font.size and r.font.size != Pt(12): r.font.size = Pt(12)
    for t in d.tables:
        tblPr = t._tbl.tblPr
        for el in tblPr.findall(qn('w:tblW')): tblPr.remove(el)
        w = tblPr.makeelement(qn('w:tblW'), {qn('w:w'): '5000', qn('w:type'): 'pct'}); tblPr.append(w)
        for el in tblPr.findall(qn('w:tblLayout')): tblPr.remove(el)
        grid = t._tbl.find(qn('w:tblGrid'))
        ws = []
        if grid is not None:
            n = len(grid); first = 3000 if n > 3 else int(9000 / max(n, 1))
            ws = [first] + [int((9000 - first) / max(n - 1, 1))] * (n - 1)
            for gc, wv in zip(grid, ws): gc.set(qn('w:w'), str(wv))
        lay = tblPr.makeelement(qn('w:tblLayout'), {qn('w:type'): 'fixed'}); tblPr.append(lay)
        for row in t.rows:
            for k, tc in enumerate(row._tr.findall(qn('w:tc'))):
                tcPr = tc.get_or_add_tcPr()
                for el in tcPr.findall(qn('w:tcW')): tcPr.remove(el)
                span = tcPr.find(qn('w:gridSpan')); sp = int(span.get(qn('w:val'))) if span is not None else 1
                if ws:
                    st = sum(len([1]) for _ in range(0)); 
                tcPr.insert(0, tcPr.makeelement(qn('w:tcW'), {qn('w:w'): '0', qn('w:type'): 'auto'}))
        for row in t.rows:
            for c in row.cells:
                for p in c.paragraphs:
                    p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.SINGLE
                    for r in p.runs: r.font.name = 'Times New Roman'; r.font.size = Pt(10)
    sec = d.sections[0]
    sec.page_height, sec.page_width = Inches(11.69), Inches(8.27)
    for s in d.sections:
        s.left_margin = s.right_margin = s.top_margin = s.bottom_margin = Inches(1)

def add_page_numbers(d):
    for s in d.sections:
        p = s.footer.paragraphs[0]; p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = p.add_run()
        for tag, txt in (('begin', None), (None, 'PAGE'), ('end', None)):
            if tag:
                e = r._r.makeelement(qn('w:fldChar'), {qn('w:fldCharType'): tag}); r._r.append(e)
            else:
                e = r._r.makeelement(qn('w:instrText'), {}); e.text = txt; r._r.append(e)

def para_before(anchor, text='', bold=False, italic=False, style=None, center=False):
    p = anchor.insert_paragraph_before('', style=style)
    if text:
        r = p.add_run(text); r.bold = bold; r.italic = italic
    if center: p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    return p

def rich_before(anchor, label, text):
    p = anchor.insert_paragraph_before('')
    r = p.add_run(label); r.bold = True
    p.add_run(text); return p



def _border(parent, tag, edges):
    for el in parent.findall(qn(tag)): parent.remove(el)
    b = parent.makeelement(qn(tag), {})
    for e, on in edges:
        x = b.makeelement(qn('w:' + e), {qn('w:val'): 'single' if on else 'nil', qn('w:sz'): str(on or 0), qn('w:space'): '0', qn('w:color'): '000000'})
        b.append(x)
    parent.append(b)

def booktabs(d):
    """Booktabs-equivalent borders: thick top and bottom rules, thin rule under the header; nothing else."""
    for t in d.tables:
        tblPr = t._tbl.tblPr
        for el in tblPr.findall(qn('w:tblStyle')): tblPr.remove(el)
        _border(tblPr, 'w:tblBorders', [('top', 12), ('left', 0), ('bottom', 12), ('right', 0), ('insideH', 0), ('insideV', 0)])
        rows = t.rows
        nh = sum(1 for r in rows if r._tr.trPr is not None and r._tr.trPr.find(qn('w:tblHeader')) is not None) or 1
        for i, r in enumerate(rows):
            for c in r.cells:
                tcPr = c._tc.get_or_add_tcPr()
                _border(tcPr, 'w:tcBorders', [('top', 0), ('left', 0), ('bottom', 6 if i == nh - 1 else 0), ('right', 0)])

def apa_captions(d):
    """APA 7 table captions: 'Table N' in bold on one line, the title in italics on the next."""
    import re as _re
    for p in d.paragraphs:
        m = _re.match(r'^(Table \d+)\.\s*(.*)$', p.text.strip())
        if m and ('Caption' in p.style.name or p.style.name.startswith('Table')):
            for r in list(p.runs): r._r.getparent().remove(r._r)
            a = p.add_run(m.group(1)); a.bold = True; a.italic = False
            a.add_break()
            b = p.add_run(m.group(2)); b.italic = True; b.bold = False
            p.paragraph_format.keep_with_next = True
