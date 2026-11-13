import re, os, sys
SRC, NUMS, FIGDIR = sys.argv[1], sys.argv[2], sys.argv[3]
TABDIR = sys.argv[4]
def rd(p): return open(p, encoding='utf8').read()
def inline(s, base):
    def rep(m):
        f = m.group(1)
        if f.startswith('floats/pipeline_tikz'): return ''
        p = os.path.join(base, f if f.endswith('.tex') else f + '.tex')
        if f.startswith('tables/'): p = os.path.join(TABDIR, os.path.basename(p))
        return inline(rd(p), base)
    return re.sub(r'\\input\{([^}]+)\}', rep, s)
def braced(s, i):
    d = 0
    for j in range(i, len(s)):
        if s[j] == '{': d += 1
        elif s[j] == '}':
            d -= 1
            if d == 0: return s[i+1:j], j+1
    raise ValueError(s[i:i+80])
def sub_cmd(s, name, fn, nargs=1):
    out = []; i = 0; pat = '\\' + name + '{'
    while True:
        k = s.find(pat, i)
        if k < 0: out.append(s[i:]); break
        out.append(s[i:k]); j = k + len(pat) - 1; args = []
        for _ in range(nargs):
            while s[j] in ' \n': j += 1
            a, j = braced(s, j); args.append(a)
        out.append(fn(*args)); i = j
    return ''.join(out)
body = rd(os.path.join(SRC, 'body.tex'))
body = re.sub(r'\\begin\{abstract\}.*?\\end\{keywords\}', '', body, flags=re.S)
body = re.sub(r'\\ifsubmission.*?\\fi', '', body, flags=re.S)
body = re.sub(r'\\bibliographystyle\{[^}]*\}\s*\\bibliography\{[^}]*\}', '', body)
body = re.sub(r'\\section\*\{Acknowledgements\}.*?(?=\\section\*)', '', body, flags=re.S)
body = body.replace(r'\section*{Disclosure statement}', r'\section*{Declaration of competing interest}')
body = body.replace(r'\section*{Declaration of generative AI use}', r'\section*{Declaration of generative AI and AI-assisted technologies in the writing process}')
body = inline(body, SRC)
s = rd(NUMS) + '\n' + rd(os.path.join(SRC, 'captions.tex')) + '\n' + body
s = sub_cmd(s, 'todo', lambda a: r'\textbf{[AUTHORS TO COMPLETE: ' + a + ']}')
s = sub_cmd(s, 'tbl', lambda cap, content: '\\caption{' + cap + '}\n' + content, 2)
notes = []
def tn(a):
    notes.append(a); return '%%TABNOTE%d%%' % (len(notes)-1)
s = sub_cmd(s, 'tabnote', tn)
# move each note to after its \end{table}
def mv(m):
    blk = m.group(0); k = re.search(r'%TABNOTE(\d+)%', blk)
    if not k: return blk
    blk = blk.replace(k.group(0), '')
    return blk + '\n\n\\emph{Note.} ' + notes[int(k.group(1))] + '\n\n'
s = re.sub(r'\\begin\{table\}.*?\\end\{table\}', mv, s, flags=re.S)
s = re.sub(r'\\resizebox\{\\textwidth\}\{!\}\{\}', r'\\includegraphics{Fig1_pipeline.pdf}', s)
s = re.sub(r'\\includegraphics(\[[^\]]*\])?\{(Fig\d[^}.]*)\.pdf\}', lambda m: r'\includegraphics[width=6in]{' + os.path.join(FIGDIR, m.group(2) + '.png') + '}', s)
for c in ['\\small', '\\scriptsize', '\\centering']: s = s.replace(c, '')
s = re.sub(r'\\setlength\{\\tabcolsep\}\{[^}]*\}', '', s)

SIMPLE = {'-': '\u2212', '\\pm': '\u00b1', '\\times': '\u00d7', '+2': '+2', '-2': '\u22122',
          '^a': '\\textsuperscript{a}', '^{-2}': '\\textsuperscript{\u22122}', 'R^2': '\\emph{R}\u00b2',
          'g = 9.81': '\\emph{g} = 9.81', 'R^2_k': '\\emph{R}\u00b2\\textsubscript{\\emph{k}}',
          '1 - R^2_k': '1 \u2212 \\emph{R}\u00b2\\textsubscript{\\emph{k}}'}
def simplemath(m):
    k = m.group(1)
    if k in SIMPLE: return SIMPLE[k]
    if re.fullmatch(r'[A-Za-z]', k): return '\\emph{' + k + '}'
    return m.group(0)
s = re.sub(r'(?<!\\)\$([^$]+)\$', simplemath, s)
s = re.sub(r'\\cmidrule(\([^)]*\))?\{[^}]*\}', '', s)

s = '\\documentclass{article}\n\\begin{document}\n' + s + '\n\\end{document}\n'
open('manuscript_pre.tex', 'w', encoding='utf8').write(s)
print('ok', len(s), 'notes', len(notes))
