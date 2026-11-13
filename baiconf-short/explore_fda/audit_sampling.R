#!/usr/bin/env Rscript
# =============================================================================
# SAMPLING AUDIT (run before the main exploratory FDA). De-identified CSV only.
#  (1) signal sampling: samples per phase vs 101-point grid, peak retention,
#      interpolation sensitivity, 500 vs 1000 Hz (athlete-level functional test)
#  (2) study sampling: contributions per athlete; equal-athlete weighting and
#      one-random-session-per-athlete re-estimation of the key FoSR estimates
#  (3) resampling checks: athlete-constancy of age group; Monte Carlo error
#  (4) selection: QC drops vs kept; coverage of age / body mass
# Output: tables/A*_*.csv, figs/figA*_*.png, audit_log.txt
# =============================================================================
t0 <- Sys.time()
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(ggplot2); library(patchwork) })
SEED <- 2026; set.seed(SEED); G <- 9.81
N_BOOT <- 2000; N_PERM <- 5000; N_DRAW <- 500
source("data_path.R"); DATA <- cmj_data_path()
dir.create("figs", showWarnings = FALSE); dir.create("tables", showWarnings = FALSE)
lc <- file("audit_log.txt", "w")
say <- function(...) { s <- sprintf(...); cat(s, "\n"); cat(s, "\n", file = lc) }
wcsv <- function(x, f) write.csv(x, file.path("tables", f), row.names = FALSE)
theme_set(theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(), strip.background = element_rect(fill = "grey92"),
  plot.title = element_text(face = "bold", size = 9), legend.position = "bottom"))
savefig <- function(p, f, w = 170, h = 100) ggsave(file.path("figs", f), p, width = w/25.4, height = h/25.4, dpi = 300, bg = "white")
pct <- 0:100
runs <- function(lg) { if (!any(lg)) return("none"); r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1
  paste(sprintf("%d-%d%%", pct[s[r$values]], pct[e[r$values]]), collapse = ", ") }

raw <- read.csv(DATA)
raw <- raw %>% mutate(
  fail_r1 = is.na(body_mass_kg) | body_mass_kg <= 0,
  fail_r2 = !fail_r1 & abs(quiet_mass_kg - body_mass_kg) / body_mass_kg > 0.05,
  fail_r3 = abs(flight_force_n) > 50,
  fail_r4 = is.na(age) | is.na(jump_height_cm) | is.na(conc_peak_force_n) | is.na(ecc_braking_impulse_ns) | is.na(conc_impulse_100ms_ns),
  fail_r5 = is.na(ldc_050),
  kept = !(fail_r1 | fail_r2 | fail_r3 | fail_r4 | fail_r5))
tr <- raw %>% filter(kept)
say("Loaded %d trials / %d athletes / %d sessions; kept %d / %d / %d", nrow(raw), n_distinct(raw$athlete), n_distinct(raw$test_code),
    nrow(tr), n_distinct(tr$athlete), n_distinct(tr$test_code))
TO <- as.matrix(tr[, grep("^to_[0-9]", names(tr))]); LD <- as.matrix(tr[, grep("^ldc_[0-9]", names(tr))])
bw <- tr$body_mass_kg * G; Y <- list(takeoff = TO / bw, landing = LD / bw)

# ---------------- (1) SIGNAL SAMPLING ----------------
say("\n(1) Signal sampling")
say("   native_fs (kept trials): %s", paste(sprintf("%s Hz: %d", names(table(tr$native_fs)), table(tr$native_fs)), collapse = "; "))
tr <- tr %>% mutate(n_to = round(contraction_time_s * native_fs), n_ld = round(landing_to_lowcom_s * native_fs))
smp <- tr %>% select(native_fs, n_to, n_ld, contraction_time_s, landing_to_lowcom_s) %>%
  pivot_longer(c(n_to, n_ld), names_to = "phase", values_to = "n_samples") %>%
  group_by(phase, native_fs) %>% summarise(trials = n(), min = min(n_samples), q25 = quantile(n_samples, .25), median = median(n_samples),
    q75 = quantile(n_samples, .75), max = max(n_samples), n_below_101 = sum(n_samples < 101), n_above_505 = sum(n_samples > 505), .groups = "drop") %>%
  bind_rows(tr %>% pivot_longer(c(n_to, n_ld), names_to = "phase", values_to = "n_samples") %>% group_by(phase) %>%
    summarise(native_fs = NA, trials = n(), min = min(n_samples), q25 = quantile(n_samples, .25), median = median(n_samples),
      q75 = quantile(n_samples, .75), max = max(n_samples), n_below_101 = sum(n_samples < 101), n_above_505 = sum(n_samples > 505)))
wcsv(smp, "A1_samples_per_phase.csv"); print(smp, width = 200); capture.output(print(as.data.frame(smp)), file = lc)
say("   NOTE: take-off duration taken as vendor contraction time (onset to take-off); assumes the curve window matches it.")
say("   grid spacing: take-off median %.1f ms (max %.1f); landing median %.1f ms (max %.1f)",
    1000*median(tr$contraction_time_s)/100, 1000*max(tr$contraction_time_s)/100, 1000*median(tr$landing_to_lowcom_s)/100, 1000*max(tr$landing_to_lowcom_s)/100)
# peak retention: max of 101-point curve vs vendor peak (computed on the native signal)
tr$ret_ld <- apply(LD, 1, max) / tr$peak_landing_force_n
tr$ret_to <- apply(TO, 1, max) / tr$conc_peak_force_n
ret <- tr %>% summarise(across(c(ret_ld, ret_to), list(min = min, p01 = ~quantile(.x, .01), p05 = ~quantile(.x, .05), median = median, max = max,
        share_below_0.95 = ~mean(.x < 0.95), share_below_0.98 = ~mean(.x < 0.98))))
wcsv(ret, "A2_peak_retention.csv")
say("   landing peak retained (curve max / vendor peak landing force): median %.4f, 1st pct %.3f, min %.3f; %.1f%% of trials < 0.95, %.1f%% < 0.98",
    ret$ret_ld_median, ret$ret_ld_p01, ret$ret_ld_min, 100*ret$ret_ld_share_below_0.95, 100*ret$ret_ld_share_below_0.98)
say("   take-off: curve max / vendor concentric peak force: median %.4f, min %.3f, max %.3f (should be ~1 if peak is in window)",
    ret$ret_to_median, ret$ret_to_min, ret$ret_to_max)
say("   landing retention vs samples per landing: Spearman rho = %.2f; by fs: 500 Hz median %.4f, 1000 Hz median %.4f",
    cor(tr$ret_ld, tr$n_ld, method = "spearman"), median(tr$ret_ld[tr$native_fs == 500]), median(tr$ret_ld[tr$native_fs == 1000]))
say("   landing retention vs landing duration: Spearman rho = %.2f", cor(tr$ret_ld, tr$landing_to_lowcom_s, method = "spearman"))
# interpolation sensitivity on the stored grid: linear vs natural cubic spline at the 100 midpoints
mid <- seq(0.5, 99.5, 1)
interp_gap <- sapply(names(Y), function(b) { M <- Y[[b]]
  d <- t(apply(M, 1, function(y) spline(pct, y, xout = mid, method = "fmm")$y - approx(pct, y, xout = mid)$y))
  c(median_abs = median(abs(d)), p99_abs = quantile(abs(d), .99), max_abs = max(abs(d)),
    trial_max_median = median(apply(abs(d), 1, max))) })
wcsv(data.frame(stat = rownames(interp_gap), interp_gap), "A3_linear_vs_spline_midpoints.csv")
say("   linear vs spline at grid midpoints (x BW): take-off median %.4f / 99th pct %.4f / max %.3f; landing median %.4f / 99th pct %.4f / max %.3f",
    interp_gap[1, 1], interp_gap[2, 1], interp_gap[3, 1], interp_gap[1, 2], interp_gap[2, 2], interp_gap[3, 2])
# grid-resolution sensitivity: decimate 101 -> 51 points and linearly re-expand; how much of the signal is lost?
dec <- sapply(names(Y), function(b) { M <- Y[[b]]; idx <- seq(1, 101, 2)
  R <- t(apply(M[, idx], 1, function(y) approx(pct[idx], y, xout = pct)$y)); e <- abs(R - M)
  c(median_abs = median(e), p99_abs = quantile(e, .99), peak_loss_median = median(1 - apply(R, 1, max) / apply(M, 1, max)),
    peak_loss_p99 = quantile(1 - apply(R, 1, max) / apply(M, 1, max), .99)) })
wcsv(data.frame(stat = rownames(dec), dec), "A3b_decimation_51pt.csv")
say("   halving the grid (51 pts) -> peak loss median %.2f%% (99th pct %.2f%%) take-off; %.2f%% (99th pct %.2f%%) landing",
    100*dec[3, 1], 100*dec[4, 1], 100*dec[3, 2], 100*dec[4, 2])

# 500 vs 1000 Hz: athlete-level functional test (athletes recorded at one rate only), cluster-mass permutation
fs_ath <- tr %>% group_by(athlete) %>% summarise(nfs = n_distinct(native_fs), fs = first(native_fs), jh = mean(jump_height_cm),
                                              age = mean(age), bm = mean(body_mass_kg), n = n(), .groups = "drop")
say("   athletes with both rates: %d (excluded from the fs test)", sum(fs_ath$nfs > 1))
one <- fs_ath %>% filter(nfs == 1)
say("   500 Hz athletes %d (trials %d) vs 1000 Hz athletes %d; athlete means 500 vs 1000 Hz: JH %.1f vs %.1f cm, age %.1f vs %.1f, BM %.1f vs %.1f; landing duration (trial) %.3f vs %.3f s",
    sum(one$fs == 500), sum(tr$native_fs == 500), sum(one$fs == 1000), mean(one$jh[one$fs == 500]), mean(one$jh[one$fs == 1000]),
    mean(one$age[one$fs == 500]), mean(one$age[one$fs == 1000]), mean(one$bm[one$fs == 500]), mean(one$bm[one$fs == 1000]),
    mean(tr$landing_to_lowcom_s[tr$native_fs == 500]), mean(tr$landing_to_lowcom_s[tr$native_fs == 1000]))
tstat2 <- function(M, g) { a <- M[g, , drop = FALSE]; b <- M[!g, , drop = FALSE]
  (colMeans(a) - colMeans(b)) / sqrt(apply(a, 2, var)/nrow(a) + apply(b, 2, var)/nrow(b)) }
clmass <- function(t, thr) { lg <- abs(t) > thr; if (!any(lg)) return(data.frame(start = integer(), end = integer(), mass = numeric()))
  sg <- sign(t) * lg; r <- rle(sg); e <- cumsum(r$lengths); s <- e - r$lengths + 1; k <- r$values != 0
  data.frame(start = s[k], end = e[k], mass = mapply(function(a, b) sum(abs(t[a:b])), s[k], e[k])) }
spm_perm <- function(M, g, nperm = N_PERM) {
  t <- tstat2(M, g); thr <- qt(0.975, nrow(M) - 2); obs <- clmass(t, thr)
  mx <- replicate(nperm, { cm <- clmass(tstat2(M, sample(g)), thr); if (nrow(cm)) max(cm$mass) else 0 })
  obs$p <- as.numeric(sapply(obs$mass, function(m) (1 + sum(mx >= m)) / (1 + nperm))); obs$p_mc_se <- sqrt(obs$p * (1 - obs$p) / nperm)
  obs$range <- if (nrow(obs)) sprintf("%d-%d%%", pct[obs$start], pct[obs$end]) else character(); list(t = t, obs = obs) }
ath_mean <- function(M, ids) { s <- rowsum(M, ids); s / as.vector(table(ids)[rownames(s)]) }
fs_rows <- list()
for (b in names(Y)) {
  A <- ath_mean(Y[[b]], tr$athlete)[one$athlete, ]; g <- one$fs == 500
  set.seed(SEED); r <- spm_perm(A, g)
  # adjusted for jump height, age, body mass: residualise athlete-mean curves first
  Xa <- cbind(1, scale(one$jh), scale(one$age), scale(one$bm)); Ar <- A - Xa %*% qr.solve(Xa, A)
  set.seed(SEED); ra <- spm_perm(Ar, g)
  for (lab in c("raw", "adjusted")) { o <- if (lab == "raw") r$obs else ra$obs
    fs_rows[[paste(b, lab)]] <- if (nrow(o)) cbind(block = b, version = lab, o) else data.frame(block = b, version = lab, range = "none")
    say("   500 vs 1000 Hz %s %-8s: %s", lab, b, if (nrow(o)) paste(sprintf("%s (p=%.4f)", o$range, o$p), collapse = "; ") else "no supra-threshold cluster") }
}
wcsv(bind_rows(fs_rows), "A4_fs_500_vs_1000_spm.csv")

# ---------------- (2) STUDY SAMPLING ----------------
say("\n(2) Study sampling")
ct <- tr %>% group_by(athlete) %>% summarise(trials = n(), sessions = n_distinct(test_code), .groups = "drop")
ts <- tr %>% count(test_code)
say("   trials per athlete: %s", paste(sprintf("%s:%d", names(table(ct$trials)), table(ct$trials)), collapse = " "))
say("   sessions per athlete: %s", paste(sprintf("%s:%d", names(table(ct$sessions)), table(ct$sessions)), collapse = " "))
say("   trials per session: %s", paste(sprintf("%s:%d", names(table(ts$n)), table(ts$n)), collapse = " "))
top10 <- sort(ct$trials, decreasing = TRUE)[1:ceiling(0.1 * nrow(ct))]
say("   top 10%% of athletes (%d) contribute %.1f%% of trials; Gini of trials per athlete = %.2f", length(top10), 100*sum(top10)/nrow(tr),
    { x <- sort(ct$trials); n <- length(x); sum((2*seq_len(n) - n - 1) * x) / (n * sum(x)) })
wcsv(ct, "A5_contributions_per_athlete.csv")
# Key estimates: FoSR model A (jump height, age, body mass) coefficient curves under 3 weightings
z <- function(v) (v - mean(v)) / sd(v)
X <- cbind(1, jh = z(tr$jump_height_cm), age = z(tr$age), bm = z(tr$body_mass_kg))
ni <- as.vector(table(tr$athlete)[tr$athlete]); w <- 1 / ni
ath_idx <- split(seq_len(nrow(tr)), tr$athlete)
wls <- function(X, Yb, w) { sw <- sqrt(w); qr.solve(X * sw, Yb * sw) }
sens_rows <- list(); sens_curves <- list()
for (b in names(Y)) {
  Yb <- Y[[b]]
  est <- list(trial_weighted = wls(X, Yb, rep(1, nrow(X))), athlete_weighted = wls(X, Yb, w))
  # one random session per athlete: N_DRAW draws
  ses_by_ath <- split(tr$test_code, tr$athlete)
  draws <- replicate(N_DRAW, { s <- sapply(ses_by_ath, function(v) { u <- unique(v); u[sample.int(length(u), 1)] })
    i <- which(tr$test_code %in% s); wls(X[i, ], Yb[i, ], 1 / as.vector(table(tr$athlete[i])[tr$athlete[i]])) }, simplify = "array")
  est$one_session_median <- apply(draws, c(1, 2), median)
  # bootstrap (athletes) simultaneous bands for each weighting; for one-session use the first draw's design
  set.seed(SEED + 1)
  bsets <- replicate(N_BOOT, unlist(ath_idx[sample(length(ath_idx), replace = TRUE)], use.names = FALSE), simplify = FALSE)
  for (wt in c("trial_weighted", "athlete_weighted")) {
    ww <- if (wt == "trial_weighted") rep(1, nrow(X)) else w
    bt <- array(NA, c(N_BOOT, 4, 101))
    for (k in seq_len(N_BOOT)) { s <- bsets[[k]]; nb <- as.vector(table(s)[as.character(s)]); bt[k, , ] <- wls(X[s, ], Yb[s, ], ww[s]) }
    for (j in 2:3) { e <- est[[wt]][j, ]; se <- apply(bt[, j, ], 2, sd)
      cs <- quantile(apply(abs(sweep(bt[, j, ], 2, e)) / rep(se, each = N_BOOT), 1, max), .95)
      sens_rows[[paste(b, wt, j)]] <- data.frame(block = b, weighting = wt, term = colnames(X)[j], sim_crit = cs,
        sig_sim = runs(e - cs*se > 0 | e + cs*se < 0), max_abs = max(abs(e)), at = pct[which.max(abs(e))])
      sens_curves[[paste(b, wt, j)]] <- data.frame(block = b, weighting = wt, term = colnames(X)[j], pct = pct, est = e, lo = e - cs*se, hi = e + cs*se) }
  }
  for (j in 2:3) { e <- est$one_session_median[j, ]
    lo <- apply(draws[j, , ], 1, quantile, .025); hi <- apply(draws[j, , ], 1, quantile, .975)
    sens_curves[[paste(b, "one", j)]] <- data.frame(block = b, weighting = "one_session_median", term = colnames(X)[j], pct = pct, est = e, lo = lo, hi = hi)
    sens_rows[[paste(b, "one", j)]] <- data.frame(block = b, weighting = "one_session (median of 500 draws)", term = colnames(X)[j], sim_crit = NA,
      sig_sim = "see draw range", max_abs = max(abs(e)), at = pct[which.max(abs(e))])
    say("   %-8s %-3s corr(trial-wtd, athlete-wtd) = %.3f, corr(trial-wtd, one-session) = %.3f; max |diff| = %.3f / %.3f BW", b, colnames(X)[j],
        cor(est$trial_weighted[j, ], est$athlete_weighted[j, ]), cor(est$trial_weighted[j, ], e),
        max(abs(est$trial_weighted[j, ] - est$athlete_weighted[j, ])), max(abs(est$trial_weighted[j, ] - e))) }
}
sr <- bind_rows(sens_rows); wcsv(sr, "A6_weighting_sensitivity.csv"); capture.output(print(sr), file = lc); print(sr)
sc <- bind_rows(sens_curves); wcsv(sc, "A6_weighting_sensitivity_curves.csv")
p <- sc %>% mutate(term = recode(term, jh = "Jump height", age = "Age"),
  weighting = recode(weighting, trial_weighted = "Every trial (as analysed)", athlete_weighted = "Equal weight per athlete (1/n_i)",
                     one_session_median = "One random session per athlete (median, 95% draw range)")) %>%
  ggplot(aes(pct, est, linetype = weighting)) + geom_hline(yintercept = 0, linewidth = 0.2) + geom_line(linewidth = 0.55) +
  facet_grid(term ~ block, scales = "free_y", labeller = labeller(block = c(takeoff = "Take-off", landing = "Landing"))) +
  scale_linetype_manual(values = c("solid", "22", "12")) + guides(linetype = guide_legend(ncol = 1)) +
  labs(x = "% of phase", y = "Effect (x BW) per 1 SD", linetype = NULL, title = "Sensitivity of FoSR coefficients (model A) to how athletes are weighted")
savefig(p, "figA1_weighting_sensitivity.png", 170, 120)

# ---------------- (3) RESAMPLING CHECKS ----------------
say("\n(3) Resampling checks")
cross <- tr %>% group_by(athlete) %>% summarise(k = n_distinct(age >= 18), .groups = "drop")
say("   athletes whose trials straddle age 18: %d of %d -> age group (<18 / >=18) is %s within athlete in this sample",
    sum(cross$k > 1), nrow(cross), ifelse(any(cross$k > 1), "NOT constant", "constant"))
agev <- tr %>% group_by(athlete) %>% filter(n_distinct(test_code) > 1) %>% summarise(age_span = diff(range(age)), bm_span = diff(range(body_mass_kg)), .groups = "drop")
say("   athletes with >1 session: age span median %.1f y (max %.1f); body-mass span median %.1f kg (max %.1f) -- spans > 15 kg: %d (check for data-entry errors)",
    median(agev$age_span), max(agev$age_span), median(agev$bm_span), max(agev$bm_span), sum(agev$bm_span > 15))
say("   MC error: p-value SE with B = %d permutations is at most %.4f (p = 0.5); at p = 0.05 it is %.4f; smallest attainable p = %.5f",
    N_PERM, sqrt(.25/N_PERM), sqrt(.05*.95/N_PERM), 1/(N_PERM + 1))

# ---------------- (4) SELECTION ----------------
say("\n(4) Selection")
qc <- data.frame(rule = c("R1 body mass invalid", "R2 quiet mass >5% off", "R3 flight force >50 N", "R4 missing metrics/age", "R5 no lowest-COM end"),
                 n_flagged = sapply(paste0("fail_r", 1:5), function(r) sum(raw[[r]], na.rm = TRUE)))
print(qc); capture.output(print(qc), file = lc)
cmpv <- c("age", "body_mass_kg", "jump_height_cm", "conc_peak_force_n", "peak_landing_force_n", "contraction_time_s", "flight_time_s", "landing_to_lowcom_s")
cmp <- bind_rows(lapply(cmpv, function(v) { k <- raw[[v]][raw$kept]; d <- raw[[v]][!raw$kept]
  data.frame(variable = v, kept_n = sum(!is.na(k)), kept_mean = mean(k, na.rm = TRUE), kept_sd = sd(k, na.rm = TRUE),
             dropped_n = sum(!is.na(d)), dropped_mean = mean(d, na.rm = TRUE), dropped_sd = sd(d, na.rm = TRUE),
             wilcox_p = tryCatch(wilcox.test(k, d)$p.value, error = function(e) NA)) }))
wcsv(cmp, "A7_dropped_vs_kept.csv"); print(cmp); capture.output(print(cmp), file = lc)
say("   dropped trials: %d from %d athletes; athletes lost entirely: %d; dropped trials at 500 Hz: %d",
    sum(!raw$kept), n_distinct(raw$athlete[!raw$kept]), n_distinct(raw$athlete) - n_distinct(tr$athlete), sum(!raw$kept & raw$native_fs == 500))
cov <- tr %>% summarise(age_min = min(age), age_q25 = quantile(age, .25), age_med = median(age), age_q75 = quantile(age, .75), age_max = max(age),
  pct_under18 = 100*mean(age < 18), pct_under15 = 100*mean(age < 15), bm_min = min(body_mass_kg), bm_med = median(body_mass_kg), bm_max = max(body_mass_kg))
wcsv(cov, "A8_coverage.csv"); capture.output(print(cov), file = lc); print(cov)
ath_age <- tr %>% group_by(athlete) %>% summarise(age = mean(age), bm = mean(body_mass_kg))
p1 <- ggplot(ath_age, aes(age)) + geom_histogram(binwidth = 1, fill = "grey60", colour = "white") + labs(x = "Athlete mean age (y)", y = "Athletes")
p2 <- ggplot(ath_age, aes(bm)) + geom_histogram(binwidth = 5, fill = "grey60", colour = "white") + labs(x = "Athlete mean body mass (kg)", y = "Athletes")
p3 <- ggplot(tr, aes(landing_to_lowcom_s * native_fs, fill = factor(native_fs))) + geom_histogram(bins = 40, colour = "white") +
  geom_vline(xintercept = 101, linetype = "dashed") + scale_fill_manual(values = c("500" = "grey20", "1000" = "grey65")) +
  labs(x = "Native samples in landing phase (dashed = 101)", y = "Trials", fill = "Hz")
p4 <- ggplot(tr, aes(n_ld, ret_ld)) + geom_point(size = 0.6, alpha = 0.6) + labs(x = "Native samples in landing", y = "Curve max / vendor peak landing force")
savefig((p1 | p2) / (p3 | p4) + plot_annotation(title = "Sampling audit: coverage, landing sampling and peak retention"), "figA2_sampling_audit.png", 170, 130)
say("   test dates: NOT in the de-identified file (only pseudonymous session codes), so date coverage cannot be checked here.")
say("\nAudit runtime %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
close(lc)
