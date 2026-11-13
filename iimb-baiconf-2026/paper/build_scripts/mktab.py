# Lays out the R-generated table bodies (package/output/paper_tables_latex) for the Overleaf project.
# Only layout, captions and notes are added here; every number comes from the R pipeline.
import re
T = '/workspace/iimb-baiconf-2026/package/output/paper_tables_latex/'
O = '/workspace/iimb-baiconf-2026/overleaf/tables/'
def rows(f):
    s = open(T + f).read()
    return re.split(r'(?<!c)\\midrule', s, maxsplit=1)[1].split('\\bottomrule')[0].strip()
def table(src, label, caption, size, colspec, head, body, note, tabx=False):
    env = 'tabularx' if tabx else 'tabular*'
    begin = ('\\begin{tabularx}{\\linewidth}{%s}' % colspec) if tabx else ('\\begin{tabular*}{\\linewidth}{@{\\extracolsep{\\fill}}%s@{}}' % colspec)
    txt = ('%% Generated from package/output/paper_tables_latex/%s (R pipeline); only layout changed.\n' % src
           + '\\begin{table}[H]\n\\centering\n\\begin{threeparttable}\n\\caption{%s}\n\\label{%s}\n%s\n' % (caption, label, size)
           + begin + '\n\\toprule\n' + head + '\n\\midrule\n' + body + '\n\\bottomrule\n\\end{%s}\n' % env
           + '\\begin{tablenotes}[flushleft]\\footnotesize\n\\item \\textit{Note.} ' + note + '\n\\end{tablenotes}\n\\end{threeparttable}\n\\end{table}\n')
    open(O + src, 'w').write(txt)
for old in ['tab6_windows.tex']:
    import os
    if os.path.exists(O + old): os.remove(O + old)
table('tab1_qc.tex', 'tab:qc', 'Quality-control flow (main analysis).', '\\small', 'lrrr',
      'Step & Trials & Sessions & Athletes \\\\', rows('tab1_qc.tex'),
      'Rules R1--R4 apply to both landing definitions; R5 applies only to the main landing definition (touch-down to the lowest point of the centre of mass), and the 1-s landing window therefore retained \\nTrialsS{} trials. Sessions are test occasions on which an athlete performed one or more trials. COM = centre of mass.')
table('tab2_descriptives.tex', 'tab:desc', 'Characteristics of the analysed sample (\\nTrials{} trials, \\nAth{} athletes).', '\\footnotesize\\setlength{\\tabcolsep}{3pt}',
      '>{\\raggedright\\arraybackslash}p{0.30\\linewidth}rlll', 'Variable & $n$ & Mean $\\pm$ SD & Median (IQR) & Range \\\\',
      rows('tab2_descriptives.tex').replace(' to ', '--'),
      'Age and body mass are per athlete at the first analysed trial; all other rows are per trial unless stated. Jump height is derived from flight time. Countermovement depth is the vendor estimate of centre-of-mass displacement (negative downwards); one trial with zero depth and zero braking impulse satisfied all quality-control rules and was retained. Touch-down to lowest COM is the duration of the landing phase in the main analysis. BW = body weight; COM = centre of mass; IQR = interquartile range.')
table('tab3_components.tex', 'tab:pcs', 'Retained principal components of the concatenated take-off and landing curve (main analysis).', '\\footnotesize\\setlength{\\tabcolsep}{3pt}',
      'lrrrlrrrrr',
      ' & & & \\makecell[r]{Landing\\\\share of} & \\makecell[l]{Largest} & \\multicolumn{5}{c}{Pearson $r$ with} \\\\\n\\cmidrule(l){6-10}\nComponent & \\makecell[r]{Variance\\\\(\\%)} & \\makecell[r]{Cumulative\\\\(\\%)} & \\makecell[r]{loading\\\\(\\%)} & \\makecell[l]{loading\\\\at} & LPF & JH & CT & CMD & LD \\\\',
      rows('tab3_components.tex').replace('Landing ', 'Landing~'),
      'Landing share of loading is the percentage of the squared loading vector in the landing block (the remainder is in the take-off block). Largest loading at gives the phase and the percentage of the phase at which the loading has its largest absolute value. LPF = peak landing force (\\,$\\times$\\,BW); JH = jump height; CT = contraction time; CMD = countermovement depth; LD = landing duration (touch-down to lowest COM). Signs are fixed so that the largest absolute loading is positive.')
table('tab4_bands.tex', 'tab:band', 'Dispersion of component scores in the full sample and among trials matched on jump height or on relative concentric peak force (main analysis).', '\\footnotesize\\setlength{\\tabcolsep}{3pt}',
      'lrrlrl', ' & & \\multicolumn{2}{c}{Jump-height band} & \\multicolumn{2}{c}{Relative peak-force band} \\\\\n\\cmidrule(lr){3-4}\\cmidrule(l){5-6}\nComponent & \\makecell[r]{SD, full\\\\sample} & SD & Ratio (95\\% CI) & SD & Ratio (95\\% CI) \\\\',
      rows('tab4_bands.tex'),
      'Matched bands comprise trials between the 45th and 55th percentiles of jump height (\\jhBandLo--\\jhBandHi\\,cm; \\jhBandN{} trials, \\jhBandAth{} athletes) or of concentric peak force relative to body weight (\\rpfBandLo--\\rpfBandHi\\,BW; \\rpfBandN{} trials, \\rpfBandAth{} athletes). Ratio = SD in the band divided by SD in the full sample; 95\\% CI from \\nBoot{} athlete-level bootstrap resamples, conditional on the estimated components. Component SDs depend on the number of grid points and are comparable only within this table; ratios are scale-free. $^a$Square root of the summed point-wise variance of the 202-point curve.')
table('tab5_r2.tex', 'tab:r2', 'Variance of each component score explained by the four vendor metrics, age and body mass, under four evaluation schemes (main analysis, $R^2$ in \\%).', '\\small',
      'lrrrrr', 'Component & In-sample & Adjusted & Athlete CV & \\makecell[r]{One trial\\\\per athlete} & \\makecell[r]{Athlete\\\\means} \\\\',
      rows('tab5_r2.tex'),
      'Predictors: jump height, concentric peak force, eccentric braking impulse, concentric impulse over the first 100\\,ms, age and body mass (ordinary least squares). In-sample and adjusted values use all \\nTrials{} trials. Athlete CV = out-of-sample $R^2$ from five-fold cross-validation with athletes allocated to folds. One trial per athlete = one randomly drawn trial per athlete (\\nAth{} trials). Athlete means = scores and predictors averaged within athlete.')
table('tab6_variance.tex', 'tab:vd', 'Decomposition of component-score variance between athletes, sessions and trials (main analysis, \\% of total variance).', '\\small',
      'lllll', 'Component & \\makecell[l]{Between\\\\athletes} & \\makecell[l]{Between\\\\sessions} & \\makecell[l]{Within\\\\session} & \\makecell[l]{Between athletes,\\\\age-adjusted} \\\\',
      rows('tab6_variance.tex').replace('Between athletes, age-adjusted', ''),
      'Three-level random-intercept model (athlete, session within athlete, trial within session) fitted by restricted maximum likelihood. Values in parentheses are 95\\% CIs from \\nBoot{} athlete-level bootstrap resamples. Only \\nAthMultiSess{} of the \\nAth{} athletes contributed more than one session, so the between-session share is imprecise. Age-adjusted = the same model with age at test as a fixed effect.')
table('tab7_windows.tex', 'tab:window', 'Main analysis compared with the sensitivity analysis in which the landing phase ended 1\\,s after touch-down.', '\\footnotesize\\setlength{\\tabcolsep}{3pt}',
      '@{}>{\\raggedright\\arraybackslash}Xll@{}', 'Quantity & \\makecell[l]{Main: landing to\\\\lowest COM} & \\makecell[l]{Sensitivity:\\\\1-s landing} \\\\',
      rows('tab7_windows.tex'),
      'COM = centre of mass; CI = confidence interval; CV = cross-validation. Between-athlete variance is taken from the three-level random-intercept model. In the 1-s window PC3 is a take-off component (Fig.~\\ref{fig:window}), which explains its correlation with contraction time and its narrower dispersion among trials matched on relative peak force.', tabx=True)
print('tables written')
