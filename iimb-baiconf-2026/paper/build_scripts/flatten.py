# Flattens the Overleaf project into pandoc-friendly LaTeX for the Word versions
import re, os
O = '/workspace/iimb-baiconf-2026/overleaf/'; FIG = os.path.abspath('fig')
rd = lambda p: open(O + p, encoding='utf8').read()
defs = rd('numbers.tex') + '\n' + rd('captions.tex') + '\n' + r'''
\newcommand{\testPeriod}{November 2022 and April 2026}
\newcommand{\ethics}[1]{\textbf{#1}}
''' + rd('frontmatter.tex')
def braced(s, i):
    d = 0
    for j in range(i, len(s)):
        if s[j] == '{': d += 1
        elif s[j] == '}':
            d -= 1
            if d == 0: return s[i+1:j], j+1
def sub_cmd(s, pat, fn):
    out = []; i = 0
    while True:
        k = s.find(pat, i)
        if k < 0: out.append(s[i:]); return ''.join(out)
        out.append(s[i:k]); a, j = braced(s, k + len(pat) - 1); out.append(fn(a)); i = j
def table(t):
    t = re.sub(r'^%.*\n', '', t, flags=re.M)
    note = re.search(r'\\begin\{tablenotes\}(\[[^\]]*\])?\\footnotesize\s*\\item\s*(.*?)\\end\{tablenotes\}', t, re.S)
    t = re.sub(r'\\begin\{tablenotes\}.*?\\end\{tablenotes\}', '', t, flags=re.S)
    t = re.sub(r'\\begin\{tabular\*\}\{\\linewidth\}\{@\{\\extracolsep\{\\fill\}\}([^@]*)@\{\}\}', lambda m: '\\begin{tabular}{' + m.group(1) + '}', t)
    t = t.replace('\\end{tabular*}', '\\end{tabular}')
    t = re.sub(r'\\begin\{tabularx\}\{\\linewidth\}\{@\{\}>\{\\raggedright\\arraybackslash\}Xll@\{\}\}', r'\\begin{tabular}{lll}', t).replace('\\end{tabularx}', '\\end{tabular}')
    t = re.sub(r'>\{\\raggedright\\arraybackslash\}p\{[^}]*\}', 'l', t)
    t = sub_cmd(t, '\\makecell[r]{', lambda a: a.replace('\\\\', ' '))
    t = sub_cmd(t, '\\makecell[l]{', lambda a: a.replace('\\\\', ' '))
    t = re.sub(r'\\cmidrule(\([^)]*\))?\{[^}]*\}', '', t)
    for c in ['\\begin{threeparttable}', '\\end{threeparttable}', '\\footnotesize', '\\small', '\\centering']: t = t.replace(c, '')
    t = re.sub(r'\\setlength\{\\tabcolsep\}\{[^}]*\}', '', t)
    t = t.replace('Landing~', 'Landing ')
    t = t.replace('\\end{table}', '\\end{table}\n\n' + ('\\emph{Note.} ' + note.group(2).replace('\\textit{Note.}', '').strip() + '\n\n' if note else ''))
    return t
def inline(s):
    return re.sub(r'\\input\{tables/([^}]+)\}', lambda m: table(rd('tables/' + m.group(1) + '.tex')), s)
SIMPLE = {'-': '\u2212', '\\pm': '\u00b1', '\\times': '\u00d7', '^a': '\\textsuperscript{a}', 'R^2': '\\emph{R}\u00b2',
          'g = 9.81': '\\emph{g} = 9.81', 'R^2_k': '\\emph{R}\u00b2\\textsubscript{\\emph{k}}',
          '1 - R^2_k': '1 \u2212 \\emph{R}\u00b2\\textsubscript{\\emph{k}}', 'n': '\\emph{n}', 'r': '\\emph{r}'}
def simplemath(m):
    k = m.group(1)
    if k in SIMPLE: return SIMPLE[k]
    if re.fullmatch(r'[A-Za-z]', k): return '\\emph{' + k + '}'
    return m.group(0)
LAB = {}
for i, f in enumerate(sorted(os.listdir(O + 'tables')), 1):
    for l in re.findall(r'\\label\{([^}]+)\}', rd('tables/' + f)): LAB[l] = str(i)
for i, l in enumerate(re.findall(r'\\label\{(fig:[^}]+)\}', rd('body.tex')), 1): LAB[l] = str(i)
LAB.update({'sec:intro': '1', 'sec:lit': '2', 'sec:methods': '3', 'sec:curves': '3.2', 'sec:results': '4', 'sec:discussion': '5', 'sec:implications': '6', 'sec:conclusion': '7'})
def finish(s):
    import itertools
    s = re.sub(r'\\ref\{([^}]+)\}', lambda m: LAB[m.group(1)], s)
    s = s.replace('[H]', '')
    for env, lab in (('table', 'Table'), ('figure', 'Fig.')):
        c = itertools.count(1)
        s = re.sub(r'(\\begin\{' + env + r'\}.*?)\\caption\{', lambda m: m.group(1) + '\\caption{\\textbf{' + lab + ' ' + str(next(c)) + '.} ', s, flags=re.S)
    s = re.sub(r'\\includegraphics(\[[^\]]*\])?\{(Fig\d[^}]*)\}', lambda m: r'\includegraphics[width=6in]{' + FIG + '/' + m.group(2) + '.png}', s)
    s = re.sub(r'(?<!\\)\$([^$]+)\$', simplemath, s)
    s = s.replace('~', ' ')
    return s
body = inline(rd('body.tex'))
main = rd('main.tex')
decl = main[main.index('\\section*{Declarations}'):main.index('\\singlespacing')]
front = (r'\begin{center}\textbf{\papertitle}\end{center}' + '\n\n\\textbf{Short title:} \\shorttitle\n\n'
         + rd('abstract.tex') + '\n\n' + rd('summary.tex') + '\n\n')
ms = finish(defs + '\n\\begin{document}\n' + front + body + '\n' + decl + '\n\\end{document}\n')
ms = '\\documentclass{article}\n' + ms
open('manuscript.tex', 'w', encoding='utf8').write(ms)
# exhibits
tabs = [table(rd('tables/' + f)) for f in sorted(os.listdir(O + 'tables'))]
ex = rd('exhibits.tex'); figs = re.findall(r'\\begin\{figure\}.*?\\end\{figure\}', ex, re.S)
exs = finish(defs + '\n\\begin{document}\n\\textbf{Exhibits (tables and figures) for: \\papertitle}\n\n\\section*{Tables}\n' + '\n\n'.join(tabs) + '\n\n\\section*{Figures}\n' + '\n\n'.join(figs) + '\n\\end{document}\n')
open('exhibits.tex', 'w', encoding='utf8').write('\\documentclass{article}\n' + exs)
# title page & highlights
for name in ['titlepage', 'highlights']:
    s = rd(name + '.tex'); s = s[s.index('\\begin{document}'):]
    s = s.replace('\\onehalfspacing', '').replace('\\medskip', '').replace('\\smallskip', '').replace('\\bigskip', '')
    s = re.sub(r'\\noindent\s*', '', s); s = s.replace('\\par', '\n\n')
    open(name + '.tex', 'w', encoding='utf8').write('\\documentclass{article}\n' + finish(defs + s))
print('flattened')
