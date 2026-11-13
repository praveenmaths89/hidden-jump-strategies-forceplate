# LITERATURE: time normalisation and registration of CMJ force curves

*How to read the claims.* All DOIs are in `refs.bib`. All 30 DOIs were resolved through doi.org on 13 Nov 2026, and the metadata returned (first author, year, title, journal) matched. Every reference below was checked this session against the publisher page, PubMed or the conference archive (DOI given). "Verified" means the bibliographic details and the specific claim attributed to the paper were checked against its abstract or full text. Where a claim is our own reasoning rather than something a paper reports, it is marked **[our reasoning]**. We found **no** published study that directly tests whether CMJ force-curve results change with the number of nodes. That gap is stated explicitly, and we ran our own check instead.

## Time normalisation and registration

### (a) The 101-point / 0–100 % convention: where it comes from and what justifies it

* **It is a convention, not a theorem.** Linear time normalisation, which resamples each trial from its start event to its end event onto *n* equally spaced points, is the standard way to make trials of different lengths comparable. *n* = 101 is chosen so that node *i* sits exactly at *i* % of the phase (0, 1, …, 100 %).
  * Pataky, Robinson, Vanrenterghem & Donnelly (2022) describe linear registration as interpolating "at *n* equally spaced time points between movement start and end, where *n* is often 101". They contrast it with nonlinear registration. *J Biomech* 136:111049. doi:10.1016/j.jbiomech.2022.111049. Verified.
  * Pataky's SPM validation simulations sample every 1D continuum at 101 nodes (Pataky et al., "On the validity of statistical parametric mapping for nonuniformly and heterogeneously smooth one-dimensional biomechanical data", *J Biomech*, 2019; LJMU Research Online eprint 10760). The content was verified from the full text; the author list and volume were not checked.
* **Use in CMJ studies.**
  * Strength-matched male versus female soccer players: force, velocity and displacement curves were normalised "to 101 nodes (0–100 % of movement time)" and compared with SPM (*Sports* 2022, PMC8949185). Verified.
  * Elite athletes before and after ACL injury: CMJ force-time data "normalised to 101 data points for the SPM analysis" (de França et al., *Transl Sports Med* 2025, doi:10.1155/tsm2/1176787). Verified.
  * Parker & Lundgren (2018), "Surfing the waves of the CMJ": force normalised to body weight, each repetition normalised to 0–100 %, then PCA of the waveforms. *Sports* 6(4):168. doi:10.3390/sports6040168. Verified.
  * Richter, O'Connor, Marshall & Moran (2014), Analysis of Characterising Phases (ACP): the propulsion-phase curve is time-normalised, and results are reported as % of the phase ("higher forces over 64–96 %"). *J Appl Biomech* 30(2):316–321. doi:10.1123/jab.2012-0218. Verified.
* **Phase boundaries used in CMJ curve work.** McMahon, Suchomel, Lake & Comfort (2018) define the six CMJ phases: weighing, unweighting, braking, propulsion, flight and landing. *Strength Cond J* 40(4):96–106 (2018). doi:10.1519/SSC.0000000000000375. Verified. Harry, Barker & Paquette (2020) show that unloading, eccentric (yielding plus braking) and concentric phase boundaries derived from joint power can be identified from force-platform data alone. *Med Sci Sports Exerc* 52:993–1000 (2020). doi:10.1249/MSS.0000000000002197. Verified.
* **What linear normalisation costs.** Moudy, Richter & Strike (2018) note that time normalisation "does not fully discard all time/phase variability". Comparing curves at the same % can therefore compare different physiological phases, and normalisation throws away absolute timing, which should be kept as a separate variable. *J Biomech* 78:109–117 (2018). doi:10.1016/j.jbiomech.2018.07.027. Verified.
* **Smoothing and basis choice for FDA in sport.** Warmenhoven et al. (2019), "Considerations for the use of functional principal components analysis in sports biomechanics: examples from on-water rowing", *Sports Biomech* 18(3):317–341, doi:10.1080/14763141.2017.1392594. Verified. Gunning, Warmenhoven, Harrison & Bargary (2024), *Functional Data Analysis in Biomechanics*, SpringerBriefs in Statistics, doi:10.1007/978-3-031-68862-1, covers smoothing, registration, FPCA and functional regression with R examples. Verified.
* **The SPM, FDA and SnPM equivalence that underpins our inference.** Warmenhoven, Harrison, Robinson, Vanrenterghem, Bargary, Smith, Cobley, Draper, Donnelly & Pataky (2018) found that FDA, SPM and SnPM gave identical t-statistic curves and the same significant regions on rowing force profiles. *J Sci Med Sport* 21:1100–1105 (2018). doi:10.1016/j.jsams.2018.03.009. Verified.

### (b) How many nodes? Is the result sensitive to the node count?

* **Direct evidence: none found for CMJ.** We found no paper that re-runs a CMJ force-curve analysis at 101 versus other node counts. The literature treats 101 as adequate for smooth waveforms without testing it.
* **Indirect evidence: SPM inference depends on smoothness, not on the node count.**
  * Pataky's 1D random-field and permutation framework takes the curve's smoothness (FWHM) into account. Once the grid is fine compared with the smoothness, adding nodes adds only correlated, redundant points, and neither the critical threshold nor the cluster extent (in % of the phase) changes materially. Pataky et al. 2019 (above) state that non-parametric (permutation) inference "does not rely on smoothness estimates". **[our reasoning, consistent with Pataky's framework]**
  * Warmenhoven et al. 2018 (above) report qualitatively identical results for parametric and non-parametric inference on biomechanical data.
* **The real constraint is the original samples per phase.** The node count should not be so large that most nodes are interpolated, nor so small that sharp features such as landing impact peaks fall between nodes.
  * The VALD technical note on sampling frequency (2025, updated 2026) cites Hori et al. 2009 (*J Strength Cond Res* 23(3):874–882, doi:10.1519/JSC.0b013e3181a00ca2) and Street et al. 2001 (*J Appl Biomech* 17(1):43–54).
  * It also notes that most human movement is below 20 Hz, while the impact phase of landing needs higher rates.
  * Vendor note, verified.
* **Our check (applied, below).** 51 versus 101 versus 201 nodes, with linear versus cubic-spline resampling, re-running the key FoSR, SPM and PCA quantities.

### (c) Linear versus spline resampling; Nyquist, filtering, and whether VALD data are filtered

* **Linear versus spline.** For smooth signals sampled densely compared with the output grid, linear and cubic-spline interpolation give nearly identical curves. Splines preserve curvature better when the original sampling is sparse.
  * The CMJ/SJ fatigue study in *J Strength Cond Res* (2022) 36(10) resampled trimmed curves "through an interpolating cubic spline".
  * Most SPM CMJ papers use linear or spline interpolation without comparing the two.
  * **[our reasoning]**: the difference matters only where a phase has few original samples (short landings at 500 Hz).
* **Filtering.**
  * Harry et al. (2022) compared raw GRF with a 50 Hz low-pass filter and with a "99 % signal power" filter for CMJ metrics. They found that 50 Hz did **not** change CMJ metrics compared with raw data, but the 99 %-power filter (a lower cut-off) biased flight height, RSI, power and concentric time. They recommend reporting filtering explicitly. *J Strength Cond Res* 36:1459–1467 (2022; online 2020). doi:10.1519/JSC.0000000000003611. Verified.
  * VALD's guidance is that the raw (unfiltered) 1000 Hz trace is used for standard CMJ metrics (vendor documentation; ForceDecks user guide). **We could not confirm from the de-identified file whether the exported curves were filtered before resampling.** This is an open item.
* **Nyquist.**
  * Take-off force content in a CMJ is concentrated well below 20–30 Hz. At 500 Hz and 1000 Hz the raw sampling is far above twice that.
  * At the 101-node grid, the effective sampling rate is 101 / phase duration. Take-off at a median 0.76 s gives ≈133 Hz, so its Nyquist frequency is ≈66 Hz. Landing at a median 0.22 s gives ≈450 Hz.
  * Point-sampling a 1000 Hz signal at 101 nodes without an anti-alias filter could, in principle, alias content above the grid's Nyquist frequency. For take-off this is negligible, given its low-frequency content. Landing impacts contain higher frequencies, but the landing grid is dense (median 2.4 ms spacing). **[our reasoning]**

### (d) Landmark, single-time-scale and elastic (SRVF) registration

| Approach | What it aligns | What it preserves | What it loses or risks | CMJ use |
|---|---|---|---|---|
| Single time scale (whole jump 0–100 %, or absolute time aligned at take-off) | Start and end only | Absolute timing (if not normalised) | Phases are misaligned between trials; amplitude and timing differences get mixed | JSCR 2022 fatigue study (absolute time aligned at toe-off versus normalised) |
| **Landmark registration** (piecewise-linear between events) | The chosen physiological events | Event-to-event correspondence; timing kept separately as landmark times or warps | Over-registration if there are too many landmarks; needs reliable event detection | Moudy et al. 2018: start, end of eccentric phase, min/max CoM power, min vGRF, take-off. Registration raised jump-height prediction from 65 % (time-normalised only) to 86–87 %, but "over-registration can occur". |
| Elastic / SRVF (Fisher–Rao) or DTW | All features, nonlinearly | Amplitude–phase separation, with phase as a function | Can "pinch" or over-warp; less interpretable; may remove real timing differences | White, Bezodis, Neville & Summers (ISBS 2020, Proc. 38(1), art. 82): registration with a peak-power landmark gave the best prediction; classification benefited. "The effects of curve registration on linear models of jump performance and classification based on vertical ground reaction forces" (White et al., *J Biomech* 140:111167, 2022, doi:10.1016/j.jbiomech.2022.111167; verified): over 512 preprocessing pipelines, registration helped classification (+5.5 points) but **hurt** jump-height models, and generalised poorly. Pataky et al. 2022 combine nonlinear registration with SnPM to test amplitude and timing together. |

* **How CMJ studies choose landmarks.**
  * Physiologically defined events that can be detected reliably from force alone: movement onset (a BW threshold), minimum force (end of unweighting, or minimum CoM velocity), zero CoM velocity (eccentric-to-concentric transition), peak power and take-off.
  * Moudy et al. 2018 and White et al. 2020/2022 use these.
  * Floría, Sánchez-Sixto & Harrison (2019), "Application of the principal component waveform analysis to identify improvements in vertical jump performance", *J Sports Sci* 37:370–377. doi:10.1080/02640414.2018.1504602. Verified. They analysed force, velocity and displacement curves over the jump.
  * Floría and colleagues' earlier girls' CMJ study (*Res Q Exerc Sport* 2013/14, PubMed 24261012) uses whole-curve comparisons.
  * Kipp, Kiely & Geiser (ISBS 2015 proceedings, published 2016) used factor analysis of discrete CMJ force-time variables, finding temporal and force factors. That is not waveform registration, so we cite it only as evidence that a "temporal" factor sits beside a force factor, which is the reason for analysing timing separately.
* **Landing.** Landing ends at the lowest CoM point in this dataset. The natural extra landmark is peak landing force. We found no CMJ landing registration standard. **[our reasoning]**: impact-peak timing varies a lot (SD ≈ 15 % of landing here), so pointwise landing means are blurred, and a landing difference needs checking against registration.

### What the literature recommends, and how we applied it

1. **Time-normalise each phase between reliable events, and report absolute durations separately.** We do this already: take-off is onset to take-off, landing is touch-down to lowest CoM, and contraction time and landing duration are analysed as scalars.
2. **Choose the node count from the original samples per phase, and show that the result does not depend on it.** Sampling audit: the minimum number of original samples is 180 for take-off and 41 for landing, against a 101-node grid. Our sensitivity check covers 51, 101 and 201 nodes, linear versus spline.
3. **Check registration with more landmarks or with elastic alignment, and look for over-registration.** We added take-off landmarks (minimum CoM velocity and zero velocity) and a landing landmark (peak force), and ran SRVF on landing.
4. **Use non-parametric (permutation) inference so that the results do not depend on smoothness assumptions.** All SPM tests are cluster-mass permutation tests at the athlete level.
5. **Report the filtering.** This is an open item: we need to confirm with the data provider whether the VALD export was filtered.

Results of these checks are in `FINDINGS.md` §0b, and the final choice is in `METHODS_SPEC.md` §4a.
