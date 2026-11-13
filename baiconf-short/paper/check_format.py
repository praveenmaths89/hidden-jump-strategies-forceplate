#!/usr/bin/env python3
"""Format checker for the IIMB Management Review / BAICONF 2026 short paper (BAI2575, branch baiconf-short).

Checks the compiled Overleaf project against the IIMB "Guidelines for Contributors"
checklist (reviews/template_language_review.md, section 3) plus the authors' own rules.

Usage (from the Overleaf folder, after compiling main, titlepage, highlights, exhibits):
    python3 check_format.py            # check existing PDFs and logs
    python3 check_format.py --build    # run latexmk on the four documents first
    python3 check_format.py --offline  # skip the DOI resolution check (no network)
Needs: pdftotext and pdftoppm (poppler), Python 3 with Pillow; latexmk for --build.
Exit code 0 when every check passes, 1 otherwise.

Rule table (rule -> what enforces it):
  no author/centre/repo identifiers in the blinded PDFs  -> check 2
  no colour figures or colour words in captions          -> check 5
  DOIs printed as https://doi.org/... and resolvable     -> check 6
  only the ethics placeholder may remain                 -> check 9
  no mention of the conference abstract (decision M5)    -> check 10
  no stock AI phrasing, em dashes, "trial-specific"      -> check 10
  body (Introduction to Conclusion) <= 4,500 words       -> check 1b
  sections exactly: Introduction, Literature review, Methodology, Findings,
  Conclusion and implications, then References            -> check 1c
"""
import os, re, subprocess, sys, glob, json, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__)); os.chdir(HERE)
DOCS = ['main', 'titlepage', 'highlights', 'exhibits']
results = []

def check(name, ok, detail=''):
    results.append(ok); print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" -- {detail}" if detail else ''))

def pdftext(pdf, layout=False):
    return subprocess.run(['pdftotext'] + (['-layout'] if layout else []) + [pdf, '-'], capture_output=True, text=True, check=True).stdout

def strip_lineno(t):
    # lineno prints left-margin numbers; drop lines that are only a number and leading numbers
    out = []
    for l in t.split('\n'):
        if re.fullmatch(r'\s*\d+\s*', l): continue
        out.append(re.sub(r'^\s*\d{1,4}\s+(?=\S)', '', l))
    return '\n'.join(out)

words = lambda s: len([w for w in s.split() if re.search(r'[A-Za-z0-9]', w)])
rd = lambda p: open(p, encoding='utf8').read()

if '--build' in sys.argv:
    env = dict(os.environ); env['PATH'] = '/home/box/.TinyTeX/bin/x86_64-linux:' + env['PATH']
    for d in DOCS:
        subprocess.run(['latexmk', '-pdf', '-interaction=nonstopmode', d + '.tex'], env=env, capture_output=True)

for d in DOCS:
    check(f'{d}.pdf exists', os.path.exists(d + '.pdf'))
if not all(results): sys.exit(1)

main = strip_lineno(pdftext('main.pdf'))
pre, refs = main.split('\nReferences\n', 1) if '\nReferences\n' in main else (main, '')

# 1. Word counts
ab = pre.split('Abstract', 1)[1].split('Keywords:')[0]
check('Abstract <= 100 words', words(ab) <= 100, f'{words(ab)} words')
check('Abstract has no citations', not re.search(r'\(\w[^)]*\d{4}\)', ab))
kw = pre.split('Keywords:', 1)[1].split('\n\n')[0].split('Extended summary')[0]
kws = [k.strip() for k in kw.replace('\n', ' ').split(';') if k.strip()]
check('Keywords <= 8', len(kws) <= 8, f'{len(kws)}: ' + '; '.join(kws))
es = pre.split('Extended summary', 1)[1].split('\n1\nIntroduction')[0].split('\nIntroduction\n')[0]
es = re.sub(r'\n\d+\n', '\n', es)
check('Extended summary <= 300 words', words(es) <= 300, f'{words(es)} words')
st = re.search(r'\\newcommand\{\\shorttitle\}\{([^}]*)\}', rd('frontmatter.tex')).group(1)
check('Short title <= 5 words', len(st.split()) <= 5, f'"{st}" ({len(st.split())} words)')
pre_nopg = re.sub(r'\n\d+\n', '\n', pre)
check('Manuscript <= 8,000 words excluding references', words(pre_nopg) <= 8000,
      f'{words(pre_nopg)} excl. references (title, abstract, summary, text, tables, captions, declarations); {words(pre_nopg) + words(refs)} incl. references')

# 1b. Body word count (Introduction to the end of Conclusion), counted from the source: tables,
#     figures, captions, equations, comments and LaTeX markup are excluded; each number macro counts
#     as one word; each cited work is counted as three words (APA "Author et al., year").
def body_words(t):
    t = re.sub(r'(?<!\\)%.*$', '', t, flags=re.M)
    t = re.sub(r'\\begin\{(figure|table|equation)\*?\}.*?\\end\{\1\*?\}', ' ', t, flags=re.S)
    t = re.sub(r'\\input\{[^}]*\}', ' ', t)
    ncit = sum(len(m.split(',')) for m in re.findall(r'\\(?:paren|text)?cite\w*\{([^}]*)\}', t))
    t = re.sub(r'\\(?:paren|text)?cite\w*\{[^}]*\}', ' ', t)
    t = re.sub(r'\\(?:ref|eqref|label)\{[^}]*\}', lambda m: ' X ' if 'ref' in m.group(0)[:5] else ' ', t)
    t = re.sub(r'\$[^$]*\$', ' X ', t)
    t = re.sub(r'\\(section|subsection)\*?\{[^}]*\}', ' ', t)
    t = re.sub(r'\\[A-Za-z]+(\{\})?', ' X ', t)
    t = re.sub(r'[{}~]', ' ', t)
    return words(t), ncit
body_src = rd('body.tex')
secs = re.split(r'(?=\\section\{)', body_src)
tot = tot_c = 0; parts = []
for sct in secs:
    m = re.match(r'\\section\{([^}]*)\}', sct)
    if not m: continue
    w, c = body_words(sct); tot += w; tot_c += c; parts.append(f'{m.group(1)} {w}+{3*c}')
check('Body (Introduction to Conclusion) <= 4,500 words', tot + 3 * tot_c <= 4500,
      f'{tot + 3 * tot_c} words incl. citations ({tot} excl. {tot_c} citations); ' + '; '.join(parts))
# 1c. Exact section order
SECS = ['Introduction', 'Literature review', 'Methodology', 'Findings', 'Conclusion and implications']
got = re.findall(r'\\section\{([^}]*)\}', body_src)
mt = rd('main.tex'); lay = pdftext('main.pdf', layout=True)
check('Sections exactly: 1 Introduction, 2 Literature review, 3 Methodology, 4 Findings, 5 Conclusion and implications, then References',
      got == SECS and mt.find('\\input{body}') < mt.find('\\printbibliography') and not re.search(r'\\section\{', mt) and
      [m.start() for m in [re.search(rf'^\s*(\d+\s+)?{i}\s+{re.escape(n)}\s*$', lay, re.M) for i, n in enumerate(SECS, 1)] if m] == sorted(m.start() for m in [re.search(rf'^\s*(\d+\s+)?{i}\s+{re.escape(n)}\s*$', lay, re.M) for i, n in enumerate(SECS, 1)] if m) and all(re.search(rf'^\s*(\d+\s+)?{i}\s+{re.escape(n)}\s*$', lay, re.M) for i, n in enumerate(SECS, 1)) and re.search(r'^\s*References\s*$', lay, re.M) is not None,
      ' | '.join(got))

# 2. Anonymity of the blinded files
BAN = r'Chougale|Praveen|Ananthakumar|Usha\b|IIT Bombay|Indian Institute of Technology|Koita|SJMSOM|Shailesh|PhysioQinesis|Performance Lab|github|praveenmaths|@gmail|@som\.|ORCID|0000-000\d|BAI2575'
for pdf in ['main.pdf', 'exhibits.pdf']:
    hits = sorted(set(re.findall(BAN, pdftext(pdf), re.I)))
    check(f'{pdf}: no author, centre, URL or repository identifiers', not hits, ', '.join(hits))
    info = subprocess.run(['pdfinfo', pdf], capture_output=True, text=True).stdout
    au = re.search(r'^Author:[ \t]*(.*)$', info, re.M)
    check(f'{pdf}: PDF Author metadata empty', not (au and au.group(1).strip()), au.group(1) if au else '')
tp = re.sub(r'\s+', '', pdftext('titlepage.pdf'))  # URLs break across lines; xurl breaks show up as spaces in pdftotext
check('Title page gives the full repository URL, branch, folder and run command',
      all(k in tp for k in ['github.com/praveenmaths89/hidden-jump-strategies-forceplate', 'baiconf-short', 'run_all.R', 'explore_fda']))
check('Blinded manuscript has the withheld-link data statement', 'link withheld for blind review' in pre.replace('\n', ' '))

# 3. Typography in the LaTeX source
pr = rd('preamble.tex') + rd('main.tex')
check('12 pt document class', re.search(r'\\documentclass\[[^\]]*12pt', rd('main.tex')) is not None)
check('Times font (newtx or times/mathptmx)', re.search(r'\\usepackage(\[[^\]]*\])?\{[^}]*\b(newtxtext|times|mathptmx)\b', pr) is not None)
check('Double spacing', '\\doublespacing' in pr or re.search(r'\\setstretch\{2', pr) is not None)
fs = subprocess.run(['pdffonts', 'main.pdf'], capture_output=True, text=True).stdout
check('Body font embedded is a Times face', re.search(r'Times|Termes|NimbusRom|TeXGyreTermes|txr', fs, re.I) is not None)

# 4. Logs: boxes, unresolved references and citations
for d in DOCS:
    lg = rd(d + '.log')
    ob = len(re.findall(r'^Overfull \\[hv]box', lg, re.M)); ub = len(re.findall(r'^Underfull \\[hv]box', lg, re.M))
    check(f'{d}.log: 0 overfull and 0 underfull boxes', ob == 0 and ub == 0, f'overfull {ob}, underfull {ub}')
    und = re.findall(r'(Reference|Citation) [`\'"]?([^\'" ]+)[\'"]? .*undefined', lg) + re.findall(r'There were undefined references', lg)
    check(f'{d}.log: every \\ref and \\cite resolved', not und, str(und[:5]))
    if os.path.exists(d + '.blg'):
        bw = [l for l in re.findall(r'^.*(?:WARN|ERROR) - .*$', rd(d + '.blg'), re.M) if 'does not contain any citations' not in l]
        check(f'{d}.blg: no Biber warnings or errors', not bw, '; '.join(bw[:3]))
alltxt = ''.join(pdftext(d + '.pdf') for d in DOCS)
check('No "??" (unresolved reference) in any PDF', '??' not in alltxt)
cited = set(k for m in re.findall(r'\\(?:paren|text)?cite\w*\{([^}]*)\}', rd('body.tex') + rd('summary.tex') + rd('abstract.tex')) for k in m.split(','))
bibkeys = set(re.findall(r'@\w+\{([^,]+),', rd('references.bib')))
check('Every cited key is in references.bib', cited <= bibkeys, ', '.join(sorted(cited - bibkeys)))

# 5. Exhibits: numbering, greyscale figures, captions, table fonts, placement
lab = lambda pat: re.findall(pat, rd('body.tex'))
tabs = [re.search(r'\\label\{([^}]+)\}', rd(f'tables/{t}.tex')).group(1) for t in lab(r'\\input\{tables/([^}]+)\}')]
firstref = []
for m in re.finditer(r'\\ref\{((?:tab|fig):[^}]+)\}', rd('body.tex')):
    if m.group(1) not in firstref: firstref.append(m.group(1))
check('Tables cited in order of first mention', [r for r in firstref if r.startswith('tab:')] == tabs, ' '.join(tabs))
figs = lab(r'\\label\{(fig:[^}]+)\}')
check('Figures cited in order of first mention', [r for r in firstref if r.startswith('fig:')] == figs, ' '.join(figs))
from PIL import Image, ImageChops
for f in sorted(glob.glob('figures/*.pdf')):
    subprocess.run(['pdftoppm', '-r', '60', '-png', '-singlefile', f, '/tmp/_cf'], check=True)
    r, g, bl = Image.open('/tmp/_cf.png').convert('RGB').split()
    sat = max(ImageChops.difference(x, y).getextrema()[1] for x, y in ((r, g), (g, bl), (r, bl)))
    check(f'{os.path.basename(f)} is greyscale', sat <= 12, f'max channel spread {sat}/255')
cap = rd('captions.tex')
cw = re.findall(r'\b(colou?r\w*|red|blue|green|orange|vermill?ion|purple|yellow)\b', re.sub(r'^%.*$', '', cap, flags=re.M), re.I)
check('Captions do not mention colours', not cw, ', '.join(cw))
small = []
for t in glob.glob('tables/*.tex'):
    s = rd(t)
    if re.search(r'\\(scriptsize|tiny)\b|\\resizebox|\\scalebox|adjustbox', s): small.append(os.path.basename(t))
check('Table text >= 9 pt (only \\small or \\footnotesize in a 12 pt document: 10.95 / 10 pt)', not small, ', '.join(small))
b = rd('body.tex')
bad = [m.group(1) for m in re.finditer(r'(?<!\n\n)\\input\{tables/([^}]+)\}', b)] + \
      [m.group(1) for m in re.finditer(r'\\input\{tables/([^}]+)\}(?!\n\n)', b)]
nonH = [t for t in glob.glob('tables/*.tex') if not re.search(r'\\begin\{table\}\[!?htb?p\]', rd(t))]
nonHf = len(re.findall(r'\\begin\{figure\}(?!\[!?htb?p\])', b))
check('Tables and figures are floats placed between paragraphs ([!htbp]; placeins keeps them in their section)', not bad and not nonH and nonHf == 0 and 'placeins' in rd('preamble.tex'),
      f'not between paragraphs: {bad}; tables not [!htbp]: {nonH}; figures not [!htbp]: {nonHf}')
vr = [os.path.basename(t) for t in glob.glob('tables/*.tex') if re.search(r'\\begin\{tabular\*?\}(\{[^}]*\})?\{[^}]*\|', rd(t)) or '\\hline' in rd(t)]
nobt = [os.path.basename(t) for t in glob.glob('tables/*.tex') if not all(k in rd(t) for k in ['\\toprule', '\\midrule', '\\bottomrule', 'tablenotes'])]
check('Tables use booktabs rules and notes below, with no vertical rules or \\hline', not vr and not nobt, f'vertical/hline: {vr}; missing booktabs/notes: {nobt}')
ci_old = [os.path.basename(t) for t in glob.glob('tables/*.tex') if re.search(r'\(\d[\d.]*--\d[\d.]*\)', rd(t))]
check('Table CIs written as [a, b]', not ci_old, ', '.join(ci_old))

# 6. References: APA DOI form and resolution
dois = re.findall(r'doi\s*=\s*\{([^}]*)\}', rd('references.bib'), re.I)
reftxt = re.sub(r'\s+', '', refs.replace('-\n', '-'))
missing = [d for d in dois if ('https://doi.org/' + d).replace(' ', '') not in reftxt]
check('Every DOI printed as https://doi.org/<doi>, unbroken', not missing, f'{len(dois)} DOIs; missing/broken: {missing[:5]}')
check('No spaced or truncated DOI strings', not re.search(r'https\s+:\s*/|doi\s+\.\s+org', refs))
check('Reference list says "ggplot2" (not "Ggplot2")', 'Ggplot2' not in refs)
if '--offline' not in sys.argv:
    def res(d):
        try:
            r = json.load(urllib.request.urlopen('https://doi.org/api/handles/' + urllib.request.quote(d, safe='/'), timeout=20))
            return d, r.get('responseCode') == 1
        except Exception as e:
            return d, False
    with ThreadPoolExecutor(8) as ex: rs = list(ex.map(res, dois))
    bad = [d for d, ok in rs if not ok]
    check('Every DOI resolves at doi.org', not bad, f'{len(dois) - len(bad)}/{len(dois)} resolve; failing: {bad}')

# 7. British spelling in the authors' text (cited titles in the .bib are left as published)
US = r'\b(behavior\w*|colors?|colored|center(s|ed)?|analyz\w+|normaliz\w+|organization\w*|modeling|modeled|summariz\w+|labeled|labeling|favor\w*|fiber\w*|optimiz\w+|characteriz\w+|recogniz\w+|utiliz\w+|randomiz\w+|standardiz\w+|minimiz\w+|maximiz\w+|emphasiz\w+|programs?|meters?|gray|defense|licensed?)\b'
text = ' '.join(rd(f) for f in ['abstract.tex', 'summary.tex', 'body.tex', 'captions.tex', 'highlights.tex', 'titlepage.tex', 'main.tex'] + glob.glob('tables/*.tex'))
text = re.sub(r'\\(?:paren|text)?cite\{[^}]*\}|\\url\{[^}]*\}|\\texttt\{[^}]*\}', '', text)
text = re.sub(r'\\(?:begin|end)\{[^}]*\}|\\[A-Za-z]+|^%.*$', '', text, flags=re.M)  # LaTeX names such as {center}
us = sorted(set(m.group(0) for m in re.finditer(US, text, re.I)))
check('British spelling (no US forms in the authors\' text)', not us, ', '.join(us))

# 8. Highlights
hl = [l.strip()[1:].strip() for l in pdftext('highlights.pdf').split('\n') if l.strip().startswith('•')]
check('Highlights: 3-5 bullets, each <= 85 characters', 3 <= len(hl) <= 5 and all(len(h) <= 85 for h in hl), ', '.join(str(len(h)) for h in hl))

# 9. Placeholders: only the ethics statement may remain
ALLOWED = ['Ethics committee name, approval number and date to be inserted', 'Written informed consent was obtained',
           'The committee waived the requirement', 'Delete the option that does not apply', 'Consent / assent wording as in Section 3.1']
ph = []
for d in DOCS:
    t = re.sub(r'\s+', ' ', strip_lineno(pdftext(d + '.pdf')))
    for m in re.finditer(r'\[([^\]\[]{4,400})\]', t):
        inner = m.group(1)
        if re.search(r'[A-Za-z]{3,}\s+[A-Za-z]{3,}', inner) and not any(a in inner for a in ALLOWED) and 'Computer software' not in inner:
            ph.append(f'{d}: [{inner[:60]}]')
    for k in ['TODO', 'TBD', 'XXX', 'AUTHORS TO COMPLETE', 'INSERT']:
        if k in t: ph.append(f'{d}: {k}')
check('No placeholders except the ethics statement', not ph, '; '.join(ph[:5]))
eth = 'Ethics committee name, approval number and date to be inserted'
check('Ethics placeholder still present (to be filled by the authors)', eth in re.sub(r'\s+', ' ', strip_lineno(pdftext('main.pdf'))) and eth.split(',')[0] in pdftext('titlepage.pdf'),
      'informational: fails once filled; then delete this check')

# 11. Page fill: no page of the manuscript is more than 25% empty, except a page that ends a
#     section (the next page opens with a section heading), the front-matter page and the last page.
def page_gaps(pdf, dpi=40):
    import tempfile
    tmp = tempfile.mkdtemp()
    subprocess.run(['pdftoppm', '-r', str(dpi), '-gray', '-png', pdf, tmp + '/p'], check=True)
    out = []
    for fpath in sorted(glob.glob(tmp + '/p-*.png')):
        im = Image.open(fpath).convert('L'); w, h = im.size
        top, bot = int(h * 0.09), int(h * 0.90)          # text block inside 1-in margins, above the page number
        box = im.crop((int(w * 0.10), top, int(w * 0.90), bot))
        dark = [y for y in range(box.size[1]) if box.crop((0, y, box.size[0], y + 1)).getextrema()[0] < 160]
        out.append(1.0 if not dark else (box.size[1] - 1 - dark[-1]) / box.size[1])
    return out
HEAD = r'^\s*(\d+\s+)?(\d\s+)?(Introduction|Literature review|Methodology|Findings|Conclusion and implications|Declarations|References)\b'
gaps = page_gaps('main.pdf'); npg = len(gaps); bad = []
for i, gp in enumerate(gaps, 1):
    if gp <= 0.25 or i in (1, npg): continue
    nxt = subprocess.run(['pdftotext', '-f', str(i + 1), '-l', str(i + 1), 'main.pdf', '-'], capture_output=True, text=True).stdout
    first = [l for l in nxt.split('\n') if l.strip()][:3]
    if any(re.match(HEAD, l) for l in first): continue
    bad.append(f'p.{i} {gp:.0%} empty')
check('No manuscript page more than 25% empty (section ends, front matter and last page excepted)', not bad,
      '; '.join(bad) if bad else 'exempt section-end pages: ' + ', '.join(f'p.{i} {g:.0%}' for i, g in enumerate(gaps, 1) if g > 0.25) + f'; largest gap elsewhere: {max([g for i, g in enumerate(gaps, 1) if g <= 0.25] or [0]):.0%}')

check('Overleaf project files present (latexmkrc, README.txt, references.bib, figures, tables)', all(os.path.exists(x) for x in ['latexmkrc', 'README.txt', 'references.bib']) and len(glob.glob('figures/*.pdf')) == 4 and len(glob.glob('tables/*.tex')) == 4)

# 12. Front matter: labelled, in the IIMB order, on one block before the Introduction (which starts a new page)
p1 = strip_lineno(pdftext('main.pdf').split('\f')[0])
order = [p1.find(k) for k in ['Revealing hidden jump strategies', 'Short title', 'Abstract', 'Keywords', 'Extended summary']]
check('Front matter on page 1 in order: title, short title, Abstract, Keywords, Extended summary', all(o >= 0 for o in order) and order == sorted(order), str(order))
p2 = strip_lineno(pdftext('main.pdf').split('\f')[1])
first2 = [l.strip() for l in p2.split('\n') if l.strip()][:4]
check('Introduction starts on the page after the front matter', any(re.fullmatch(r'(1\s+)?Introduction', l) for l in first2), ' | '.join(first2))

# 10. Recurring drafting mistakes (each happened at least twice while preparing this paper)
src = {f: rd(f) for f in ['abstract.tex', 'summary.tex', 'body.tex', 'captions.tex', 'highlights.tex', 'titlepage.tex', 'main.tex', 'README.txt'] + glob.glob('tables/*.tex')}
M5 = r'BAICONF abstract|submitted abstract|conference abstract|preliminary analys|earlier analys|exploratory analys[ie]s reported earlier|817 trials|213 athletes|changed numbers|PCA[- ]version|version [0-9]+ of the|previous version|first version|fixed before|pre-?specified|pre-?registered|decided in advance'
hits = [f'{f}: {m.group(0)}' for f, t in src.items() for m in re.finditer(M5, t, re.I)]
hits += [f'{d}.pdf: {m.group(0)}' for d in DOCS for m in re.finditer(M5, pdftext(d + '.pdf'), re.I)]
check('No mention of the conference abstract or an earlier analysis (decision M5)', not hits, '; '.join(hits[:5]))
SLOP = r'\b(delve\w*|crucial|pivotal|landscape|underscor\w+|notabl[ey]|furthermore|moreover|additionally|robust\w*|interplay|intricate|showcas\w+|leverag\w+|novel|groundbreaking|it is important to note|it is worth noting|shed\w* light|paves? the way|in conclusion|trial-specific)\b'
hits = [f'{f}: {m.group(0)}' for f, t in src.items() for m in re.finditer(SLOP, t, re.I)]
hits += [f'{f}: em dash' for f, t in src.items() if '---' in re.sub(r'^%.*$', '', t, flags=re.M) or '\u2014' in t]
check('No stock AI phrasing, em dashes or the "trial-specific" overclaim', not hits, '; '.join(hits[:8]))

n = len(results); p = sum(results)
print(f'\n{p}/{n} checks passed')
sys.exit(0 if p == n else 1)
