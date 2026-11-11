#!/usr/bin/env python3
"""PII scan of every file that would be committed. Tokens come from PRIVATE files passed on the command line
(VALD profiles JSON/CSV, tests.csv, codebook.json); they are never printed. Usage:
  python3 tools/pii_scan.py --profiles a.json b.csv ... --tests tests.csv --codebook codebook.json
Prints the number of matches per file and token type, and exits 1 if anything matches."""
import argparse, csv, json, os, re, subprocess, sys
ap = argparse.ArgumentParser(); ap.add_argument('--profiles', nargs='*', default=[]); ap.add_argument('--tests', nargs='*', default=[])
ap.add_argument('--codebook', nargs='*', default=[]); a = ap.parse_args()
tok = {'name': set(), 'fullname': set(), 'id': set(), 'email': set(), 'dob': set(), 'group': set()}
def add(rec):
    g, f = str(rec.get('givenName') or '').strip().lower(), str(rec.get('familyName') or '').strip().lower()
    if g and f: tok['fullname'].update({g + ' ' + f, f + ' ' + g, f + ', ' + g})
    for k, v in rec.items():
        if v in (None, '') or isinstance(v, (list, dict)): continue
        v = str(v).strip(); kl = k.lower()
        if kl in ('givenname', 'familyname'):
            for part in re.split(r'[\s\-\.]+', v):
                if len(part) >= 3: tok['name'].add(part.lower())
        elif kl in ('profileid', 'externalid', 'syncid', 'testid', 'trialid', 'id') and len(v) >= 6: tok['id'].add(v.lower())
        elif kl == 'email': tok['email'].add(v.lower())
        elif kl == 'dateofbirth': tok['dob'].add(v[:10])
        elif kl == 'groupname' and len(v) >= 4: tok['group'].add(v.lower())
for p in a.profiles:
    if p.endswith('.json'):
        d = json.load(open(p)); d = d.get('profiles', d) if isinstance(d, dict) else d
        for r in d: add(r)
    else:
        for r in csv.DictReader(open(p, encoding='utf-8', errors='ignore')): add(r)
for p in a.tests:
    for r in csv.DictReader(open(p, encoding='utf-8', errors='ignore')): add({k: v for k, v in r.items() if k.lower() in ('testid', 'profileid')})
for p in a.codebook:
    d = json.load(open(p))
    for sec in d.values():
        if isinstance(sec, dict):
            for k in sec: tok['id'].add(str(k).lower())
print('tokens loaded:', {k: len(v) for k, v in tok.items()})
files = [l for l in subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], capture_output=True, text=True).stdout.splitlines()]
generic = {'email-pattern': re.compile(r'[\w.+-]+@[\w-]+\.[\w.]+'), 'uuid-pattern': re.compile(r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b', re.I),
           'iso-date-pattern': re.compile(r'\b(19|20)\d\d-[01]\d-[0-3]\d\b')}
allow_email = {'praveenmaths89@gmail.com'}   # corresponding author's public contact address
THIRD_PARTY = {'paper/booktabs.sty', 'paper/natbib.sty', 'paper/subfig.sty', 'paper/tfapastyle.sty', 'paper/interact.cls', 'paper/tfapacite.bst'}
VERSION_DATES = {'outputs/sessionInfo.txt', 'paper/tfapacite.bst'}   # R build date / style-file version date
hits = 0
name_tokens = set()
FULL_RX = re.compile(r'\b(?:' + '|'.join(sorted(map(re.escape, tok['fullname']), key=len, reverse=True)) + r')\b') if tok['fullname'] else None
for f in files:
    if f.endswith('.png') or f.startswith('tools/pii_scan'): continue
    if f.endswith('.pdf'): text = subprocess.run(['pdftotext', f, '-'], capture_output=True, text=True).stdout
    elif f.endswith('.eps'):   # only DSC comments; the drawn text is identical to the scanned PDF in paper/figures
        text = ''.join(l for l in open(f, encoding='latin-1') if l.startswith('%%'))
    else:
        try: text = open(f, encoding='utf-8', errors='ignore').read()
        except IsADirectoryError: continue
    low = text.lower(); words = set(re.findall(r'[a-z]+', low))
    res = {}
    res['full-name'] = len(FULL_RX.findall(low)) if FULL_RX else 0
    single = words & tok['name']
    if single: name_tokens.update(single)
    res['id'] = sum(1 for t in tok['id'] if t in low)
    res['email'] = sum(1 for t in tok['email'] if t in low)
    res['dob'] = sum(1 for t in tok['dob'] if t in text)
    res['group'] = sum(1 for t in tok['group'] if re.search(r'\b' + re.escape(t) + r'\b', low))
    for k, rx in generic.items():
        if k == 'email-pattern' and f in THIRD_PARTY: continue
        if k == 'iso-date-pattern' and f in VERSION_DATES: continue
        m = [x for x in (mm.group(0).rstrip('.') for mm in rx.finditer(text)) if x.lower() not in allow_email]
        res[k] = len(m)
    res = {k: v for k, v in res.items() if v}
    if res: hits += 1; print(f'{f}: {res}')
print(f'scanned {len(files)} files; files with matches: {hits}')
print(f'single name-part tokens that also occur in committed text (common words, author or cited-author names; review by hand, not printed): {len(name_tokens)}')
sys.exit(1 if hits else 0)
