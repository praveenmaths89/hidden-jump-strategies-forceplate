#!/usr/bin/env python3
"""Check every DOI in paper/references.bib against Crossref: the DOI must resolve, and the
first author's surname, the year and the title must match the Crossref record."""
import json, re, sys, time, unicodedata, urllib.request, difflib
def norm(s):
    s = unicodedata.normalize('NFKD', re.sub(r'\\[a-zA-Z]+|[{}\\\'"`^~]', '', s))
    return re.sub(r'[^a-z0-9 ]', ' ', s.encode('ascii', 'ignore').decode().lower()).split()
bib = open('paper/references.bib').read()
entries = re.findall(r'@(\w+)\{(\w+),(.*?)\}\s*(?=@|\Z)', bib, re.S)
rows, fails = [], 0
for typ, key, body in entries:
    f = dict((k.lower(), v) for k, v in re.findall(r'(\w+)\s*=\s*\{((?:[^{}]|\{[^{}]*\})*)\}', body))
    if 'doi' not in f:
        rows.append((key, 'NO DOI (url: %s)' % f.get('url', '-'))); continue
    try:
        m = json.load(urllib.request.urlopen('https://api.crossref.org/works/%s?mailto=praveenmaths89@gmail.com' % f['doi'], timeout=30))['message']
    except Exception as e:
        rows.append((key, 'DOI FAILED: %s' % e)); fails += 1; continue
    cr_title = m.get('title', [''])[0] + ' ' + ' '.join(m.get('subtitle', []))
    sim = difflib.SequenceMatcher(None, ' '.join(norm(f['title'])), ' '.join(norm(cr_title))).ratio()
    people = m.get('author') or m.get('editor') or []
    cr_first = norm(people[0].get('family', people[0].get('name', '')))[-1:] if people else []
    bib_first = norm(f['author'].split(' and ')[0].split(',')[0])[-1:]
    years = {p['date-parts'][0][0] for k in ('issued', 'published-print', 'published-online') if k in m for p in [m[k]]}
    prefix = ' '.join(norm(f['title'])).startswith(' '.join(norm(cr_title)))  # Crossref sometimes omits the subtitle
    ok = (sim > 0.80 or prefix) and (not people or cr_first == bib_first) and int(f['year']) in years
    fails += not ok
    rows.append((key, '%s  title-sim %.2f (-1 = Crossref title is a prefix of the bib title)  author %s/%s  year %s in %s' % ('OK  ' if ok else 'FAIL', sim if not prefix or sim > 0.8 else -1, bib_first, cr_first, f['year'], sorted(years))))
    time.sleep(0.2)
for r in rows: print('%-16s %s' % r)
print('\n%d entries, %d with DOI, %d failures' % (len(entries), sum('doi' in b for _, _, b in entries), fails))
sys.exit(1 if fails else 0)
