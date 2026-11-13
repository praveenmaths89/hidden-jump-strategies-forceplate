import re, sys, glob
def clean(s):
    s = re.sub(r'%.*', '', s)
    s = re.sub(r'\\begin\{equation\}.*?\\end\{equation\}', ' ', s, flags=re.S)
    s = re.sub(r'\$[^$]*\$', ' ', s)
    s = re.sub(r'\\(parencite|textcite|citep|citet|ref|label|input|includegraphics|caption)\{[^}]*\}', ' ', s)
    s = re.sub(r'\\[a-zA-Z]+\*?(\[[^\]]*\])?', ' ', s)
    s = re.sub(r'[{}~]', ' ', s)
    return s
def sents(s): return [x.strip() for x in re.split(r'(?<=[.;:])\s+', clean(s)) if len(x.split()) > 5]
def toks(s): return re.findall(r"[a-z0-9]+", s.lower())
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6
target = sys.argv[2]; refs = sys.argv[3:]
ref_grams = set()
for r in refs:
    t = toks(clean(open(r).read()))
    ref_grams |= {tuple(t[i:i+N]) for i in range(len(t)-N+1)}
out = []
for s in sents(open(target).read()):
    t = toks(s)
    if len(t) < N: continue
    cov = [False]*len(t)
    for i in range(len(t)-N+1):
        if tuple(t[i:i+N]) in ref_grams:
            for j in range(i, i+N): cov[j] = True
    out.append((sum(cov)/len(t), s[:160]))
out.sort(reverse=True)
tot = sum(1 for c,_ in out if c > 0.5)
print('sentences', len(out), '>50% covered', tot, '>25%', sum(1 for c,_ in out if c > 0.25))
for c, s in out[:int(sys.argv[0:1] and 40)]:
    if c > 0.25: print(f'{c:.2f} | {s}')
