# FINDINGS: exploratory functional analysis of CMJ force curves

**Status: exploratory. Not part of the submitted paper, and nothing here has been added to the paper, Overleaf or GitHub.**

* Data: `cmj_trials_deidentified.csv` only, after the paper's QC: 805 trials, 327 sessions, 212 male football players. Ages are 8.8–37.9 years (median 14.2), and 74 % of trials are from under-18s.
* Curves: force in body-weight units (×BW), as two separate landmark-registered phases, each 0–100 % on 101 nodes:
  * **take-off**, from movement onset to take-off;
  * **landing**, from touch-down to the lowest centre-of-mass point.
* Methods are in `METHODS_SPEC.md`, the literature on normalisation and registration in `LITERATURE.md` (30 DOIs in `refs.bib`, all resolved), and the checks of the data in `SAMPLING_AUDIT.md`.
* All inference resamples or permutes **athletes**, never trials. α = 0.05.

Scripts, all with seed 2026:
* `audit_sampling.R`, about 1 min;
* `time_norm_sensitivity.R`, about 2 min;
* `run_explore.R`, sections 1–7, about 15 min;
* `srvf_landing.R`, section 8 (SRVF fit about 3 min, cached in `srvf_landing_fit.rds`);
* `within_between_check.R`, under 1 min.

---

## 0. Before the analyses: is the data fit for curve analysis?

### 0a. Sampling audit verdict (details in `SAMPLING_AUDIT.md`)

**Fit for purpose, with four caveats.**

1. **Take-off.** Every take-off has at least 180 original samples (median 762), so the 101-node grid only ever downsamples. The curve peak matches the vendor's concentric peak force (median ratio 0.999).
2. **Landing: a small, real limitation.** 43 of 805 landings (5.3 %) have fewer than 101 original samples, with a minimum of 41. These are mostly short landings recorded at 500 Hz (21 of the 59 trials at 500 Hz). The landing peak is kept well overall: curve maximum divided by the vendor's peak landing force has a median of 0.997. But 10 % of trials lose more than 2 % of the peak and 2.6 % lose more than 5 %, worst in long landings. Halving the grid would lose up to 20 % of the peak in the worst 1 % of trials.
3. **QC drops are not random.** The 28 dropped trials come from lighter athletes (40.8 versus 54.9 kg, p = 0.002) who jump lower (24.9 versus 28.2 cm, p = 0.04). The analysed sample is slightly heavier and better-jumping than everyone tested.
4. **Unknown or unverifiable from the file.** Whether the exported signals were low-pass filtered, and the test dates.

Two further checks:
* **500 versus 1000 Hz.** There is no detectable difference in the curves at the athlete level: no significant cluster in either phase, raw or adjusted. Power is low, with only 14 athletes recorded at 500 Hz.
* **Heavy contributors.** The top 10 % of athletes give 24 % of trials, and the largest single contributor has 16 trials. Jump-height results are unchanged with equal athlete weighting or with one random session per athlete (the coefficient curves correlate at 0.97). **The landing age curve does change** (correlation 0.68), so it is not interpreted.

### 0b. Why 101 points, and does it matter? (`LITERATURE.md`, `METHODS_SPEC.md` §4a)

* **101 nodes is a convention.** Node *i* sits at *i* % of the phase. Pataky's SPM framework and CMJ waveform studies (Richter et al. 2014; Parker & Lundgren 2018; the CMJ SPM papers cited) all use it.
* **No published study tests the node count for CMJ curves**, so we tested it ourselves.
* **What the audit supports.** 101 suits take-off, where it always downsamples. For landing, 101 is about the minimum that keeps impact peaks, and it should not be reduced.
* **Sensitivity: 51 versus 101 versus 201 nodes, linear versus cubic spline.**
  * FoSR jump-height regions moved by at most 1–2 % of the phase at their edges. Take-off was 13–33 % and 65–99 % at 101 nodes, against 12–33 % and 64–100 % at 201 nodes. Landing was 3–28 % in every version.
  * SPM clusters were identical (landing 2–56 %, p = 0.0034, in all versions).
  * PCA variance changed by at most 0.4 points.
  * Linear and spline interpolation give the same answers. Their pointwise differences are negligible (median 0.001 BW) except right at sharp landing peaks.
* **Caveat.** The 201-node curves are re-interpolated from the stored 101-node curves, because the raw signals are private and were not used. This tests the analysis, not the original resampling step.
* **Registration.** We keep two landmarks per phase as the primary analysis. As sensitivity analyses we added extra landmarks (take-off: minimum and zero centre-of-mass velocity; landing: peak force) and elastic SRVF alignment of landing. Results are in §1 and §4.

---

## 1. Where along the jump do jump height and age matter? (Function-on-scalar regression)

**Models.**
* Model A: force(t) ~ jump height + age + body mass. Model B adds concentric peak force, braking impulse, and the impulse over the first 100 ms of the concentric phase. Predictors are standardised: 1 SD is 8.4 cm of jump height, 5.7 years of age and 15.8 kg of body mass.
* Two estimators:
  * pointwise OLS with athlete-block bootstrap simultaneous bands (2000 resamples);
  * a functional mixed model (`refund::pffr`, fREML, with athlete and session functional random intercepts) with Ruppert-type simultaneous bands.
* A region is **"supported"** only when both estimators' simultaneous 95 % bands exclude zero.
* Figures: `fig1a`, `fig1b`, `fig1c`, `fig5a` to `fig5d`. Tables: `F1`, `F2`, `F3`.

**Take-off (supported regions, model A).** Higher jumpers have **lower force at 14–30 %** of take-off, meaning a deeper or faster unweighting, and **higher force from about 66 % to 98 %**, meaning late propulsion. The largest effect is +0.25 BW per SD of jump height at 95–96 % [pointwise 95 % CI 0.23, 0.26].
* An SPM comparison of top versus bottom jump-height tertiles (§3) agrees: 81–99 %, a difference of 0.55 BW [0.48, 0.61], Hedges' g 2.6.
* The age effect is confined to the last few % before take-off (supported only at about 98 %), and is tiny (at most 0.06–0.09 BW per SD).
* Adding extra landmarks keeps the jump-height pattern. Higher jumpers reach the end of unweighting and the zero-velocity point slightly later: +1.0 to 1.1 % of take-off per SD [CI 0.3, 1.8].

**Landing (supported regions).** Higher jumpers have **higher force over 4–28 % of landing**, the impact-absorption phase, and nowhere else. The cross-sectional effect is +0.36 BW per SD of jump height at about 14 %.
* **Within versus between athletes** (`within_between_check.R`, `F3`). When jump height is split into the athlete's average and the trial-to-trial deviation:
  * Within one athlete, a higher jump than usual comes with a much harder early landing: about +0.11 BW per cm at 13 % [CI 0.07, 0.16 per cm], significant at 2–16 %.
  * Between athletes, the effect is about +0.04 BW per cm.
  * This explains why the mixed model's jump-height coefficient (0.90 BW per SD) is larger than the OLS one (0.36). The mixed model mostly estimates the within-athlete effect.
  * Physically this is expected: a higher flight means a faster touch-down.
* **Age.** No significant region in model A under either estimator. In model B the OLS bootstrap flags 60–100 %, but pffr does not, and the landing age curve is unstable under weighting (§0a). **This is treated as null.**
* **Timing versus amplitude.** Peak landing force comes earlier in higher jumpers, by −2.3 % of landing per SD [CI −4.0, −0.7]. After registering at the peak (extra landmark) or with SRVF (§4), a jump-height amplitude effect remains: SPM 4–33 % with landmarks, and 2–45 % on SRVF-aligned curves. **The landing difference is partly timing and partly amplitude.**

**How much do the metrics explain?**
* **Landing.** The three metrics explain only **3–8 %** of between-trial force variance at any landing point (pointwise R²). Adding the other three vendor metrics raises this to at most 9 %. **The vendor metrics say almost nothing about landing shape.**
* **Take-off.** R² is below 10 % for most of the phase, but reaches 45–55 % in the last 10 % (late propulsion). In model B it is around 49 % (median), but that is partly built in, because the impulses are integrals of the take-off curve itself.

**Model checks.**
* **Linearity.** Loess and linear fits of the FPC scores against each predictor agree closely (`fig5d`).
* **Residual structure** (`fig5c`, `F2`). The mixed model's residuals are still strongly autocorrelated within each curve: median lag-1 correlation 0.94–0.97. The athlete-level dependence is absorbed (the athlete ICC of the residual FPC1 is 0.00). The pffr white-noise error is therefore wrong, and **its bands are too narrow**: for example, it flags body mass across 0–100 % of landing. For this reason only regions that the cluster-robust athlete bootstrap also supports are reported.

**So what for coaches.** What separates higher from lower jumpers in take-off is what happens late in propulsion, which jump height already captures. The landing is different: when an athlete jumps higher than usual, the first quarter of the landing gets markedly harder. Landing load should therefore be read relative to that jump's height, not judged from the curve alone. And the standard metrics explain under 10 % of landing shape, so they cannot stand in for looking at the landing.

---

## 2. Are there distinct "jump profiles"? (Curve clustering; exploratory only)

**Method.** k-means on FPC scores (≥ 90 % of variance), separately for each phase, with k = 2–6. k was chosen by silhouette together with bootstrap stability over athlete resamples. The k = 1 (continuum) alternative was checked with the gap statistic, Mclust BIC, dip tests and cluster-wise Jaccard. Figures: `fig2a`, `fig2b`, `fig6`, `fig4`. Tables: `C1` to `C5`.

**Profiles found (k = 2 in both phases).**
* **Take-off.**
  * Profile 1 (n = 329): a fast, deep unweighting down to about 0.35 BW, then a high peak of about 2.5 BW near 70 %. Contraction time 0.65 s.
  * Profile 2 (n = 476): a slower, shallower take-off with a flatter peak of about 2.0 BW. Contraction time 0.88 s.
  * Jump height is 29.6 versus 27.2 cm (mixed model with an athlete random intercept, p < 0.001). Age and body mass differ slightly (16.0 versus 16.4 years).
* **Landing.**
  * Profile 1 (n = 560): a longer landing (0.29 s), peaking at about 3 BW around 20 % of landing, then settling at about 1.8 BW.
  * Profile 2 (n = 245): a short, stiff landing (0.14 s), peaking at about 4.6 BW around 40 %, with a plateau near 2.5 BW.
  * Jump height is 28.4 versus 27.7 cm (p = 0.018; a trivial 0.7 cm). Age (p = 0.58) and body mass (p = 0.13) do not differ.

**But these are not distinct types.**
* **Take-off: no clear cluster structure.** The gap statistic picks **k = 1**. FPC1 scores and log contraction time are unimodal (dip test p = 0.74 and 0.90), and the silhouette is 0.30. The two "profiles" are the fast and slow halves of a continuum.
* **Landing: weak structure.** The silhouette is 0.37 ("weak, could be artificial" on the Kaufman–Rousseeuw scale). FPC1 scores and log landing duration are unimodal (dip p = 0.98 and 0.49). The gap statistic and Mclust BIC keep increasing up to k = 6, which happens with elongated continuous data and is not evidence for six groups.
* **Bootstrap stability is high** (Jaccard 0.93–0.99, ARI 0.81–0.95). But k-means cuts a continuum reproducibly in the same place, so stability here does **not** show that the groups are real.

**Profile stability within athletes** (83 athletes with two or more sessions).
* Same landing profile in every session: **70 %**, against **51 %** expected by chance (permutation p < 0.001).
* Same take-off profile in every session: **55 %**, against 43 % by chance (p = 0.007).
* Within one session, two trials share a landing profile 80 % of the time (chance 58 %).

Profiles are somewhat athlete-specific, but about 30–45 % of repeat testers switch.

**Matched height (`fig4`).** In the 45th–55th percentile of jump height (26.0–28.2 cm; 82 trials from 51 athletes), both landing profiles appear (74 % and 26 %, against 70 % and 30 % overall), as do both take-off profiles (35 % and 65 %). Shape variability is almost as large as in the full sample: the mean pointwise SD ratio is 0.97–0.98. **Equal jump height does not mean an equal curve.**

**Registration caveat.** The landing profiles largely reflect when the impact peak occurs and how long the landing lasts (0.14 versus 0.29 s). After elastic alignment they mostly reorganise (ARI 0.18, §4). They are best read as "landing duration and peak-timing" profiles.

**So what for coaches.** Think of a sliding scale, from short and stiff to long and soft landings, and from quick and deep to slow and shallow take-offs, rather than fixed athlete "types". Where an athlete sits on the scale is moderately repeatable, so it is worth tracking over several trials and sessions, but one jump should not be used to label an athlete.

---

## 3. Pointwise group tests (SPM-style, athlete-level permutation, cluster-mass family-wise error control)

**Method.** The unit is the athlete-mean curve. Clusters are formed at |t| > t_crit, and the cluster mass is tested against a permutation null of the maximum cluster mass over the whole phase (5000 athlete-level permutations; Monte Carlo SE of p at most 0.003 near 0.05). There are four primary families (2 contrasts × 2 phases). Adjusted versions use Freedman–Lane permutation. Figures: `fig3a`, `fig3b`, `fig7`. Tables: `S1`, `S2`, `S3`.

| Contrast (athletes) | Phase | Significant region (raw) | Effect at peak (95 % CI) | Hedges' g [CI] | Adjusted |
|---|---|---|---|---|---|
| (a) Top vs bottom tertile of mean jump height (71 vs 71) | Take-off | **81–99 %**, p = 0.0002 | 2.06 vs 1.52 BW at 93 %: **+0.55 BW [0.48, 0.61]** | 2.63 [2.31, 2.94] | For age and body mass: **66–99 %** (p = 0.0002) and **12–32 %** (p = 0.021; lower force in top jumpers) |
| (a) | Landing | **2–56 %**, p = 0.0034 | 2.65 vs 1.90 BW at 15 %: **+0.75 BW [0.45, 1.04]** | 0.83 [0.50, 1.15] | For age and body mass: only **19–40 %**, p = 0.043 (does **not** survive Bonferroni across 4 families) |
| (b) 18 and over vs under 18 (48 vs 164) | Take-off | **87–99 %**, p = 0.0008 | 1.57 vs 1.10 BW at 96 %: **+0.47 BW [0.37, 0.56]** | 1.60 [1.25, 1.92] | For body mass and jump height: **nothing significant** (all p ≥ 0.12) |
| (b) | Landing | none (10–22 %, p = 0.07) | – | – | For body mass and jump height: none |

The three raw effects survive a Bonferroni correction across the four primary families (p < 0.0125).

* **Adults versus juniors.** The take-off difference is explained by adults jumping higher and being heavier. There is **no evidence of an age-specific curve shape** once those are accounted for.
* **Landing.** Better jumpers land harder in the first half of the landing, but most of this goes with their age and size, and only a weak residual effect remains (19–40 %). On SRVF-aligned landing curves the raw jump-height difference persists (2–45 %, p = 0.003). The phase functions show no difference, so the raw landing difference is mostly amplitude rather than a timing artefact.
* **Adults versus juniors in landing: weak and inconsistent.** The athlete-bootstrap simultaneous band for the age difference just excludes zero at about 12–18 % of landing (`fig7`), but the cluster-mass permutation test does not reach significance (p = 0.07), and adjusting for body mass and jump height removes it. We treat this as weak or null.
* **(c) Between profiles.** This is **descriptive only, because it is circular**: the profiles were built to differ. It is shown in `fig3c` and is not counted as evidence.

**So what for coaches.** Better jumpers differ mainly in the last fifth of take-off, where they push about 0.5 BW harder just before leaving the ground. Juniors do not have a different jump "shape" once size and jump height are taken into account, so separate curve norms for juniors are not supported by these data.

---

## 4. Registration sensitivity (landing: elastic SRVF alignment)

* Elastic alignment splits landing variability into roughly half amplitude and half phase. fdasrvf's decomposition gives a total of 1.32, made up of amplitude 0.65 and phase 0.72.
* **Impact-peak timing therefore accounts for a large share of the landing differences** between trials. This matches the large spread in where the peak falls: SD of 15 % of landing.
* SPM(a) on the aligned amplitude curves: 2–45 % (p = 0.003). On the phase functions: nothing significant for (a) or (b).
* After alignment, the spread in where peak landing force falls drops from an SD of 14.6 % to 4.8 % of landing.
* FoSR on the aligned curves:
  * The jump-height amplitude effect is significant over 1–10 %, 13–45 % and 54–94 % (largest +0.65 BW per SD at 27 %).
  * There is no significant jump-height effect on the phase functions.
  * Caveat: unpenalised SRVF (λ = 0) sharpens peaks and can over-warp, so the aligned amplitudes overstate peak differences somewhat.
* **The landing profiles are not robust to registration.** k = 2 clustering of the aligned landing curves agrees poorly with the unaligned profiles (ARI 0.18). The "short, stiff" versus "long, soft" split is therefore largely a split on timing and duration of the impact, not on force amplitude.
* **Interpretation.** The between-athlete jump-height difference in landing is a real amplitude difference. Many trial-to-trial differences between landings, however, are differences in *when* the peak occurs. This is a caution for any pointwise landing result, including the paper's PCA, where landing PC1 partly reflects timing.

---

## What this can and cannot claim

**Can claim (within this centre's tested population of mostly adolescent male footballers):**
* Jump height is associated with force in two specific windows: about 66–99 % of take-off (more force late in propulsion) and about 4–28 % of landing (a harder early impact). These hold under athlete-level resampling, weighting changes, node count (51, 101 or 201), interpolation method and extra landmarks.
* The vendor metrics explain under 10 % of landing-curve variance at any point. Landing shape carries information the standard report does not.
* Within an athlete, a higher-than-usual jump comes with a markedly harder early landing (about 0.11 BW per cm).
* Curve "profiles" are a convenient description of a continuum. Landing profiles mainly capture landing duration and the timing of the impact peak. Where an athlete sits on it is moderately repeatable across sessions (70 % against 51 % by chance for landing).
* After adjusting for jump height and body mass, there is no evidence that adults' and juniors' curves differ in shape.

**Cannot claim:**
* **No causal or injury claims.** There are no injury or outcome data, and a "stiff" landing is not shown to be harmful or worse.
* **No discrete athlete types.** The cluster tests favour a continuum, at k = 1 for take-off.
* **No generalisation** to females, other sports, other force-plate systems, or untested populations. This is a single referral centre, and the analysed sample is slightly heavier and better-jumping than everyone tested (§0a).
* **No standardised-landing interpretation.** Landing technique was not instructed or controlled. Landing differences may partly reflect how athletes chose to land on that day, and 30–45 % switch profile between sessions.
* **Not confirmatory.** These analyses were exploratory, some choices followed a first look (see the disclosure in `METHODS_SPEC.md`), and there is no correction across all analyses beyond the stated family-wise control. Findings should be replicated before being used to make decisions.
* **The pffr bands on their own are not trustworthy here.** The residuals are autocorrelated within curves, so only regions also supported by the athlete bootstrap are claimed.

**Other caveats.**
* Repeated measures are handled throughout by athlete-level resampling or random effects.
* Most participants are minors (74 % of trials are from under-18s, 59 % from under-15s), and growth and maturation are not measured beyond age.
* Absolute durations are removed by time normalisation. They differ strongly between profiles (contraction time 0.65 versus 0.88 s; landing 0.14 versus 0.29 s) and should be reported alongside any curve result.
* Whether the exported signals were filtered is unknown.

## Most informative figures

1. `figs/fig5a_pffr_modelA_coefficients.png` and `figs/fig1a_fosr_modelA_coefficients.png`: where jump height, age and body mass act along take-off and landing.
2. `figs/fig7_spm_effect_size_curves.png`: group differences with effect-size bands (top versus bottom jump height; adults versus juniors).
3. `figs/fig4_matched_height_profiles.png`: the same jump height with different curves.
4. `figs/fig6_cluster_continuum_check.png`: profiles are slices of a continuum, not types.

Supporting figures: `fig1c` (pointwise R²), `fig2b` (profile mean curves), `fig3a` and `fig3b` (SPM), `fig5c` (residual diagnostics), `fig8` (SRVF), `figT1` (node count and registration sensitivity), `figA1` and `figA2` (audit).
