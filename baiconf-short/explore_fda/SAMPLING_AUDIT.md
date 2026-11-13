# SAMPLING AUDIT (run before the main analyses)

Script: `audit_sampling.R` (seed 2026). Log: `audit_log.txt`. Tables: `tables/A1`–`A8`. Figures: `figs/figA1_weighting_sensitivity.png` and `figs/figA2_sampling_audit.png`. Node-count and registration checks: `time_norm_sensitivity.R` (`tables/T1`, `T2`; `figs/figT1_timenorm_sensitivity.png`). Data: the de-identified CSV only.

## Summary of what is wrong or needs care

1. **Short landings at 500 Hz are undersampled compared with the 101-node grid.** 43 of 805 landings (5.3 %) have fewer than 101 original samples. The minimum is 41 samples, and 21 of the 59 trials recorded at 500 Hz (36 %) fall below 101. For these trials the 101-node landing curve is partly interpolated. It is not wrong, but it adds no information, and a sharp impact peak between the original samples was already missed at acquisition.
2. **The landing peak is slightly attenuated in some trials.** Curve maximum divided by the vendor's peak landing force has a median of 0.997, but 10 % of trials are below 0.98 and 2.6 % are below 0.95 (minimum 0.857). Attenuation is worse for longer landings (Spearman ρ = −0.29 with duration), because the 101 nodes are spread more thinly there. Halving the grid to 51 nodes would lose up to 19.5 % of the landing peak in the worst 1 % of trials. **101 nodes is therefore about the minimum for landing, and should not be reduced for landing analyses.**
3. **Whether the exported curves were low-pass filtered is unknown.** This cannot be determined from the file. It is an open item for the data provider.
4. **Test dates are not in the de-identified file.** The Nov 2022 to Apr 2026 coverage stated in the paper cannot be verified from it.
5. **QC drops are not random.** The 28 dropped trials come from lighter athletes (body mass 40.8 versus 54.9 kg, Wilcoxon p = 0.002), with lower jump height (24.9 versus 28.2 cm, p = 0.044) and lower peak landing force. Rule R2, quiet-stance mass more than 5 % from body mass, removes the most trials (15). This rule is harder to meet for light, young athletes. The bias is small in absolute terms (3.4 % of trials), but the analysed sample is slightly heavier and better-jumping than the tested population.
6. **The age effect on landing curves depends on how athletes are weighted.** The age coefficient curve for landing correlates only 0.68 between trial weighting and equal athlete weighting, with peaks of 0.34 versus 0.17 BW per SD. The age result for landing is therefore driven partly by heavy contributors, and should not be interpreted (it is not significant under any weighting anyway).

Nothing in the audit invalidates the main analyses. Points 2, 5 and 6 limit the claims we make.

## (1) Signal sampling

| Phase | Hz | Trials | Min | Q1 | Median | Q3 | Max | Trials < 101 samples | Trials > 505 samples (≥ 5× downsampling) |
|---|---|---|---|---|---|---|---|---|---|
| Take-off | 500 | 59 | 180 | 334 | 376 | 419 | 681 | 0 | 5 |
| Take-off | 1000 | 746 | 306 | 663 | 777 | 903 | 1484 | 0 | 692 |
| Landing | 500 | 59 | 41 | 82 | 120 | 147 | 289 | **21** | 0 |
| Landing | 1000 | 746 | 70 | 151 | 235 | 316 | 928 | **22** | 19 |

The samples per phase are calculated as phase duration × native rate. Take-off duration is the vendor's contraction time. We checked this against the curve: the take-off velocity integrated from the curve matches the velocity implied by jump height, with r = 0.964 and a median ratio of 0.985. The window and duration are therefore consistent.

* **Take-off.** The grid always downsamples (by a median factor of 7.5). Node spacing is 7.7 ms at the median and 14.8 ms at the maximum, an effective rate of 68–130 Hz, which is well above the low-frequency content of a CMJ take-off. The curve maximum matches the vendor's concentric peak force (median ratio 0.999). The ratio exceeds 1 (up to 1.51) only in trials where the take-off window's maximum lies in the braking phase rather than the concentric phase, which is expected and not an error.
* **Landing.** Node spacing is 2.4 ms at the median and 9.3 ms at the maximum. See points 1 and 2 above.
* **Linear versus spline.** We compared the two at the grid midpoints on the stored curves, in ×BW. For take-off the median difference is 0.0009 and the 99th percentile 0.017. For landing the median is 0.0012 and the 99th percentile 0.114, with a maximum of 1.2 near sharp impact peaks. The method only matters at impact peaks.
* **Node-count sensitivity (51, 101 and 201 nodes, linear and spline; `tables/T1`).**
  * FoSR jump-height regions: take-off 13–33 % and 65–99 % at 101 nodes, against 14–32 % and 66–98 % at 51 nodes and 12–33 % and 64–100 % at 201 nodes. Landing is 3–28 % in every version.
  * SPM(a) clusters: take-off 81–99 % (82–98 % at 51 nodes), landing 2–56 % with p = 0.0034 in every version.
  * PCA cumulative variance changed by at most 0.4 points.

  **Results do not depend on the node count or the interpolation method.** Caveat: 201-node curves can only be re-interpolated from the stored 101-node curves, because the raw signals are private. This tests the analysis's sensitivity, not information lost at the original resampling. That loss is assessed through the peak retention in point 2.
* **500 versus 1000 Hz.** We ran an athlete-level functional test, with cluster-mass permutation (5000) on athlete-mean curves. It covered 14 athletes recorded only at 500 Hz against 192 recorded only at 1000 Hz; 6 athletes with both rates were excluded. **There was no significant difference** in take-off (a cluster at 0–1 %, p = 0.46) or landing (no supra-threshold cluster), either raw or adjusted for jump height, age and body mass. The groups were similar (jump height 27.4 versus 27.5 cm, age 15.7 versus 16.2 years, landing duration 0.247 versus 0.247 s). Power is low with 14 athletes at 500 Hz, so this is "no evidence of a difference", not proof of equivalence.

## (2) Study sampling

* **Trials per athlete:** 1 (11 athletes), 2 (58), 3 (60), 4 (20), 5 (28), 6 (6), 7 (14), 8 (7), 9 to 12 (7), and 16 (1).
* **Sessions per athlete:** 1 (129), 2 (58), 3 (20), 4 (4), 6 (1). **Trials per session:** mostly 2 or 3.
* **Concentration.** The top 10 % of athletes (22) contribute 24.0 % of trials, with a Gini coefficient of 0.30. This is moderate, and no single athlete dominates (the maximum is 16 of 805 trials, 2 %).
* **Re-estimation of the key FoSR estimates (model A).** We compared trial weighting (as analysed), equal weight per athlete (1/n_i), and one random session per athlete (median over 500 draws). See `tables/A6` and `figs/figA1`.

| Block | Term | r(trial-weighted, athlete-weighted) | r(trial-weighted, one session) | Max \|difference\| (BW) | Simultaneous-band regions (trial-weighted → athlete-weighted) |
|---|---|---|---|---|---|
| Take-off | Jump height | 0.976 | 0.967 | 0.04 | 13–32 %, 65–99 % → 16–27 %, 78–99 % |
| Take-off | Age | 0.975 | 0.973 | 0.03 | 95–99 % → 95–99 % |
| Landing | Jump height | 0.973 | 0.965 | 0.10 | 4–27 % → 3–32 % |
| Landing | Age | **0.682** | **0.653** | **0.23** | none → none |

The jump-height findings are robust to weighting. The landing age curve is not (see point 6).

## (3) Resampling for inference

| Step | Resampled unit | Count |
|---|---|---|
| FoSR bands (`run_explore.R` §1) | Whole athletes, with all their trials (`ath_idx`) | B = 2000; the Monte Carlo SE of the simultaneous critical value is reported in `F1` (0.03–0.05) |
| pffr bands (§5) | Posterior simulation; random effects for athlete and session | 10,000 draws |
| SPM (§3, §7, §8; audit) | Athlete-mean curves (one row per athlete), label permutation; Freedman–Lane residual permutation at the athlete level | B = 5000. The p-value Monte Carlo SE is at most 0.007, and 0.003 at p = 0.05; the smallest p is 0.0002 |
| Cluster stability (§2, §6) | Whole athletes | 200 resamples |
| Profile stability chance baseline | Session labels | 2000 permutations, plus an analytic baseline |
| Effect-size CIs (§7) | Athletes, within groups | 2000 |

* **Age group is constant within athlete.** No athlete's trials straddle age 18 (0 of 212), so the age contrast is properly an athlete-level contrast.
* **Within-athlete spread.** Among athletes with more than one session, the age span has a median of 0.7 years (maximum 2.5), and the body-mass span a median of 3.0 kg (maximum 12.3). No implausible jumps remain after QC; a 46 kg span in the raw file belonged to a trial removed by QC.
* **Note on the first-pass SPM (c), between clusters.** It used sign-flipping of within-athlete differences, which is athlete-level. But it is circular, so it is reported as descriptive only.

## (4) Selection

| Rule | Trials flagged (overlapping) |
|---|---|
| R1 invalid body mass | 5 |
| R2 quiet-stance mass more than 5 % from body mass | 15 |
| R3 flight force above 50 N | 2 |
| R4 missing metrics or age | 0 |
| R5 no lowest-COM landing end | 11 |

The flags overlap: 28 trials are dropped in total, from 21 athletes. Three athletes are lost entirely. Only one dropped trial was recorded at 500 Hz.

| Variable | Kept (n = 805), mean | Dropped (n = 28), mean | Wilcoxon p |
|---|---|---|---|
| Age (y) | 16.3 | 14.9 | 0.17 |
| Body mass (kg) | 54.9 | 40.8 | **0.002** |
| Jump height (cm) | 28.2 | 24.9 | **0.044** |
| Concentric peak force (N) | 1269 | 1115 | 0.069 |
| Peak landing force (N) | 2913 | 2182 | **0.006** |
| Contraction time (s) | 0.78 | 0.71 | 0.049 |
| Landing duration (s) (n = 17 dropped) | 0.247 | 0.246 | 0.64 |

**Coverage of the kept trials.**
* Age: 8.8–37.9 years (median 14.2, IQR 12.5–18.2). 74.3 % of trials are from under-18s and 59.1 % from under-15s.
* Body mass: 25–96 kg (median 53.4).
* Test dates are not available in the de-identified file.

**Referral and single-centre bias.** All athletes are male football players tested at one private centre. Athletes who attend a performance centre are likely to be more motivated and better resourced than the general youth football population, and the mix of academies or clubs that refer them is unknown. Repeat testers (83 athletes with two or more sessions) may differ from one-time testers. Results should be read as describing **this centre's tested population**, not youth footballers in general.
