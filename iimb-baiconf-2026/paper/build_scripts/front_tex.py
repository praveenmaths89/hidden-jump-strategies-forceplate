from front import *
def esc(x): return x.replace('%', '\\%').replace('&', '\\&')
out = ['\\begin{center}\\textbf{' + TITLE[0].upper() + TITLE[1:] + '}\\end{center}', '',
       '\\noindent\\textbf{Short title:} ' + SHORT, '', '\\noindent\\textbf{Abstract}', '', '\\noindent ' + esc(ABSTRACT), '',
       '\\noindent\\textbf{Keywords:} ' + '; '.join(KEYWORDS), '', '\\noindent\\textbf{Extended summary}', '']
out += [esc(p) + '\n' for p in SUMMARY]
out += ['\\newpage', '']
open('front.tex', 'w').write('\n'.join(out))
