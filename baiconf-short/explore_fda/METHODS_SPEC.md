# METHODS SPECIFICATION: exploratory functional analysis of CMJ force curves

*Status: exploratory, not part of the submitted paper. Version 2, 13 Nov 2026.*

**Disclosure.** A first-pass run (pointwise OLS FoSR with an athlete bootstrap, k-means profiles, and SPM tests including a between-cluster test) was done before this spec was written. This spec was written after that run but **before** the version-2 analyses (functional mixed models, gap statistic and Jaccard stability, the k = 1 comparison, Freedman–Lane adjusted SPM, SRVF registration, and the sampling audit). It governs everything reported in `FINDINGS.md`. Where a first-pass element is kept, the reason is given below. Nothing was dropped because of its result.

## 0. Data, units and dependence structure

* Source: `cmj_trials_deidentified.csv` only, with the paper's QC rules R1–R5 applied. That leaves 805 trials from 327 sessions of 212 athletes. `_PRIVATE_raw` is never read.
* Curves: y_ijk(t) is the vertical ground-reaction force divided by body weight (×BW) for trial k in session j of athlete i. It is recorded on two separately landmark-registered blocks:
  * take-off, t ∈ [0, 100] % from movement onset to take-off;
  * landing, t ∈ [0, 100] % from touch-down to the lowest centre-of-mass point.

  Each block has 101 equally spaced points. The blocks are analysed separately and never concatenated.
* Dependence: trials are nested in sessions, which are nested in athletes. **No inferential step treats the 805 trials as independent.** Each step uses one of these:
  * an athlete-level functional random effect;
  * resampling of whole athletes (all their sessions and trials) in a bootstrap;
  * permutation of athlete-level units (athlete-mean curves), or sign-flipping of athlete-level paired differences.
* Global settings: seed 2026, α = 0.05 two-sided, B_boot = 2000 athlete resamples, B_perm = 5000 athlete-level permutations. The Monte Carlo SE of a permutation p-value is √(p(1−p)/B). It is at most 0.007, and 0.003 at p = 0.05.

## 1. Function-on-scalar regression (FoSR)

**Estimand.** β_m(t) is the expected change in force (×BW) at phase position t per 1 SD of scalar predictor m, holding the other predictors fixed. We look at it across t for each block.

**Hypotheses.** For predictor m, H0: β_m(t) = 0 for all t, against H1: β_m(t) ≠ 0 for some t. The question of interest is the set of t where the simultaneous 95% band excludes 0.

**Models.** Predictors are standardised.
* Model A: x = (jump height, age, body mass).
* Model B: Model A plus concentric peak force, eccentric braking impulse, and the impulse over the first 100 ms of the concentric phase.

Functional mixed model (Scheipl, Staicu & Greven 2015; Goldsmith et al. 2011 lineage):

  y_ijk(t) = β0(t) + Σ_m x_ijk,m β_m(t) + b_i(t) + c_ij(t) + ε_ijk(t)

* b_i(t) is the functional random intercept for athlete i, b_i(t) = Σ_l ξ_il φ_l(t) with ξ_il ~ N(0, λ_l).
* c_ij(t) is the functional random intercept for session j within athlete i, c_ij(t) = Σ_l ζ_ijl ψ_l(t) with ζ_ijl ~ N(0, ν_l).
* ε_ijk(t) ~ N(0, σ²) is white noise.

The β_m(t) are penalised splines (cubic P-splines, 20 basis functions in t), with smoothing parameters chosen by REML. The random effects are fitted with `refund::pffr` using `pcre()` terms. The eigenfunctions φ and ψ and the eigenvalues λ and ν are estimated from the multilevel decomposition of residuals of the fixed-effect fit, by method of moments (multilevel FPCA in the spirit of Di et al. 2009). We keep eigenfunctions up to 95% of each level's variance.

*Implementation notes (version 2).*
* Fitted with `algorithm = "bam"`, `method = "fREML"` (the fast REML of `bam`) and `discrete = TRUE`, on every second node (51 nodes).
* Eigenfunctions are capped at 5 per level. They reach at least 95% of each level's variance in all fits.
* `sandwich = "none"`. pffr's default cluster sandwich ran out of memory at 16 GB, and the athlete-bootstrap OLS fallback already provides cluster-robust inference.
* A full-grid fit with up to 8 eigenfunctions also ran out of memory or did not finish within 20 minutes.

The node-count sensitivity analysis (§4a) shows that 51 versus 101 nodes does not change the results.

**Simultaneous bands.** Following Ruppert, Wand & Carroll (2003), we draw 10,000 samples from N(β̂, V̂β), the Bayesian posterior covariance from mgcv, and take the 95% quantile c of sup_t |β*(t) − β̂(t)| / se(t). The band is β̂(t) ± c·se(t).

**Robustness and inference fallback.** Pointwise OLS on the 101-point grid, with the same predictors, plus an **athlete-block bootstrap** (2000 resamples of athletes). Its bootstrap sup-t band is valid under arbitrary within-athlete dependence, including within-curve autocorrelation that the mixed model's white-noise ε cannot capture. We report a region as "supported" when both methods agree on it.

**Assumptions and checks.**

| Assumption | Check |
|---|---|
| Linearity of x effects at each t | Partial-residual plots of curve scores (FPC1–FPC2) against each predictor |
| Random effects capture the within-athlete and within-session correlation | Residual correlation surface Cor(ε(s), ε(t)) and the residual lag-1 autocorrelation. Strong leftover structure means the mixed-model SEs are anti-conservative, so the athlete bootstrap becomes the primary inference. |
| Homoscedastic Gaussian ε(t) | Residual SD by t; QQ plot of residuals |
| Weighting / heavy contributors | Equal-athlete weights (1/n_i) and one random session per athlete (in the sampling audit) |
| Collinearity (Model B) | Predictor correlation matrix and VIFs. Model B coefficients are interpreted cautiously, because the impulses are integrals of the take-off curve itself, so their take-off R² is partly built in. |

**Why this method.**
* FoSR (Ramsay & Silverman 2005, ch. 13; Morris 2015) answers *where* along the phase a scalar is associated with force. Discrete metrics or PCA cannot answer that.
* Pointwise t-tests without smoothing or a random effect would ignore both the smoothness and the nesting.
* We did not use Bayesian wavelet functional mixed models (Morris & Carroll 2006), because the curves are smooth and short (101 points), so splines are adequate.
* The athlete bootstrap is kept because it does not need the random-effect structure to be correct.

## 2. Curve clustering (jump profiles). Exploratory only

**Estimand.** Whether the curves contain discrete, reproducible shape groups, and if so how many there are and what they look like. **No hypothesis test about clusters is made.**

**Method.** This is two-stage, filtering-type clustering (Jacques & Preda 2014): FPCA of each block, keeping the scores that reach 90% of variance, followed by k-means for k = 1…6 (50 starts). A model-based cross-check uses Gaussian mixtures (mclust, G = 1…6, BIC).

**Choosing k, and the continuum alternative (k = 1).**
* Gap statistic (Tibshirani, Walther & Hastie 2001; B = 100, rule "firstSEmax"). This is the formal k = 1 comparison.
* Mean silhouette (Kaufman & Rousseeuw 1990): below 0.25 means no substantial structure, and 0.26–0.50 means weak structure that may be artificial.
* Mclust BIC including G = 1.
* Hartigan's dip test of unimodality on FPC1 scores and on log landing duration.
* Cluster-wise **Jaccard stability** over athlete bootstrap resamples (Hennig 2007; 200 resamples): above 0.75 is stable, below 0.5 means the cluster "dissolves". We also report the overall ARI.

If the gap statistic picks k = 1 or the silhouette is below 0.25, we report "no clear cluster structure: a continuum". If k > 1 is picked with a silhouette of 0.25–0.5 and unimodal scores, we report "weak structure: the clusters are a convenient partition of a continuum, not distinct types".

**Within-athlete profile stability.** Athletes with ≥ 2 sessions. A session's profile is the centroid nearest to the session-mean FPC score. We report the share of athletes whose profile is the same in every session. The chance baseline uses two methods: permutation of session profiles across sessions, and the analytic value Σ_i Σ_k p_k^{n_i}.

**Not done.** We do not run SPM between clusters formed from the same curves, because it is circular (the groups were chosen to differ). If it is shown at all, it is labelled *descriptive only* and excluded from the multiplicity count.

## 3. SPM-style pointwise tests with family-wise error control

**Estimand.** Δ(t) = μ_1(t) − μ_2(t): the difference in athlete-mean force curves between two athlete-level groups.

**Hypotheses.** H0: Δ(t) = 0 for all t ∈ [0, 100] within a block, against H1: Δ(t) ≠ 0 on some interval.

**Contrasts.** These are inferential.
* (a) Top versus bottom tertile of athlete-mean jump height.
* (b) Athletes aged ≥ 18 versus < 18. Age group is constant within athlete in this sample (verified in the audit), and athlete-mean age is used.

Each contrast is run raw and **adjusted**:
* (a) adjusted for athlete-mean age and body mass;
* (b) adjusted for athlete-mean body mass and jump height.

Adjustment uses Freedman–Lane permutation of reduced-model residuals (Winkler et al. 2014), because simple residualise-then-permute is liberal.

**Statistic.** The unit is the athlete-mean curve (one per athlete, so units are independent across athletes). This gives every athlete equal weight, whatever their number of trials. The pointwise statistic is a Welch t (unadjusted) or the t of the group coefficient in the linear model (adjusted). The cluster-forming threshold is |t| > t_0.975,df. Supra-threshold intervals of one sign form clusters, and each cluster's statistic is its mass Σ|t|.

**FWER control.** A permutation null of the **maximum cluster mass over the whole block**, from 5000 athlete-level label permutations (Nichols & Holmes 2002; Maris & Oostenveld 2007; the non-parametric SPM of Pataky 2012, 2015). This controls the family-wise error rate at α = 0.05 over the 101 points of each block.

**Effect sizes.** We report:
* the mean difference curve Δ̂(t) with athlete-bootstrap 95% pointwise and sup-t simultaneous bands;
* at the point of peak |t| in each significant cluster, Δ̂ (×BW) with its 95% CI and Hedges' g.

**Test count and multiplicity across analyses.**
* Inferential SPM families: 2 contrasts × 2 blocks = 4 primary families, plus 4 adjusted versions (sensitivity analyses, not new hypotheses).
* Audit: 500 versus 1000 Hz, 2 blocks.
* FoSR: 2 models × 2 blocks × 3 or 6 coefficient functions. Each is FWER-controlled over t through its simultaneous band.

We do not apply an across-family correction, because these are exploratory, separately motivated questions. We report which findings would survive a Bonferroni α = 0.05/4 = 0.0125 across the primary SPM families.

**Assumptions.** Exchangeability of athlete-level units under H0. This is reasonable for athlete means. It is violated if group membership is related to the number of trials an athlete has (we check the n_i distribution by group). Cluster-mass inference localises *intervals* only approximately: a significant cluster means "some difference within this interval", not "a difference at every point" (Pataky 2015).

## 4. Registration and phase variation

The landmark registration is at onset, take-off, touch-down and lowest COM, with linear time-normalisation in between. Residual phase variation (for example, the timing of the landing impact peak) blurs pointwise means, and it can turn timing differences into apparent amplitude differences.

**Sensitivity check (landing).** Elastic SRVF alignment (Srivastava et al. 2011; Tucker, Wu & Srivastava 2013; `fdasrvf::time_warping`) splits each landing curve into an aligned amplitude curve and a warping function γ(t). We then repeat:
* SPM (a) and (b) on the aligned amplitude curves and on the phase functions γ(t) − t;
* the FoSR jump-height coefficient on the aligned curves;
* k = 2 clustering on the aligned curves, with its ARI against the unaligned profiles.

Implemented in `srvf_landing.R`, with the same method as `run_explore.R` §8; the SRVF fit is cached in `srvf_landing_fit.rds`. We conclude that a difference is mainly amplitude if it persists after alignment, and mainly timing if it moves into γ.


## 4a. Final choice: time normalisation, node count and interpolation (added after the literature review; see `LITERATURE.md`)

**Choice.** We keep the two landmark-registered phases as primary:
* take-off, from onset to take-off;
* landing, from touch-down to the lowest COM point.

Each phase is linearly time-normalised to **101 nodes** (0–100 %), and absolute durations are analysed separately as scalars. The functional mixed models are fitted on every second node (51 nodes) to save computation.

**Justification.**
1. **Convention and interpretability.** 101 nodes put node *i* at *i* % of the phase. This is the standard grid in SPM and CMJ waveform work (Pataky et al.; Richter et al. 2014; Parker & Lundgren 2018; and the CMJ SPM studies cited in `LITERATURE.md`).
2. **Sampling audit.**
   * **Take-off:** at least 180 original samples per take-off phase (median 762). The 101-node grid therefore never upsamples take-off; it downsamples by a median factor of about 7.5. The node spacing is 7.7 ms at the median, giving an effective rate of about 130 Hz, which is above twice the low-frequency content of a CMJ take-off.
   * **Landing:** a median of 223 original samples, but a minimum of **41**, and **43 of 805 landings (5.3 %) have fewer than 101 samples**, mostly short landings recorded at 500 Hz. For those trials some nodes are interpolated, and no information is gained or lost by the grid itself; any peak that falls between the original samples was already lost at acquisition.
   * The 101-node landing curve keeps the vendor's peak landing force: median ratio 0.997, with 2.6 % of trials below 0.95.
   * At 1000 Hz, more than 101 nodes would add mostly redundant points. At 500 Hz, more nodes would add only interpolated points.
3. **Sensitivity (time_norm_sensitivity.R).** We compared 51, 101 and 201 nodes, with linear and cubic-spline resampling. The FoSR jump-height regions changed by at most 1–2 % of the phase at their edges. The SPM(a) clusters were identical (take-off 81–99 % versus 82–98 % at 51 nodes; landing 2–56 % at every resolution, p identical). Cumulative PCA variance changed by ≤ 0.4 points. The node count and the interpolation method do not drive any result.
4. **Extra landmarks** (take-off: minimum COM velocity and zero velocity; landing: peak force). We report these as a **registration sensitivity analysis**, not as the primary analysis.
   * Take-off results are qualitatively unchanged.
   * Part of the landing jump-height effect is timing: higher jumpers reach peak landing force earlier, by 2.3 % of landing per SD [95 % CI 0.7, 4.0]. A smaller amplitude effect remains after registration.
   * Following Moudy et al. (2018) and White et al. (2022), extra landmarks risk over-registration and can remove real timing differences, so the primary analysis keeps two landmarks per phase. Timing is reported separately (landmark times, durations, SRVF phase).

**Open item.** Whether the exported force signals were low-pass filtered before resampling cannot be determined from the de-identified file. Harry et al. (2022) show that a 50 Hz low-pass filter does not change CMJ metrics, but lower cut-offs do.

## 5. Matched-height view (descriptive)

Trials in the 45th–55th percentile of jump height. We show the curves split by profile, the profile mix within the band versus overall, and the ratio of the band's mean pointwise SD to the whole sample's (a ratio ≈ 1 means equal height does not narrow the shape variation).

## 6. Sampling audit (prerequisite; see `SAMPLING_AUDIT.md`)

* Native samples per phase against the 101-point grid, and peak retention against the vendor peak.
* Interpolation sensitivity (linear versus spline at the midpoints, and grid decimation).
* 500 versus 1000 Hz: an athlete-level cluster-mass test.
* Contributions per athlete, with equal-weight and one-session-per-athlete re-estimation.
* A check that resampling is at the athlete level, and the Monte Carlo error.
* Selection: QC-dropped versus kept trials, and coverage.

## References

* Di C-Z, Crainiceanu CM, Caffo BS, Punjabi NM (2009). Multilevel functional principal component analysis. *Ann Appl Stat* 3:458–488.
* Goldsmith J, Bobb J, Crainiceanu CM, Caffo B, Reich D (2011). Penalized functional regression. *J Comput Graph Stat* 20:830–851.
* Hennig C (2007). Cluster-wise assessment of cluster stability. *Comput Stat Data Anal* 52:258–271.
* Jacques J, Preda C (2014). Functional data clustering: a survey. *Adv Data Anal Classif* 8:231–255.
* Kaufman L, Rousseeuw PJ (1990). *Finding Groups in Data*. Wiley.
* Maris E, Oostenveld R (2007). Nonparametric statistical testing of EEG- and MEG-data. *J Neurosci Methods* 164:177–190.
* Morris JS (2015). Functional regression. *Annu Rev Stat Appl* 2:321–359.
* Morris JS, Carroll RJ (2006). Wavelet-based functional mixed models. *JRSS-B* 68:179–199.
* Nichols TE, Holmes AP (2002). Nonparametric permutation tests for functional neuroimaging. *Hum Brain Mapp* 15:1–25.
* Pataky TC (2012). One-dimensional statistical parametric mapping in Python. *Comput Methods Biomech Biomed Eng* 15:295–301.
* Pataky TC, Vanrenterghem J, Robinson MA (2015). Zero- vs. one-dimensional, parametric vs. non-parametric, and confidence interval vs. hypothesis testing procedures in one-dimensional biomechanical trajectory analysis. *J Biomech* 48:1277–1285.
* Ramsay JO, Silverman BW (2005). *Functional Data Analysis*, 2nd ed. Springer.
* Ruppert D, Wand MP, Carroll RJ (2003). *Semiparametric Regression*. Cambridge University Press.
* Scheipl F, Staicu A-M, Greven S (2015). Functional additive mixed models. *J Comput Graph Stat* 24:477–501.
* Srivastava A, Wu W, Kurtek S, Klassen E, Marron JS (2011). Registration of functional data using Fisher–Rao metric. arXiv:1103.3817.
* Tibshirani R, Walther G, Hastie T (2001). Estimating the number of clusters via the gap statistic. *JRSS-B* 63:411–423.
* Tucker JD, Wu W, Srivastava A (2013). Generative models for functional data using phase and amplitude separation. *Comput Stat Data Anal* 61:50–66.
* Winkler AM, Ridgway GR, Webster MA, Smith SM, Nichols TE (2014). Permutation inference for the general linear model. *NeuroImage* 92:381–397.
