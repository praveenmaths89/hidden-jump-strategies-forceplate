#!/usr/bin/env Rscript
# =============================================================================
# Builds every paper input for the BAICONF short paper from the analysis outputs:
#   ../paper/numbers_fda.tex  (all in-text numbers as LaTeX macros)
#   ../paper/tables/tab1..4   (booktabs + siunitx)
#   ../paper/figures/Fig1..4  (greyscale PDF; PNG copies for the Word version)
#   ../IIMB_BAICONF2026_dataset.xlsx (data + dictionary)
# Run after audit_sampling.R, time_norm_sensitivity.R, run_explore.R, srvf_landing.R,
# within_between_check.R (run_all.R does this). Seed 2026 (no random steps here).
# =============================================================================
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(ggplot2); library(patchwork); library(writexl) })
set.seed(2026); G <- 9.81
PAPER <- Sys.getenv("PAPER_DIR", "../paper"); dir.create(file.path(PAPER, "tables"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path(PAPER, "figures"), showWarnings = FALSE); dir.create("paper_png", showWarnings = FALSE)
T <- function(f) read.csv(file.path("tables", f), stringsAsFactors = FALSE)
source("data_path.R"); raw <- read.csv(cmj_data_path())
raw <- raw %>% mutate(
  fail_r1 = is.na(body_mass_kg) | body_mass_kg <= 0,
  fail_r2 = !fail_r1 & abs(quiet_mass_kg - body_mass_kg) / body_mass_kg > 0.05,
  fail_r3 = abs(flight_force_n) > 50,
  fail_r4 = is.na(age) | is.na(jump_height_cm) | is.na(conc_peak_force_n) | is.na(ecc_braking_impulse_ns) | is.na(conc_impulse_100ms_ns),
  fail_r5 = is.na(ldc_050),
  qc_pass = !(fail_r1 | fail_r2 | fail_r3 | fail_r4 | fail_r5))
tr <- raw %>% filter(qc_pass); n <- nrow(tr); pct <- 0:100
Y <- list(takeoff = as.matrix(tr[, grep("^to_[0-9]", names(tr))]) / (tr$body_mass_kg * G),
          landing = as.matrix(tr[, grep("^ldc_[0-9]", names(tr))]) / (tr$body_mass_kg * G))
prof <- T("C6_trial_profiles.csv"); stopifnot(all(prof$athlete == tr$athlete), all(prof$trial_no == tr$trial_no))

# ---------------- numbers ----------------
NUM <- character()
f <- function(x, d = 1) formatC(x, format = "f", digits = d)
neg <- function(s) sub("^-", "$-$", s)
num <- function(name, value) { stopifnot(grepl("^[A-Za-z]+$", name)); NUM[name] <<- as.character(value) }
pr <- function(p) if (p < 0.001) "< 0.001" else paste("=", f(p, 3))
pr4 <- function(p) if (p < 0.001) "< 0.001" else paste("=", f(p, 3))
rng <- function(s) { s <- gsub("%", "", s); s <- gsub("\\b([0-9]+)-\\1\\b", "\\1", s, perl = TRUE); gsub("-", "--", s) }
rparts <- function(s) { r <- strsplit(gsub("%", "", s), ", ")[[1]]; m <- do.call(rbind, lapply(strsplit(r, "-"), as.numeric)); m }
# sample
num("nTrialsAll", nrow(raw)); num("nAthAll", n_distinct(raw$athlete)); num("nSessAll", n_distinct(raw$test_code))
num("nTrials", n); num("nAth", n_distinct(tr$athlete)); num("nSess", n_distinct(tr$test_code)); num("nDropped", sum(!raw$qc_pass))
num("nAthLost", n_distinct(raw$athlete) - n_distinct(tr$athlete))
num("pctUnderEighteen", f(100 * mean(tr$age < 18), 0)); num("pctUnderFifteen", f(100 * mean(tr$age < 15), 0))
num("ageMin", f(min(tr$age))); num("ageMax", f(max(tr$age))); num("ageMedian", f(median(tr$age)))
ses_ath <- tapply(tr$test_code, tr$athlete, function(x) length(unique(x)))
num("nAthMulti", sum(ses_ath >= 2)); num("trialsPerAthMax", max(table(tr$athlete)))
num("nFsLow", sum(tr$native_fs == 500)); num("nFsHigh", sum(tr$native_fs == 1000))
num("sdJH", f(sd(tr$jump_height_cm))); num("sdAge", f(sd(tr$age))); num("sdBM", f(sd(tr$body_mass_kg)))
num("meanJH", f(mean(tr$jump_height_cm)))
# audit
A1 <- T("A1_samples_per_phase.csv"); a_all <- A1[is.na(A1$native_fs), ]
num("toSampMin", a_all$min[a_all$phase == "n_to"]); num("toSampMedian", f(a_all$median[a_all$phase == "n_to"], 0))
num("ldSampMin", a_all$min[a_all$phase == "n_ld"]); num("ldSampMedian", f(a_all$median[a_all$phase == "n_ld"], 0))
num("nLdUnder", a_all$n_below_101[a_all$phase == "n_ld"]); num("pctLdUnder", f(100 * a_all$n_below_101[a_all$phase == "n_ld"] / n))
num("nLdUnderLowFs", A1$n_below_101[A1$phase == "n_ld" & A1$native_fs %in% 500])
A2 <- T("A2_peak_retention.csv")
num("retLdMedian", f(A2$ret_ld_median, 3)); num("retLdPctTwo", f(100 * A2$ret_ld_share_below_0.98, 0)); num("retLdPctFive", f(100 * A2$ret_ld_share_below_0.95, 1))
num("retToMedian", f(A2$ret_to_median, 3))
A3b <- T("A3b_decimation_51pt.csv"); num("decLossLdP", f(100 * A3b$landing[A3b$stat == "peak_loss_p99.99%"], 0))
A3 <- T("A3_linear_vs_spline_midpoints.csv"); num("splineDiffMedian", f(max(A3$takeoff[A3$stat == "median_abs"], A3$landing[A3$stat == "median_abs"]), 3))
A7 <- T("A7_dropped_vs_kept.csv"); g7 <- function(v, c) A7[[c]][A7$variable == v]
num("bmKept", f(g7("body_mass_kg", "kept_mean"))); num("bmDropped", f(g7("body_mass_kg", "dropped_mean"))); num("pBmDropped", f(g7("body_mass_kg", "wilcox_p"), 3))
num("jhKept", f(g7("jump_height_cm", "kept_mean"))); num("jhDropped", f(g7("jump_height_cm", "dropped_mean"))); num("pJhDropped", f(g7("jump_height_cm", "wilcox_p"), 3))
A4 <- T("A4_fs_500_vs_1000_spm.csv"); num("fsMinP", f(min(suppressWarnings(as.numeric(A4$p)), na.rm = TRUE), 2))
ct <- T("A5_contributions_per_athlete.csv"); top <- sort(ct$trials, decreasing = TRUE)[1:ceiling(0.1 * nrow(ct))]
num("pctTopTen", f(100 * sum(top) / n, 0))
A6 <- T("A6_weighting_sensitivity_curves.csv")
wc <- function(b, term) { a <- A6 %>% filter(block == b, term == !!term); cor(a$est[a$weighting == "trial_weighted"], a$est[a$weighting == "athlete_weighted"]) }
num("wcorJHto", f(wc("takeoff", "jh"), 2)); num("wcorJHld", f(wc("landing", "jh"), 2)); num("wcorAgeld", f(wc("landing", "age"), 2))
# node count / interpolation
T1 <- T("T1_node_count_interp_sensitivity.csv")
spm_ld <- unique(T1$spm_a_sig[T1$block == "landing"]); num("nodeSpmLdSame", ifelse(length(spm_ld) == 1, "identical", "not identical"))
pcv <- sapply(strsplit(T1$pc1_4_cum_var, "/"), function(x) as.numeric(x[4])); num("nodePcMaxDiff", f(max(tapply(pcv, T1$block, function(v) diff(range(v)))), 1))
num("fosrJHtoHundredOne", rng(T1$fosr_jh_sim_sig[T1$block == "takeoff" & T1$nodes == 101])); num("fosrJHtoTwoHundredOne", rng(T1$fosr_jh_sim_sig[T1$block == "takeoff" & T1$nodes == 201 & T1$interp == "spline"]))
num("fosrJHldAll", rng(T1$fosr_jh_sim_sig[T1$block == "landing" & T1$nodes == 101]))
T3 <- T("T3_landmark_timing.csv"); gt <- function(l, c) T3[[c]][T3$landmark == l]
num("velR", f(gt("velocity check (r, median ratio)", "est"), 2)); num("velRatio", f(gt("velocity check (r, median ratio)", "lo"), 3))
num("tmZeroV", f(gt("zero velocity", "est"), 1)); num("tmZeroVlo", f(gt("zero velocity", "lo"), 1)); num("tmZeroVhi", f(gt("zero velocity", "hi"), 1))
num("tmPeak", neg(f(gt("peak landing force", "est"), 1))); num("tmPeaklo", neg(f(gt("peak landing force", "lo"), 1))); num("tmPeakhi", neg(f(gt("peak landing force", "hi"), 1)))
num("peakSD", f(gt("SD peak-landing %", "est"), 0)); num("posZeroV", f(gt("mean zero-velocity %", "est"), 0)); num("posMinV", f(gt("mean min-velocity %", "est"), 0))
T2 <- T("T2_landmark_registration_sensitivity.csv"); num("lmSpmLd", rng(sub(" \\(p=.*", "", T2$spm_a_sig[T2$block == "landing"])))
num("lmSpmLdP", f(as.numeric(sub(".*p=([0-9.]+).*", "\\1", T2$spm_a_sig[T2$block == "landing"])), 3))
# FoSR
F1 <- T("F1_fosr_significance.csv"); F1c <- T("F1_fosr_coefficients.csv"); F2 <- T("F2_pffr_significance.csv"); F2d <- T("F2_pffr_residual_diagnostics.csv")
R2 <- T("F1_fosr_pointwise_r2.csv")
num("rtwoLdMaxA", f(100 * max(R2$r2[R2$model == "A" & R2$block == "landing"]), 0)); num("rtwoLdMinA", f(100 * min(R2$r2[R2$model == "A" & R2$block == "landing"]), 0))
num("rtwoLdMaxB", f(100 * max(R2$r2[R2$model == "B" & R2$block == "landing"]), 0))
r2to <- R2 %>% filter(model == "A", block == "takeoff")
num("rtwoToShareLow", f(100 * mean(r2to$r2[r2to$pct %in% 5:89] < 0.10), 0)); num("rtwoToLate", f(100 * max(r2to$r2[r2to$pct %in% 90:99]), 0))
num("simCritMin", f(min(F1$sim_crit), 2)); num("simCritMax", f(max(F1$sim_crit), 2)); num("simCritMCmax", f(max(F1$sim_crit_mc_se), 2))
num("residLagMin", f(min(F2d$resid_lag1_corr_median), 2)); num("residLagMax", f(max(F2d$resid_lag1_corr_median), 2))
pk <- function(b, term, model = "A") { d <- F1c %>% filter(model == !!model, block == b, term == !!term); k <- which.max(abs(d$est)); d[k, ] }
for (b in c("takeoff", "landing")) { bb <- ifelse(b == "takeoff", "to", "ld")
  p <- pk(b, "jump_height"); num(paste0("pkJH", bb), f(p$est, 2)); num(paste0("pkJH", bb, "lo"), f(p$lo_pw, 2)); num(paste0("pkJH", bb, "hi"), f(p$hi_pw, 2)); num(paste0("pkJH", bb, "at"), p$pct)
  s <- F2 %>% filter(model == "A", block == b, term == "jump_height"); num(paste0("supJH", bb), rng(s$supported_both)) }
sp <- rparts(F2$supported_both[F2$model == "A" & F2$block == "takeoff" & F2$term == "jump_height"])
num("supJHtoEarly", paste0(sp[1, 1], "--", sp[1, 2])); num("supJHtoLateLo", sp[2, 1]); num("supJHtoLateHi", sp[nrow(sp), 2]); num("supJHtoGaps", c("no", "one", "two", "three", "four")[nrow(sp) - 1])
op <- rparts(F1$sig_simultaneous[F1$model == "A" & F1$block == "takeoff" & F1$term == "jump_height"])
num("olsJHtoEarly", paste0(op[1, 1], "--", op[1, 2])); num("olsJHtoLate", paste0(op[2, 1], "--", op[2, 2]))
mp <- rparts(F2$sig_sim_pffr[F2$model == "A" & F2$block == "takeoff" & F2$term == "jump_height"]); num("mmJHtoN", nrow(mp))
num("olsJHld", rng(F1$sig_simultaneous[F1$model == "A" & F1$block == "landing" & F1$term == "jump_height"]))
num("olsAgeLdN", ifelse(F1$sig_simultaneous[F1$model == "A" & F1$block == "landing" & F1$term == "age"] == "none", "no", "some"))
num("supAgeLd", rng(F2$supported_both[F2$model == "A" & F2$block == "landing" & F2$term == "age"]))
am0 <- tr %>% group_by(athlete) %>% mutate(dev = jump_height_cm - mean(jump_height_cm)) %>% ungroup()
num("sdJHwithin", f(sd(am0$dev))); num("sdJHbetween", f(sd(tapply(tr$jump_height_cm, tr$athlete, mean))))
num("supAgeTo", rng(F2$supported_both[F2$model == "A" & F2$block == "takeoff" & F2$term == "age"]))
pa <- pk("takeoff", "age"); num("pkAgeTo", f(pa$est, 2))
num("pffrJHld", f(as.numeric(sub(" .*", "", F2$effect_ci_at_max[F2$model == "A" & F2$block == "landing" & F2$term == "jump_height"])), 2))
F3 <- T("F3_within_between_jump_height.csv"); sdj <- sd(tr$jump_height_cm)
w3 <- function(b, term) F3[F3$block == b & F3$term == term, ]
ci3 <- function(s) as.numeric(strsplit(gsub("\\[|\\]", "", s), ",")[[1]])
for (b in c("takeoff", "landing")) for (term in c("jh_within", "jh_between")) { r <- w3(b, term); nm <- paste0(ifelse(term == "jh_within", "wi", "bw"), ifelse(b == "takeoff", "To", "Ld"))
  num(paste0(nm, "Cm"), f(r$max_effect_per_SD_JH / sdj, 3)); cc <- ci3(r$ci) / sdj; num(paste0(nm, "CmLo"), f(cc[1], 3)); num(paste0(nm, "CmHi"), f(cc[2], 3))
  num(paste0(nm, "Reg"), rng(r$sig_sim)); num(paste0(nm, "At"), r$at_pct) }
num("wiBwRatio", c("one", "two", "three", "four", "five")[round(w3("landing", "jh_within")$max_effect_per_SD_JH / w3("landing", "jh_between")$max_effect_per_SD_JH)])
num("wiLdFirst", rng(strsplit(w3("landing", "jh_within")$sig_sim, ", ")[[1]][1]))
# SPM
S1 <- T("S1_spm_clusters.csv"); S2 <- T("S2_spm_adjusted_freedman_lane.csv"); S3 <- T("S3_spm_effect_sizes.csv")
am <- tr %>% group_by(athlete) %>% summarise(jh = mean(jump_height_cm), age = mean(age), .groups = "drop"); tert <- quantile(am$jh, c(1/3, 2/3))
num("nTop", sum(am$jh >= tert[2])); num("nBottom", sum(am$jh <= tert[1])); num("nAdult", sum(am$age >= 18)); num("nJunior", sum(am$age < 18))
num("tertLo", f(tert[1])); num("tertHi", f(tert[2]))
s3 <- function(cn, b) S3[substr(S3$contrast, 1, 1) == cn & S3$block == b, ]
for (cn in c("a", "b")) for (b in c("takeoff", "landing")) { r <- s3(cn, b); if (!nrow(r)) next
  nm <- paste0(ifelse(cn == "a", "tert", "age"), ifelse(b == "takeoff", "To", "Ld"))
  num(paste0(nm, "Reg"), rng(r$cluster)); num(paste0(nm, "P"), pr(r$p_raw)); num(paste0(nm, "D"), f(r$diff_bw, 2)); num(paste0(nm, "Dlo"), f(r$ci_lo, 2)); num(paste0(nm, "Dhi"), f(r$ci_hi, 2))
  num(paste0(nm, "G"), f(r$hedges_g, 2)); num(paste0(nm, "Glo"), f(r$g_ci_lo, 2)); num(paste0(nm, "Ghi"), f(r$g_ci_hi, 2)); num(paste0(nm, "At"), r$peak_pct)
  num(paste0(nm, "MeanHi"), f(r$mean_g1, 2)); num(paste0(nm, "MeanLo"), f(r$mean_g2, 2)) }
ageLdRaw <- S1 %>% filter(substr(contrast, 1, 1) == "b", block == "landing") %>% arrange(p) %>% slice(1)
num("ageLdRawReg", rng(ageLdRaw$range)); num("ageLdRawP", f(ageLdRaw$p, 2))
s2 <- function(cn, b) S2 %>% filter(substr(contrast, 1, 1) == cn, block == b)
sig2 <- function(d) d %>% filter(!is.na(p), p < 0.05)
a2to <- sig2(s2("a", "takeoff")); num("tertToAdjRegs", paste(sprintf("%s\\%% (\\(p\\) %s)", rng(a2to$range), sapply(a2to$p, pr)), collapse = " and "))
a2ld <- sig2(s2("a", "landing")); num("tertLdAdjReg", rng(a2ld$range)); num("tertLdAdjP", f(a2ld$p, 3))
num("ageToAdjMinP", f(min(s2("b", "takeoff")$p, na.rm = TRUE), 2)); num("ageLdAdjMinP", f(min(s2("b", "landing")$p, na.rm = TRUE), 2))
num("bonf", f(0.05 / 4, 4))
# clustering
C2 <- T("C2_cluster_profiles.csv"); C3 <- T("C3_profile_stability.csv"); C4 <- T("C4_cluster_validation.csv"); C5 <- T("C5_cluster_jaccard.csv")
for (b in c("takeoff", "landing")) { bb <- ifelse(b == "takeoff", "To", "Ld"); c2 <- C2[C2$block == b, ]; c3 <- C3[C3$block == b, ]; c4 <- C4[C4$block == b, ]
  num(paste0("nProfOne", bb), c2$n_trials[1]); num(paste0("nProfTwo", bb), c2$n_trials[2])
  num(paste0("jhProfOne", bb), f(c2$jump_height_cm_mean[1])); num(paste0("jhProfTwo", bb), f(c2$jump_height_cm_mean[2]))
  num(paste0("ctProfOne", bb), f(c2$contraction_time_s_mean[1], 2)); num(paste0("ctProfTwo", bb), f(c2$contraction_time_s_mean[2], 2))
  num(paste0("ldProfOne", bb), f(c2$landing_to_lowcom_s_mean[1], 2)); num(paste0("ldProfTwo", bb), f(c2$landing_to_lowcom_s_mean[2], 2))
  num(paste0("pJHProf", bb), pr(c2$p_jump_height_lmm[1]))
  num(paste0("sil", bb), f(c4$silhouette, 2)); num(paste0("gapK", bb), c4$gap_k_firstSEmax); num(paste0("dip", bb), f(c4$dip_FPC1_p, 2))
  num(paste0("jacMin", bb), f(min(C5$jaccard_mean[C5$block == b]), 2)); num(paste0("jacMax", bb), f(max(C5$jaccard_mean[C5$block == b]), 2))
  num(paste0("stab", bb), f(100 * c3$share_same_all_sessions, 0)); num(paste0("chance", bb), f(100 * c3$chance_perm_mean, 0)); num(paste0("pStab", bb), pr(c3$p_perm))
  num(paste0("wsAgree", bb), f(100 * c3$within_session_trial_agreement, 0)); num(paste0("wsChance", bb), f(100 * c3$within_session_chance, 0)) }
num("jacMinAll", f(min(C5$jaccard_mean), 2)); num("jacMaxAll", f(max(C5$jaccard_mean), 2))
num("dipLogLd", f(C4$dip_logduration_p[C4$block == "landing"], 2))
M1 <- T("M1_matched_band_profiles.csv"); M2 <- T("M2_matched_band_limits.csv")
num("bandLo", f(M2$lo_cm)); num("bandHi", f(M2$hi_cm)); num("bandN", M2$n_trials); num("bandAth", M2$n_athletes)
num("bandSdRatioMin", f(min(M1$mean_sd_ratio_band_vs_all), 2)); num("bandSdRatioMax", f(max(M1$mean_sd_ratio_band_vs_all), 2))
num("bandLdShareTwo", f(M1$pct_band[M1$block == "landing" & M1$cluster == 2], 0)); num("bandToShareOne", f(M1$pct_band[M1$block == "takeoff" & M1$cluster == 1], 0))
R1 <- T("R1_srvf_sensitivity.csv"); R2s <- T("R2_srvf_summary.csv")
num("srvfAri", f(R1$ari_k2_vs_unaligned[1], 2)); num("srvfSpmA", rng(sub(" \\(.*", "", R1$a_top_vs_bottom_JH[1])))
num("srvfSpmAP", f(as.numeric(sub(".*p=([0-9.]+).*", "\\1", R1$a_top_vs_bottom_JH[1])), 3))
num("srvfPhaseShare", f(100 * R2s$var_phase / (R2s$var_phase + R2s$var_amplitude), 0))
num("srvfPeakSDun", f(R2s$peak_sd_unaligned, 0)); num("srvfPeakSDal", f(R2s$peak_sd_aligned, 0))
writeLines(c("% Generated by explore_fda/make_paper_outputs.R from the analysis outputs -- do not edit by hand",
             sprintf("\\newcommand{\\%s}{%s}", names(NUM), NUM)), file.path(PAPER, "numbers_fda.tex"))
cat(length(NUM), "macros written\n")

# ---------------- tables ----------------
wtab <- function(lines, name) writeLines(c("% Generated by explore_fda/make_paper_outputs.R -- regenerate rather than edit", lines), file.path(PAPER, "tables", paste0(name, ".tex")))
ds <- function(x, d) { q <- quantile(x, c(.25, .5, .75), na.rm = TRUE); c(f(mean(x, na.rm = TRUE), d), f(sd(x, na.rm = TRUE), d), f(q[2], d), f(q[1], d), f(q[3], d), f(min(x, na.rm = TRUE), d), f(max(x, na.rm = TRUE), d)) }
row <- function(lab, x, d) paste0("\\quad ", lab, " & ", paste(ds(x, d), collapse = " & "), " \\\\")
first <- tr %>% group_by(athlete) %>% slice(1) %>% ungroup()
tpa <- as.vector(table(tr$athlete)); tps <- as.vector(table(tr$test_code))
t1 <- c("\\begin{table}[!htbp]", "\\centering", "\\begin{threeparttable}", "\\caption{Sample characteristics}", "\\label{tab:desc}",
  "\\footnotesize\\setlength{\\tabcolsep}{3pt}",
  "\\begin{tabular}{@{}l S[table-format=4.2] S[table-format=3.2] S[table-format=4.2] S[table-format=4.2] S[table-format=4.2] S[table-format=4.2] S[table-format=4.2]@{}}",
  "\\toprule", " & & & & \\multicolumn{2}{c}{Quartiles} & \\multicolumn{2}{c}{Range} \\\\", "\\cmidrule(lr){5-6}\\cmidrule(l){7-8}",
  "Variable & {Mean} & {SD} & {Median} & {Q1} & {Q3} & {Min} & {Max} \\\\", "\\midrule",
  sprintf("\\multicolumn{8}{@{}l}{\\textit{Athletes ($n$ = %d)}} \\\\", n_distinct(tr$athlete)),
  row("Age at first test (years)", first$age, 1), row("Body mass at first test (kg)", first$body_mass_kg, 1),
  row("Trials per athlete", tpa, 1), row("Sessions per athlete", as.vector(ses_ath), 1), "\\addlinespace",
  sprintf("\\multicolumn{8}{@{}l}{\\textit{Sessions ($n$ = %d)}} \\\\", n_distinct(tr$test_code)), row("Trials per session", tps, 1), "\\addlinespace",
  sprintf("\\multicolumn{8}{@{}l}{\\textit{Trials ($n$ = %d)}} \\\\", n),
  row("Jump height (cm)", tr$jump_height_cm, 1), row("Concentric peak force (BW)", tr$conc_peak_force_n / (tr$body_mass_kg * G), 2),
  row("Eccentric braking impulse (N\\,s)", tr$ecc_braking_impulse_ns, 1), row("Concentric impulse, first 100\\,ms (N\\,s)", tr$conc_impulse_100ms_ns, 1),
  row("Peak landing force (BW)", tr$peak_landing_force_n / (tr$body_mass_kg * G), 2), row("Take-off duration (s)", tr$contraction_time_s, 2),
  row("Landing duration (s)$^{a}$", tr$landing_to_lowcom_s, 2),
  row("Native samples, take-off$^{b}$", round(tr$contraction_time_s * tr$native_fs), 0), row("Native samples, landing$^{b}$", round(tr$landing_to_lowcom_s * tr$native_fs), 0),
  "\\bottomrule", "\\end{tabular}", "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf("\\item \\textit{Note.} BW = multiples of body weight. Take-off runs from movement onset to take-off (vendor contraction time). %d trials were recorded at 500\\,Hz and %d at 1000\\,Hz. $^{a}$Touch-down to the lowest point of the centre of mass. $^{b}$Phase duration multiplied by the sampling rate; each phase is resampled to 101 nodes.", sum(tr$native_fs == 500), sum(tr$native_fs == 1000)),
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
wtab(t1, "tab1_sample")
# Table 2: FoSR
lab <- c(jump_height = "Jump height", age = "Age", body_mass = "Body mass")
t2rows <- c()
for (b in c("takeoff", "landing")) {
  t2rows <- c(t2rows, sprintf("\\multicolumn{5}{@{}l}{\\textit{%s}} \\\\", ifelse(b == "takeoff", "Take-off (onset to take-off)", "Landing (touch-down to lowest centre of mass)")))
  for (term in names(lab)) { s1 <- F1 %>% filter(model == "A", block == b, term == !!term); s2r <- F2 %>% filter(model == "A", block == b, term == !!term); p <- pk(b, term)
    t2rows <- c(t2rows, sprintf("\\quad %s & %s & %s & %s & %s [%s, %s] at %d\\%% \\\\", lab[term], rng(s1$sig_simultaneous), rng(s2r$sig_sim_pffr), rng(s2r$supported_both),
      neg(f(p$est, 2)), neg(f(p$lo_pw, 2)), neg(f(p$hi_pw, 2)), p$pct)) }
  for (term in c("jh_within", "jh_between")) { r <- w3(b, term); cc <- ci3(r$ci) / sdj
    t2rows <- c(t2rows, sprintf("\\quad Jump height, %s athlete$^{b}$ & %s & {--} & {--} & %s [%s, %s] per cm at %d\\%% \\\\", ifelse(term == "jh_within", "within", "between"),
      rng(r$sig_sim), f(r$max_effect_per_SD_JH / sdj, 3), f(cc[1], 3), f(cc[2], 3), r$at_pct)) }
  if (b == "takeoff") t2rows <- c(t2rows, "\\addlinespace")
}
t2rows <- gsub("none", "{none}", t2rows)
t2 <- c("\\begin{table}[!htbp]", "\\centering", "\\begin{threeparttable}", "\\caption{Where along each phase the predictors are associated with force (function-on-scalar regression)}", "\\label{tab:fosr}",
  "\\footnotesize\\setlength{\\tabcolsep}{3pt}", "\\begin{tabularx}{\\linewidth}{@{}>{\\raggedright\\arraybackslash}X >{\\raggedright\\arraybackslash}p{2.2cm} >{\\raggedright\\arraybackslash}p{2.2cm} >{\\raggedright\\arraybackslash}p{2.2cm} >{\\raggedright\\arraybackslash}p{3.3cm}@{}}", "\\toprule",
  " & \\multicolumn{3}{l}{Simultaneous 95\\% band excludes zero (\\% of phase)} & \\\\", "\\cmidrule(lr){2-4}",
  "Predictor & Athlete bootstrap & Mixed model & Both (claimed) & Largest effect, BW per SD [95\\% CI]$^{a}$ \\\\", "\\midrule", t2rows,
  "\\bottomrule", "\\end{tabularx}", "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf("\\item \\textit{Note.} Model: force $\\sim$ jump height + age + body mass, predictors standardised (1 SD = %s\\,cm, %s years, %s\\,kg). Athlete bootstrap: pointwise least squares with 2000 resamples of athletes. Mixed model: penalised functional regression with athlete and session random curves, fitted on every second node. $^{a}$Least-squares estimate with pointwise 95\\%% bootstrap interval. $^{b}$Jump height split into the athlete's mean and the trial's deviation from it; effects per cm with 95\\%% bootstrap intervals.", f(sd(tr$jump_height_cm)), f(sd(tr$age)), f(sd(tr$body_mass_kg))),
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
wtab(t2, "tab2_fosr")
# Table 3: permutation tests
t3rows <- c()
for (cn in c("a", "b")) for (b in c("takeoff", "landing")) {
  raws <- S1 %>% filter(substr(contrast, 1, 1) == cn, block == b, p < 0.05); r <- s3(cn, b); adj <- sig2(s2(cn, b))
  lab3 <- ifelse(cn == "a", sprintf("Top vs bottom jump-height tertile (%d vs %d)", sum(am$jh >= tert[2]), sum(am$jh <= tert[1])), sprintf("18 and over vs under 18 (%d vs %d)", sum(am$age >= 18), sum(am$age < 18)))
  rawtxt <- if (nrow(raws)) paste(sprintf("%s (%s)", rng(raws$range), ifelse(raws$p < 0.001, "$<$0.001", f(raws$p, 3))), collapse = "; ") else sprintf("none (min $p$ = %s)", f(min(S1$p[substr(S1$contrast, 1, 1) == cn & S1$block == b]), 2))
  adjtxt <- if (nrow(adj)) paste(sprintf("%s (%s)", rng(adj$range), ifelse(adj$p < 0.001, "$<$0.001", f(adj$p, 3))), collapse = "; ") else sprintf("none (min $p$ = %s)", f(min(s2(cn, b)$p, na.rm = TRUE), 2))
  eff <- if (nrow(r)) sprintf("%s [%s, %s] at %d\\%%", f(r$diff_bw, 2), f(r$ci_lo, 2), f(r$ci_hi, 2), r$peak_pct) else "{--}"
  gg <- if (nrow(r)) sprintf("%s [%s, %s]", f(r$hedges_g, 2), f(r$g_ci_lo, 2), f(r$g_ci_hi, 2)) else "{--}"
  t3rows <- c(t3rows, sprintf("%s & %s & %s & %s & %s & %s \\\\", if (b == "takeoff") lab3 else "", ifelse(b == "takeoff", "Take-off", "Landing"), rawtxt, eff, gg, adjtxt))
  if (cn == "a" && b == "landing") t3rows <- c(t3rows, "\\addlinespace")
}
t3 <- c("\\begin{table}[!htbp]", "\\centering", "\\begin{threeparttable}", "\\caption{Pointwise group comparisons of athlete-mean curves with family-wise error control}", "\\label{tab:spm}",
  "\\footnotesize\\setlength{\\tabcolsep}{3pt}", "\\begin{tabularx}{\\linewidth}{@{}>{\\raggedright\\arraybackslash}p{2.6cm} l >{\\raggedright\\arraybackslash}X >{\\raggedright\\arraybackslash}p{2.5cm} >{\\raggedright\\arraybackslash}p{2.1cm} >{\\raggedright\\arraybackslash}X@{}}", "\\toprule",
  "Contrast (athletes) & Phase & Significant region, \\% ($p$) & Difference at peak, BW [95\\% CI] & Hedges' $g$ [95\\% CI] & Region after adjustment, \\% ($p$)$^{a}$ \\\\", "\\midrule", t3rows,
  "\\bottomrule", "\\end{tabularx}", "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf("\\item \\textit{Note.} One mean curve per athlete. Clusters of adjacent nodes with $|t|$ above the two-sided 5\\%% threshold were tested against the permutation distribution of the largest cluster mass over the whole phase (5000 permutations of athlete labels), which controls the family-wise error rate over the 101 nodes. Differences are first group minus second, at the node of largest $|t|$, with 95\\%% intervals from 2000 bootstrap resamples of athletes within groups. Bonferroni threshold across the four primary tests: $p$ < %s. $^{a}$Tertile contrast adjusted for athlete-mean age and body mass; age contrast adjusted for body mass and jump height (Freedman--Lane permutation).", f(0.05 / 4, 4)),
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
wtab(t3, "tab3_spm")
# Table 4: profiles
c2 <- function(b) C2[C2$block == b, ]; c3 <- function(b) C3[C3$block == b, ]; c4 <- function(b) C4[C4$block == b, ]
v4 <- function(lab, fn) sprintf("%s & %s & %s \\\\", lab, fn("takeoff"), fn("landing"))
t4 <- c("\\begin{table}[!htbp]", "\\centering", "\\begin{threeparttable}", "\\caption{Curve profiles: description, validation and stability within athletes}", "\\label{tab:profiles}",
  "\\footnotesize\\setlength{\\tabcolsep}{4pt}", "\\begin{tabularx}{\\linewidth}{@{}>{\\raggedright\\arraybackslash}X ll@{}}", "\\toprule", " & Take-off & Landing \\\\", "\\midrule",
  "\\multicolumn{3}{@{}l}{\\textit{Description}} \\\\",
  v4("\\quad Profile 1 / profile 2 (trials)", function(b) sprintf("%d / %d", c2(b)$n_trials[1], c2(b)$n_trials[2])),
  v4("\\quad Mean jump height (cm)", function(b) sprintf("%s / %s ($p$ %s)$^{a}$", f(c2(b)$jump_height_cm_mean[1]), f(c2(b)$jump_height_cm_mean[2]), pr(c2(b)$p_jump_height_lmm[1]))),
  v4("\\quad Mean take-off duration (s)", function(b) sprintf("%s / %s", f(c2(b)$contraction_time_s_mean[1], 2), f(c2(b)$contraction_time_s_mean[2], 2))),
  v4("\\quad Mean landing duration (s)", function(b) sprintf("%s / %s", f(c2(b)$landing_to_lowcom_s_mean[1], 2), f(c2(b)$landing_to_lowcom_s_mean[2], 2))),
  "\\addlinespace", "\\multicolumn{3}{@{}l}{\\textit{Is there cluster structure?}} \\\\",
  v4("\\quad Mean silhouette", function(b) f(c4(b)$silhouette, 2)),
  v4("\\quad Number of groups preferred by the gap statistic$^{b}$", function(b) as.character(c4(b)$gap_k_firstSEmax)),
  v4("\\quad Dip test of unimodality, first FPC score ($p$)", function(b) f(c4(b)$dip_FPC1_p, 2)),
  v4("\\quad Bootstrap Jaccard similarity (range over profiles)", function(b) sprintf("%s--%s", f(min(C5$jaccard_mean[C5$block == b]), 2), f(max(C5$jaccard_mean[C5$block == b]), 2))),
  "\\addlinespace", "\\multicolumn{3}{@{}l}{\\textit{Stability}} \\\\",
  v4(sprintf("\\quad Same profile in every session, \\%% (athletes with $\\geq$ 2 sessions, $n$ = %d)", c3("landing")$athletes_multi), function(b) sprintf("%s", f(100 * c3(b)$share_same_all_sessions, 0))),
  v4("\\quad Expected by chance, \\% (permutation $p$)", function(b) sprintf("%s (%s)", f(100 * c3(b)$chance_perm_mean, 0), ifelse(c3(b)$p_perm < 0.001, "$<$0.001", f(c3(b)$p_perm, 3)))),
  v4("\\quad Two trials in one session share a profile, \\% (chance)", function(b) sprintf("%s (%s)", f(100 * c3(b)$within_session_trial_agreement, 0), f(100 * c3(b)$within_session_chance, 0))),
  v4("\\quad Profile mix in the matched-height band, \\% (all trials)$^{c}$", function(b) { m <- M1[M1$block == b, ]; sprintf("%s / %s (%s / %s)", f(m$pct_band[1], 0), f(m$pct_band[2], 0), f(m$pct_all[1], 0), f(m$pct_all[2], 0)) }),
  v4("\\quad Agreement with profiles after elastic alignment (ARI)", function(b) if (b == "landing") f(R1$ari_k2_vs_unaligned[1], 2) else "{--}"),
  "\\bottomrule", "\\end{tabularx}", "\\begin{tablenotes}[flushleft]\\footnotesize",
  sprintf("\\item \\textit{Note.} Profiles from $k$-means ($k$ = 2) on functional principal component (FPC) scores covering at least 90\\%% of variance, computed separately for each phase. $^{a}$Linear mixed model with an athlete random intercept. $^{b}$Candidates 1 to 6; 1 means no cluster structure. $^{c}$Trials with jump height between the 45th and 55th percentiles (%s--%s\\,cm, %d trials).", f(M2$lo_cm), f(M2$hi_cm), M2$n_trials),
  "\\end{tablenotes}", "\\end{threeparttable}", "\\end{table}")
wtab(t4, "tab4_profiles")

# ---------------- figures ----------------
theme_set(theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
  strip.background = element_rect(fill = "grey92", colour = "grey60"), plot.title = element_text(face = "bold", size = 9), legend.position = "bottom",
  legend.key.width = unit(8, "mm"), plot.tag = element_text(face = "bold", size = 10)))
PH <- c(takeoff = "Take-off (onset to take-off)", landing = "Landing (touch-down to lowest COM)")
save2 <- function(p, name, w = 160, h = 120) {
  ggsave(file.path(PAPER, "figures", paste0(name, ".pdf")), p, width = w/25.4, height = h/25.4, device = cairo_pdf)
  ggsave(file.path("paper_png", paste0(name, ".png")), p, width = w/25.4, height = h/25.4, dpi = 300, bg = "white") }
runs_df <- function(lg, x) { if (!any(lg)) return(data.frame(xmin = numeric(), xmax = numeric())); r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1
  data.frame(xmin = x[s[r$values]], xmax = x[e[r$values]]) }
# Fig 1
mc <- bind_rows(lapply(names(Y), function(b) data.frame(phase = PH[b], pct = pct, m = colMeans(Y[[b]]), s = apply(Y[[b]], 2, sd))))
mc$phase <- factor(mc$phase, PH)
p1a <- ggplot(mc, aes(pct, m)) + geom_ribbon(aes(ymin = m - s, ymax = m + s), fill = "grey80") + geom_line(linewidth = 0.6) +
  geom_hline(yintercept = 1, linetype = "dotted", linewidth = 0.3) + facet_wrap(~phase, scales = "free_y") + labs(x = NULL, y = "Force (BW)", tag = "A")
co <- F1c %>% filter(model == "A", term == "jump_height") %>% mutate(phase = factor(PH[block], PH))
F2c <- T("F2_pffr_coefficients.csv")
supp <- bind_rows(lapply(names(PH), function(b) { o <- co %>% filter(block == b); m <- F2c %>% filter(model == "A", block == b, term == "jump_height")
  s_ols <- (o$lo_sim > 0 | o$hi_sim < 0)[match(m$pct, o$pct)]; s_mm <- m$lo_sim > 0 | m$hi_sim < 0
  r <- runs_df(s_ols & s_mm, m$pct); if (nrow(r)) { r$xmin <- r$xmin - 1; r$xmax <- r$xmax + 1; r$phase <- factor(PH[b], PH) }; r }))
p1b <- ggplot(co, aes(pct, est)) + geom_rect(data = supp, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey90") +
  geom_ribbon(aes(ymin = lo_sim, ymax = hi_sim), fill = "grey75") + geom_ribbon(aes(ymin = lo_pw, ymax = hi_pw), fill = "grey50") +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.3) + geom_line(linewidth = 0.6) + facet_wrap(~phase, scales = "free_y") +
  labs(x = "% of phase", y = "Jump-height effect (BW per SD)", tag = "B")
save2(p1a / p1b, "Fig1_mean_curves_fosr", 160, 130)
# Fig 2
amean <- function(M) { s <- rowsum(M, tr$athlete); (s / as.vector(table(tr$athlete)[rownames(s)]))[am$athlete, ] }
S4 <- T("S4_delta_curves.csv") %>% filter(substr(contrast, 1, 1) == "a") %>% mutate(phase = factor(ifelse(grepl("^Take", block), PH["takeoff"], PH["landing"]), PH))
sel <- am$jh <= tert[1] | am$jh >= tert[2]
gm <- bind_rows(lapply(names(Y), function(b) { A <- amean(Y[[b]])[sel, ]; g <- am$jh[sel] >= tert[2]
  data.frame(phase = PH[b], pct = rep(pct, 2), f = c(colMeans(A[g, ]), colMeans(A[!g, ])),
    grp = rep(c(sprintf("Top tertile (n = %d)", sum(g)), sprintf("Bottom tertile (n = %d)", sum(!g))), each = 101)) })) %>% mutate(phase = factor(phase, PH))
shade <- S1 %>% filter(substr(contrast, 1, 1) == "a", p < 0.05) %>% mutate(phase = factor(PH[block], PH), xmin = start - 1, xmax = end - 1)
p2a <- ggplot(gm, aes(pct, f, linetype = grp)) + geom_rect(data = shade, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey88") +
  geom_line(linewidth = 0.6) + facet_wrap(~phase, scales = "free_y") + scale_linetype_manual(values = c("22", "solid")) + labs(x = NULL, y = "Force (BW)", linetype = NULL, tag = "A")
p2b <- ggplot(S4, aes(pct, d)) + geom_rect(data = shade, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey88") +
  geom_ribbon(aes(ymin = lo_sim, ymax = hi_sim), fill = "grey75") + geom_ribbon(aes(ymin = lo_pw, ymax = hi_pw), fill = "grey50") +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.3) + geom_line(linewidth = 0.6) + facet_wrap(~phase, scales = "free_y") +
  labs(x = "% of phase", y = "Top minus bottom (BW)", tag = "B")
save2(p2a / p2b + plot_layout(heights = c(1.1, 1)), "Fig2_tertile_comparison", 160, 135)
# Fig 3
inb <- tr$jump_height_cm >= M2$lo_cm & tr$jump_height_cm <= M2$hi_cm
f3 <- lapply(names(Y), function(b) { cl <- prof[[paste0(b, "_profile")]][inb]
  labs_ <- sprintf("Profile %d (%d trials)", cl, ave(cl, cl, FUN = length))
  d <- data.frame(id = rep(which(inb), each = 101), pct = rep(pct, sum(inb)), f = as.vector(t(Y[[b]][inb, ])), prof = rep(labs_, each = 101))
  mm <- d %>% group_by(prof, pct) %>% summarise(f = mean(f), .groups = "drop")
  ggplot(d, aes(pct, f, group = id)) + geom_line(colour = "grey70", linewidth = 0.2) + geom_line(data = mm, aes(pct, f, group = prof), inherit.aes = FALSE, linewidth = 0.9) +
    facet_wrap(~prof, nrow = 1) + labs(x = "% of phase", y = "Force (BW)", title = PH[b]) })
save2(f3[[1]] / f3[[2]], "Fig3_matched_height", 160, 140)
# Fig 4
f4 <- lapply(names(PH), function(b) { d <- data.frame(x = prof[[paste0(b, "_fpc1")]], y = prof[[paste0(b, "_fpc2")]], p = factor(paste("Profile", prof[[paste0(b, "_profile")]])))
  s <- ggplot(d, aes(x, y, shape = p, fill = p)) + geom_point(size = 1.1, stroke = 0.25, colour = "black") + scale_shape_manual(values = c(21, 24)) +
    scale_fill_manual(values = c("grey25", "grey80")) + labs(x = "FPC1 score", y = "FPC2 score", shape = NULL, fill = NULL, title = PH[b])
  h <- ggplot(d, aes(x, fill = p)) + geom_histogram(bins = 40, colour = "white", linewidth = 0.2) + scale_fill_manual(values = c("grey25", "grey80"), guide = "none") + labs(x = "FPC1 score", y = "Trials")
  s / h + plot_layout(heights = c(1.3, 1)) })
save2(wrap_plots(f4, ncol = 2) + plot_layout(guides = "collect") & theme(legend.position = "bottom"), "Fig4_profile_continuum", 160, 130)

# ---------------- dataset (Excel) ----------------
pj <- prof %>% select(athlete, test_code, trial_no, takeoff_profile, landing_profile)
dat <- raw %>% transmute(athlete_id = athlete, session_id = test_code, trial_id = trial_code, trial_no, age_years = age, body_mass_kg, quiet_stance_mass_kg = round(quiet_mass_kg, 2),
  sampling_rate_hz = native_fs, jump_height_cm = round(jump_height_cm, 2), conc_peak_force_n = round(conc_peak_force_n, 1), ecc_braking_impulse_ns = round(ecc_braking_impulse_ns, 2),
  conc_impulse_100ms_ns = round(conc_impulse_100ms_ns, 2), peak_landing_force_n = round(peak_landing_force_n, 1), cm_depth_cm = round(cm_depth_cm, 2),
  takeoff_duration_s = contraction_time_s, flight_time_s, landing_duration_s = landing_to_lowcom_s, mean_flight_force_n = round(flight_force_n, 2),
  qc_included = qc_pass, qc_reason = ifelse(qc_pass, "", paste0(ifelse(fail_r1, "R1 ", ""), ifelse(fail_r2, "R2 ", ""), ifelse(fail_r3, "R3 ", ""), ifelse(fail_r4, "R4 ", ""), ifelse(fail_r5, "R5", "")))) %>%
  left_join(pj, by = c("athlete_id" = "athlete", "session_id" = "test_code", "trial_no"))
dict <- data.frame(variable = names(dat), description = c(
  "Pseudonymous athlete identifier", "Pseudonymous test-session identifier", "Pseudonymous trial identifier", "Trial number within the session",
  "Age at the session (years)", "Body mass recorded by the force-plate software (kg)", "Mass estimated from the quiet-stance force before the jump (kg)",
  "Native sampling rate of the force plates (Hz)", "Jump height from flight time (cm)", "Concentric peak force (N)", "Eccentric braking impulse (N s)",
  "Impulse over the first 100 ms of the concentric phase (N s)", "Peak landing force (N)", "Countermovement depth, centre-of-mass displacement (cm, negative downwards)",
  "Take-off phase duration: movement onset to take-off (s)", "Flight time (s)", "Landing phase duration: touch-down to lowest centre of mass (s)",
  "Mean force recorded during flight (N; quality-control rule R3)", "TRUE if the trial passed all quality-control rules and is analysed",
  "Rules failed: R1 invalid body mass; R2 quiet-stance mass more than 5% from body mass; R3 mean flight force above 50 N; R4 missing metric or age; R5 lowest centre-of-mass point not found",
  "Take-off curve profile from k-means on FPC scores (1 or 2; analysed trials only)", "Landing curve profile from k-means on FPC scores (1 or 2; analysed trials only)"))
notes <- data.frame(note = c("IIMB / BAICONF 2026 dataset: one row per countermovement-jump trial (all trials before quality control; analysed trials have qc_included = TRUE).",
  "The 101-node body-weight force curves for take-off and landing are not included in this workbook; they are in the de-identified CSV in the code repository, which reproduces every result.",
  "Raw force-time recordings are held by the testing centre under a non-disclosure agreement and cannot be shared.",
  "All identifiers are pseudonymous; no names, dates of birth or test dates are included."))
write_xlsx(list(data = dat, dictionary = dict, notes = notes), file.path(dirname(normalizePath(PAPER)), "IIMB_BAICONF2026_dataset.xlsx"))
cat("paper outputs written to", normalizePath(PAPER), "\n")
