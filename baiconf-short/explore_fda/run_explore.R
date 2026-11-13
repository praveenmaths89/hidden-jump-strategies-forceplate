#!/usr/bin/env Rscript
# =============================================================================
# EXPLORATORY functional-data analysis of CMJ force curves (not part of the paper)
#   1. Function-on-scalar regression (FoSR) with athlete-block bootstrap bands
#   2. Curve clustering into jump profiles (k-means on FPCA scores; k = 2..6)
#   3. SPM-style pointwise tests with athlete-level permutation cluster correction
#   4. Matched-height view (45th-55th percentile of jump height)
# Take-off (onset -> take-off) and landing (touch-down -> lowest COM) are analysed
# as separate 101-point blocks (0-100 % of phase), force in body-weight units.
# Run from explore_fda/:  Rscript run_explore.R
# =============================================================================
t0 <- Sys.time()
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(patchwork)
  library(cluster); library(mclust); library(nlme)
  library(refund); library(mgcv); library(diptest); library(fdasrvf)
})
SEED <- 2026; set.seed(SEED)
G <- 9.81
N_BOOT <- 2000      # athlete-block bootstrap (FoSR)
N_PERM <- 5000      # athlete-level permutations (SPM)
N_STAB <- 200       # bootstrap resamples for cluster stability (Jaccard/ARI; Hennig 2007 uses 100-200)
N_GAP <- 100        # reference datasets for the gap statistic
N_SIM <- 10000      # posterior draws for Ruppert-type simultaneous bands (pffr)
PFFR_GRID <- seq(1, 101, 2)   # pffr fitted on every 2nd node (51 nodes); node-count sensitivity shows no change (time_norm_sensitivity.R)
K_GRID <- 2:6
VAR_KEEP <- 0.90    # FPCA scores retained for clustering
source("data_path.R"); DATA <- cmj_data_path()
dir.create("figs", showWarnings = FALSE); dir.create("tables", showWarnings = FALSE)
log_con <- file("results_log.txt", "w")
say <- function(...) { s <- sprintf(...); cat(s, "\n"); cat(s, "\n", file = log_con) }
wcsv <- function(x, f) write.csv(x, file.path("tables", f), row.names = FALSE)

theme_set(theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(),
  strip.background = element_rect(fill = "grey92"), plot.title = element_text(face = "bold", size = 9),
  legend.position = "bottom"))
savefig <- function(p, f, w = 170, h = 110) ggsave(file.path("figs", f), p, width = w/25.4, height = h/25.4, dpi = 300, bg = "white")
BLOCKS <- c(takeoff = "Take-off (onset to take-off)", landing = "Landing (touch-down to lowest COM)")
pct <- 0:100

# -----------------------------------------------------------------------------
# 0. Data + the paper's QC rules (R1-R5) -> 805 trials
# -----------------------------------------------------------------------------
tr <- read.csv(DATA)
tr <- tr %>% filter(!(is.na(body_mass_kg) | body_mass_kg <= 0)) %>%
  filter(abs(quiet_mass_kg - body_mass_kg) / body_mass_kg <= 0.05) %>%
  filter(abs(flight_force_n) <= 50) %>%
  filter(!(is.na(age) | is.na(jump_height_cm) | is.na(conc_peak_force_n) |
           is.na(ecc_braking_impulse_ns) | is.na(conc_impulse_100ms_ns))) %>%
  filter(!is.na(ldc_050))
bw <- tr$body_mass_kg * G
Y <- list(takeoff = as.matrix(tr[, grep("^to_\\d", names(tr))]) / bw,
          landing = as.matrix(tr[, grep("^ldc_\\d", names(tr))]) / bw)
stopifnot(ncol(Y$takeoff) == 101, ncol(Y$landing) == 101, !anyNA(Y$takeoff), !anyNA(Y$landing))
ath <- factor(tr$athlete); ses <- factor(tr$test_code)
n <- nrow(tr)
say("[0] %d trials, %d athletes, %d sessions after QC", n, nlevels(ath), nlevels(ses))
say("    age < 18: %d trials (%.1f%%); athletes with >=2 sessions: %d", sum(tr$age < 18), 100*mean(tr$age < 18),
    sum(tapply(as.character(tr$test_code), tr$athlete, function(s) length(unique(s))) >= 2))

# helper: contiguous runs of TRUE -> "a-b%" strings
runs <- function(lg, x = pct) {
  if (!any(lg)) return("none")
  r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1
  paste(sprintf("%d-%d%%", x[s[r$values]], x[e[r$values]]), collapse = ", ")
}
long_curves <- function(M, ids, extra = NULL) {
  d <- data.frame(id = rep(ids, each = 101), pct = rep(pct, length(ids)), f = as.vector(t(M)))
  d
}

# -----------------------------------------------------------------------------
# 1. FUNCTION-ON-SCALAR REGRESSION -- ROBUSTNESS VERSION (pointwise OLS on the 101-point grid,
#    predictors standardised -> coefficient = change in force (xBW) per 1 SD),
#    inference by athlete-block bootstrap (resample athletes with all trials).
#    Simultaneous band: bootstrap sup-|t| over the 101 points of each block.
# -----------------------------------------------------------------------------
say("\n[1] Function-on-scalar regression")
z <- function(v) (v - mean(v)) / sd(v)
Xdf <- data.frame(jump_height = z(tr$jump_height_cm), age = z(tr$age), body_mass = z(tr$body_mass_kg),
                  conc_peak_force = z(tr$conc_peak_force_n), braking_impulse = z(tr$ecc_braking_impulse_ns),
                  impulse_100ms = z(tr$conc_impulse_100ms_ns))
MODELS <- list(A = c("jump_height", "age", "body_mass"),
               B = c("jump_height", "age", "body_mass", "conc_peak_force", "braking_impulse", "impulse_100ms"))
sd_raw <- c(jump_height = sd(tr$jump_height_cm), age = sd(tr$age), body_mass = sd(tr$body_mass_kg),
            conc_peak_force = sd(tr$conc_peak_force_n), braking_impulse = sd(tr$ecc_braking_impulse_ns),
            impulse_100ms = sd(tr$conc_impulse_100ms_ns))
say("    1 SD: jump height %.2f cm, age %.2f y, body mass %.2f kg", sd_raw[1], sd_raw[2], sd_raw[3])
ath_idx <- split(seq_len(n), ath)
boot_sets <- replicate(N_BOOT, unlist(ath_idx[sample(length(ath_idx), replace = TRUE)], use.names = FALSE), simplify = FALSE)
fosr_rows <- list(); fosr_coef <- list(); r2_rows <- list()
for (m in names(MODELS)) for (b in names(Y)) {
  X <- cbind(1, as.matrix(Xdf[, MODELS[[m]]])); Yb <- Y[[b]]
  est <- qr.solve(X, Yb)                                 # (p+1) x 101
  res <- Yb - X %*% est
  r2 <- 1 - colSums(res^2) / colSums(sweep(Yb, 2, colMeans(Yb))^2)
  r2_rows[[paste(m, b)]] <- data.frame(model = m, block = b, pct = pct, r2 = r2)
  bt <- array(NA, c(N_BOOT, nrow(est), 101))
  for (i in seq_len(N_BOOT)) { s <- boot_sets[[i]]; bt[i, , ] <- qr.solve(X[s, ], Yb[s, ]) }
  for (j in 2:nrow(est)) {
    se <- apply(bt[, j, ], 2, sd)
    tmax <- apply(abs(sweep(bt[, j, ], 2, est[j, ])) / rep(se, each = N_BOOT), 1, max)
    cs <- quantile(tmax, 0.95); cs_mcse <- sd(replicate(500, quantile(sample(tmax, replace = TRUE), 0.95)))
    d <- data.frame(model = m, block = b, term = colnames(X)[j], pct = pct, est = est[j, ],
                    lo_pw = est[j, ] - 1.96*se, hi_pw = est[j, ] + 1.96*se,
                    lo_sim = est[j, ] - cs*se, hi_sim = est[j, ] + cs*se, crit_sim = cs)
    fosr_coef[[paste(m, b, j)]] <- d
    sig_pw <- d$lo_pw > 0 | d$hi_pw < 0; sig_sim <- d$lo_sim > 0 | d$hi_sim < 0
    fosr_rows[[paste(m, b, j)]] <- data.frame(model = m, block = b, term = colnames(X)[j],
      sim_crit = round(cs, 2), sim_crit_mc_se = round(cs_mcse, 3), pct_points_sig_sim = sum(sig_sim),
      sig_simultaneous = runs(sig_sim), sig_pos_sim = runs(d$lo_sim > 0), sig_neg_sim = runs(d$hi_sim < 0),
      sig_pointwise = runs(sig_pw), max_abs_effect_bw = round(max(abs(d$est)), 3),
      at_pct = pct[which.max(abs(d$est))], effect_at_max = round(d$est[which.max(abs(d$est))], 3))
  }
  say("    model %s %-8s pointwise R2: median %.3f, range %.3f-%.3f", m, b, median(r2), min(r2), max(r2))
}
fosr_tab <- bind_rows(fosr_rows); fosr_c <- bind_rows(fosr_coef); r2_tab <- bind_rows(r2_rows)
wcsv(fosr_tab, "F1_fosr_significance.csv"); wcsv(fosr_c, "F1_fosr_coefficients.csv"); wcsv(r2_tab, "F1_fosr_pointwise_r2.csv")
for (i in seq_len(nrow(fosr_tab))) with(fosr_tab[i, ], say("    %s %-8s %-16s sim-sig: %s | +: %s | -: %s | max|b|=%.3f BW at %d%%",
  model, block, term, sig_simultaneous, sig_pos_sim, sig_neg_sim, max_abs_effect_bw, at_pct))

term_lab <- c(jump_height = "Jump height", age = "Age", body_mass = "Body mass", conc_peak_force = "Conc. peak force",
              braking_impulse = "Braking impulse", impulse_100ms = "Impulse first 100 ms")
plot_fosr <- function(m) {
  d <- fosr_c %>% filter(model == m) %>%
    mutate(term = factor(term_lab[term], levels = term_lab[MODELS[[m]]]), block = factor(BLOCKS[block], levels = BLOCKS))
  sig <- d %>% mutate(s = lo_sim > 0 | hi_sim < 0) %>% filter(s)
  ggplot(d, aes(pct, est)) +
    geom_ribbon(aes(ymin = lo_sim, ymax = hi_sim), fill = "grey85") +
    geom_ribbon(aes(ymin = lo_pw, ymax = hi_pw), fill = "grey60") +
    geom_hline(yintercept = 0, linewidth = 0.3, linetype = "dashed") +
    geom_line(linewidth = 0.6) +
    geom_rug(data = sig, aes(x = pct), sides = "b", inherit.aes = FALSE, linewidth = 0.4, length = unit(0.04, "npc")) +
    facet_grid(term ~ block, scales = "free_y") +
    labs(x = "% of phase", y = "Effect on force (x BW) per 1 SD of predictor",
         title = sprintf("Function-on-scalar regression, model %s: coefficient curves", m),
         caption = "Dark band: 95% pointwise; light band: 95% simultaneous (athlete-block bootstrap, 2000 resamples).\nTicks on the x-axis mark points where the simultaneous band excludes zero. Predictors standardised; all terms adjusted for each other.")
}
savefig(plot_fosr("A"), "fig1a_fosr_modelA_coefficients.png", 170, 150)
savefig(plot_fosr("B"), "fig1b_fosr_modelB_coefficients.png", 170, 230)
p_r2 <- ggplot(r2_tab %>% mutate(block = factor(BLOCKS[block], levels = BLOCKS)), aes(pct, r2, linetype = model)) +
  geom_line(linewidth = 0.6) + facet_wrap(~block) + scale_y_continuous(limits = c(0, 1)) +
  scale_linetype_manual(values = c(A = "solid", B = "22"), labels = c(A = "A: jump height + age + body mass", B = "B: + 3 other vendor metrics")) +
  labs(x = "% of phase", y = expression("Pointwise "*R^2), linetype = NULL, title = "Share of between-trial force variance explained at each point")
savefig(p_r2, "fig1c_fosr_pointwise_r2.png", 170, 80)

# -----------------------------------------------------------------------------
# 2. CLUSTERING into jump profiles (per block): PCA (FPCA on the dense grid)
#    -> scores explaining >= 90 % variance -> k-means (k = 2..6).
#    k chosen by mean silhouette and bootstrap stability (athlete resampling,
#    ARI between bootstrap clustering and original labels on the resampled trials);
#    Gaussian-mixture BIC (mclust) reported as a cross-check.
# -----------------------------------------------------------------------------
say("\n[2] Clustering")
ari <- function(a, b) adjustedRandIndex(a, b)
clus <- list(); kchoice <- list(); clus_summ <- list(); stab_out <- list()
for (b in names(Y)) {
  pc <- prcomp(Y[[b]], center = TRUE, scale. = FALSE)
  ve <- cumsum(pc$sdev^2) / sum(pc$sdev^2); q <- which(ve >= VAR_KEEP)[1]
  S <- pc$x[, 1:q, drop = FALSE]
  say("    %s: %d FPCs retained (%.1f%% variance)", b, q, 100*ve[q])
  D <- dist(S)
  sel <- lapply(K_GRID, function(k) {
    set.seed(SEED + k); km <- kmeans(S, k, nstart = 50, iter.max = 100)
    sil <- mean(silhouette(km$cluster, D)[, 3])
    st <- sapply(seq_len(N_STAB), function(i) {
      s <- unlist(ath_idx[sample(length(ath_idx), replace = TRUE)], use.names = FALSE)
      kb <- kmeans(S[s, ], k, nstart = 10, iter.max = 100)
      ari(kb$cluster, km$cluster[s])
    })
    list(km = km, row = data.frame(block = b, k = k, silhouette = sil, stab_ari_median = median(st),
         stab_ari_p10 = quantile(st, 0.10), min_cluster_n = min(km$size), wss_ratio = km$tot.withinss / km$totss))
  })
  ksel <- bind_rows(lapply(sel, `[[`, "row"))
  mc <- Mclust(S, G = K_GRID, verbose = FALSE)
  bicmax <- apply(mc$BIC, 1, max, na.rm = TRUE)
  ksel$gmm_best_bic <- bicmax[as.character(ksel$k)]
  say("    %s Mclust best: %s with G = %d", b, mc$modelName, mc$G)
  # rule: largest silhouette among k with median stability ARI >= 0.75 (else largest silhouette)
  ok <- ksel$stab_ari_median >= 0.75
  kbest <- if (any(ok)) ksel$k[ok][which.max(ksel$silhouette[ok])] else ksel$k[which.max(ksel$silhouette)]
  ksel$chosen <- ksel$k == kbest; kchoice[[b]] <- ksel
  print(ksel)
  km <- sel[[which(K_GRID == kbest)]]$km
  # order clusters by mean PC1 score so labels are reproducible
  ord <- order(tapply(S[, 1], km$cluster, mean)); lab <- match(km$cluster, ord)
  clus[[b]] <- list(cl = lab, k = kbest, S = S, pc = pc, centers = km$centers[ord, , drop = FALSE], mclustG = mc$G, mclustModel = mc$modelName)
  say("    %s chosen k = %d (silhouette %.3f, stability ARI %.2f); sizes: %s", b, kbest,
      ksel$silhouette[ksel$chosen], ksel$stab_ari_median[ksel$chosen], paste(table(lab), collapse = "/"))
}
kc <- bind_rows(kchoice); wcsv(kc, "C1_k_selection.csv")
p_k <- kc %>% select(block, k, silhouette, stab_ari_median) %>% pivot_longer(c(silhouette, stab_ari_median)) %>%
  mutate(name = recode(name, silhouette = "Mean silhouette", stab_ari_median = "Bootstrap stability (median ARI)"),
         block = factor(BLOCKS[block], levels = BLOCKS)) %>%
  ggplot(aes(k, value, shape = name, linetype = name)) + geom_line() + geom_point(size = 2) + facet_wrap(~block) +
  geom_hline(yintercept = 0.75, linewidth = 0.3, colour = "grey50", linetype = "dotted") +
  scale_shape_manual(values = c(16, 1)) + labs(y = NULL, shape = NULL, linetype = NULL, title = "Choosing the number of jump profiles")
savefig(p_k, "fig2a_cluster_k_selection.png", 170, 80)

# Cluster descriptions + jump-height differences (mixed model with athlete random intercept)
desc_vars <- c(jump_height_cm = "Jump height (cm)", age = "Age (y)", body_mass_kg = "Body mass (kg)",
               landing_to_lowcom_s = "Landing duration (s)", contraction_time_s = "Contraction time (s)")
for (b in names(Y)) {
  cl <- clus[[b]]$cl; d <- tr %>% mutate(cl = factor(cl))
  s <- d %>% group_by(cl) %>% summarise(n_trials = n(), n_athletes = n_distinct(athlete),
        across(all_of(names(desc_vars)), list(mean = ~mean(.x, na.rm = TRUE), sd = ~sd(.x, na.rm = TRUE))),
        pct_under18 = 100*mean(age < 18), .groups = "drop") %>% mutate(block = b)
  tests <- sapply(c("jump_height_cm", "age", "body_mass_kg"), function(v) {
    dd <- d[!is.na(d[[v]]), ]; dd$yv <- dd[[v]]
    m1 <- lme(yv ~ cl, random = ~1 | athlete, data = dd, method = "ML")
    m0 <- lme(yv ~ 1, random = ~1 | athlete, data = dd, method = "ML")
    anova(m0, m1)$`p-value`[2]
  })
  s$p_jump_height_lmm <- tests["jump_height_cm"]; s$p_age_lmm <- tests["age"]; s$p_body_mass_lmm <- tests["body_mass_kg"]
  clus_summ[[b]] <- s
  say("    %s cluster means (JH cm / age / BM / landing s / contraction s; n):", b)
  for (i in seq_len(nrow(s))) say("      C%s n=%d (%d ath): JH %.1f, age %.1f, BM %.1f, land %.3f, CT %.3f, <18 %.0f%%", s$cl[i], s$n_trials[i], s$n_athletes[i],
      s$jump_height_cm_mean[i], s$age_mean[i], s$body_mass_kg_mean[i], s$landing_to_lowcom_s_mean[i], s$contraction_time_s_mean[i], s$pct_under18[i])
  say("      LMM (athlete RI) LRT p: jump height %.3g, age %.3g, body mass %.3g", tests[1], tests[2], tests[3])
}
wcsv(bind_rows(clus_summ), "C2_cluster_profiles.csv")

# Cluster mean curves with bands (mean +/- 1 SD and 2.5-97.5 % pointwise quantiles)
cl_curves <- bind_rows(lapply(names(Y), function(b) {
  cl <- clus[[b]]$cl
  bind_rows(lapply(sort(unique(cl)), function(k) {
    M <- Y[[b]][cl == k, , drop = FALSE]
    data.frame(block = b, cluster = paste0("Profile ", k, " (n=", sum(cl == k), ")"), pct = pct, mean = colMeans(M),
               lo = colMeans(M) - apply(M, 2, sd), hi = colMeans(M) + apply(M, 2, sd))
  }))
}))
LT <- c("solid", "42", "12", "4212", "dotdash", "longdash"); GR <- c("grey10", "grey45", "grey65", "grey30", "grey55", "grey20")
p_cl <- lapply(names(Y), function(b) {
  d <- cl_curves %>% filter(block == b)
  ggplot(d, aes(pct, mean, linetype = cluster)) + geom_ribbon(aes(ymin = lo, ymax = hi, fill = cluster), alpha = 0.35, colour = NA) +
    geom_line(linewidth = 0.7) + scale_linetype_manual(values = LT) + scale_fill_manual(values = c("grey40", "grey70", "grey85", "grey55", "grey75", "grey30")) +
    labs(x = "% of phase", y = "Force (x BW)", linetype = NULL, fill = NULL, title = BLOCKS[b]) + guides(fill = "none") +
    theme(legend.direction = "vertical")
})
savefig(wrap_plots(p_cl, ncol = 2) + plot_annotation(title = "Jump profiles: cluster mean curves (band = mean +/- 1 SD)",
        caption = "k-means on FPCA scores (>= 90% variance), separately for take-off and landing; time normalised to 0-100% of each phase."),
        "fig2b_cluster_mean_curves.png", 170, 100)

# Within-athlete stability of profiles across sessions + chance baseline
say("\n    Profile stability across sessions (athletes with >= 2 sessions)")
stab_rows <- list()
for (b in names(Y)) {
  cl <- clus[[b]]$cl; S <- clus[[b]]$S; C <- clus[[b]]$centers
  # session profile = cluster nearest to the session's mean FPCA score (robust to ties)
  sm <- aggregate(S, by = list(test_code = tr$test_code), mean)
  sess_cl <- apply(as.matrix(sm[, -1]), 1, function(v) which.min(colSums((t(C) - v)^2)))
  sess <- data.frame(test_code = sm$test_code, scl = sess_cl) %>%
    left_join(distinct(tr, test_code, athlete), by = "test_code")
  multi <- sess %>% group_by(athlete) %>% filter(n() >= 2)
  obs_same <- multi %>% summarise(same = n_distinct(scl) == 1, .groups = "drop") %>% pull(same) %>% mean()
  obs_pair <- multi %>% summarise(agree = { v <- scl; pr <- combn(length(v), 2); mean(v[pr[1, ]] == v[pr[2, ]]) }, .groups = "drop") %>% pull(agree) %>% mean()
  set.seed(SEED)
  perm <- replicate(N_PERM %/% 2.5, {
    sp <- sess; sp$scl <- sample(sp$scl)
    sp %>% filter(athlete %in% multi$athlete) %>% group_by(athlete) %>% summarise(same = n_distinct(scl) == 1, .groups = "drop") %>% pull(same) %>% mean()
  })
  # analytic baseline: sum over athletes of sum_k p_k^{n_i}
  pk <- prop.table(table(sess$scl)); ni <- table(multi$athlete); ni <- ni[ni > 0]
  analytic <- mean(sapply(ni, function(m) sum(pk^m)))
  # trial-level: within-session agreement among trials
  w_same <- tr %>% mutate(cl = cl) %>% group_by(test_code) %>% filter(n() >= 2) %>%
    summarise(a = { v <- cl; pr <- combn(length(v), 2); mean(v[pr[1, ]] == v[pr[2, ]]) }, .groups = "drop") %>% pull(a) %>% mean()
  w_chance <- sum(prop.table(table(cl))^2)
  p_perm <- (1 + sum(perm >= obs_same)) / (1 + length(perm))
  stab_rows[[b]] <- data.frame(block = b, k = clus[[b]]$k, athletes_multi = n_distinct(multi$athlete),
    sessions_of_these = nrow(multi), share_same_all_sessions = obs_same, chance_perm_mean = mean(perm),
    chance_analytic = analytic, p_perm = p_perm, mean_pairwise_session_agreement = obs_pair,
    within_session_trial_agreement = w_same, within_session_chance = w_chance)
  say("    %s: %d athletes; same profile in all sessions %.1f%% vs chance %.1f%% (perm; analytic %.1f%%), p = %.3f; within-session trial agreement %.1f%% vs chance %.1f%%",
      b, n_distinct(multi$athlete), 100*obs_same, 100*mean(perm), 100*analytic, p_perm, 100*w_same, 100*w_chance)
}
stab <- bind_rows(stab_rows); wcsv(stab, "C3_profile_stability.csv")
wcsv(data.frame(athlete = tr$athlete, test_code = tr$test_code, trial_no = tr$trial_no, jump_height_cm = tr$jump_height_cm,
  takeoff_profile = clus$takeoff$cl, landing_profile = clus$landing$cl,
  takeoff_fpc1 = clus$takeoff$S[, 1], takeoff_fpc2 = clus$takeoff$S[, 2], landing_fpc1 = clus$landing$S[, 1], landing_fpc2 = clus$landing$S[, 2]),
  "C6_trial_profiles.csv")
xt <- table(takeoff = clus$takeoff$cl, landing = clus$landing$cl)
cv <- suppressWarnings(sqrt(chisq.test(xt)$statistic / (sum(xt) * (min(dim(xt)) - 1))))
say("    Take-off x landing profile cross-tab (Cramer's V = %.3f, chi-sq p = %.3g):", cv, suppressWarnings(chisq.test(xt)$p.value))
capture.output(print(xt), file = log_con); print(xt)

# -----------------------------------------------------------------------------
# 3. SPM-style pointwise tests, cluster-mass correction, athlete-level permutation
#    (a) top vs bottom tertile of athlete-mean jump height (athlete mean curves)
#    (b) athletes with mean age < 18 vs >= 18 (athlete mean curves)
#    (c) between profiles: within-athlete paired contrast (athletes with trials
#        in both profiles), sign-flip permutation at athlete level.
#    Cluster-forming threshold: two-sided p < .05 on the pointwise t (t-dist df).
# -----------------------------------------------------------------------------
say("\n[3] SPM-style tests")
tstat2 <- function(M, g) {   # Welch t, g logical (TRUE = group 1)
  a <- M[g, , drop = FALSE]; b <- M[!g, , drop = FALSE]
  (colMeans(a) - colMeans(b)) / sqrt(apply(a, 2, var)/nrow(a) + apply(b, 2, var)/nrow(b))
}
tstat1 <- function(D) colMeans(D) / (apply(D, 2, sd) / sqrt(nrow(D)))
clmass <- function(t, thr) {   # list of supra-threshold clusters with mass
  t[!is.finite(t)] <- 0          # zero-variance nodes (e.g. fixed warp end-points) carry no evidence
  lg <- abs(t) > thr
  if (!any(lg)) return(data.frame(start = integer(), end = integer(), mass = numeric()))
  r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1
  s <- s[r$values]; e <- e[r$values]
  # split by sign as well
  out <- list()
  for (i in seq_along(s)) { idx <- s[i]:e[i]; sg <- sign(t[idx]); rr <- rle(sg); ee <- cumsum(rr$lengths); ss <- ee - rr$lengths + 1
    for (j in seq_along(ss)) out[[length(out)+1]] <- data.frame(start = idx[ss[j]], end = idx[ee[j]], mass = sum(abs(t[idx[ss[j]:ee[j]]]))) }
  bind_rows(out)
}
spm_run <- function(M, g = NULL, D = NULL, label, block) {
  set.seed(SEED)
  if (is.null(D)) { t <- tstat2(M, g); df <- sum(g) + sum(!g) - 2 } else { t <- tstat1(D); df <- nrow(D) - 1 }
  thr <- qt(0.975, df)
  obs <- clmass(t, thr)
  maxnull <- replicate(N_PERM, {
    tp <- if (is.null(D)) tstat2(M, sample(g)) else tstat1(D * sample(c(-1, 1), nrow(D), replace = TRUE))
    cm <- clmass(tp, thr); if (nrow(cm)) max(cm$mass) else 0
  })
  obs$p <- sapply(obs$mass, function(ms) (1 + sum(maxnull >= ms)) / (1 + N_PERM))
  obs$range <- sprintf("%d-%d%%", pct[obs$start], pct[obs$end])
  obs$direction <- if (nrow(obs)) ifelse(t[obs$start] > 0, "group1 > group2", "group1 < group2") else character()
  list(t = data.frame(contrast = label, block = block, pct = pct, t = t, thr = thr), clusters = if (nrow(obs)) cbind(contrast = label, block = block, obs) else NULL,
       maxnull95 = quantile(maxnull, 0.95))
}
ath_mean <- function(M, ids) { a <- rowsum(M, ids) / as.vector(table(ids)[rownames(rowsum(M, ids))]); a }
am <- tr %>% group_by(athlete) %>% summarise(jh = mean(jump_height_cm), age = mean(age), .groups = "drop")
tert <- quantile(am$jh, c(1/3, 2/3))
spm_res <- list(); grp_means <- list()
for (b in names(Y)) {
  A <- ath_mean(Y[[b]], tr$athlete); A <- A[match(am$athlete, rownames(A)), ]
  # (a)
  sel <- am$jh <= tert[1] | am$jh >= tert[2]; g <- am$jh[sel] >= tert[2]
  spm_res[[paste("a", b)]] <- spm_run(A[sel, ], g, label = "a: top vs bottom jump-height tertile", block = b)
  grp_means[[paste("a", b)]] <- data.frame(contrast = "a: top vs bottom jump-height tertile", block = b, pct = pct,
     g1 = colMeans(A[sel, ][g, ]), g2 = colMeans(A[sel, ][!g, ]), n1 = sum(g), n2 = sum(!g), lab1 = "Top tertile", lab2 = "Bottom tertile")
  # (b)
  g <- am$age >= 18
  spm_res[[paste("b", b)]] <- spm_run(A, g, label = "b: 18+ vs under 18", block = b)
  grp_means[[paste("b", b)]] <- data.frame(contrast = "b: 18+ vs under 18", block = b, pct = pct,
     g1 = colMeans(A[g, ]), g2 = colMeans(A[!g, ]), n1 = sum(g), n2 = sum(!g), lab1 = "18 and over", lab2 = "Under 18")
  # (c) two most different profiles (largest centroid distance in curve space), within-athlete
  cl <- clus[[b]]$cl; K <- clus[[b]]$k
  cm <- t(sapply(1:K, function(k) colMeans(Y[[b]][cl == k, , drop = FALSE])))
  dd <- as.matrix(dist(cm)); pr <- which(dd == max(dd), arr.ind = TRUE)[1, ]; pr <- sort(pr)
  i1 <- cl == pr[2]; i2 <- cl == pr[1]
  A1 <- ath_mean(Y[[b]][i1, ], tr$athlete[i1]); A2 <- ath_mean(Y[[b]][i2, ], tr$athlete[i2])
  both <- intersect(rownames(A1), rownames(A2))
  Dm <- A1[both, ] - A2[both, ]
  lab <- sprintf("c: profile %d vs %d (within athlete)", pr[2], pr[1])
  spm_res[[paste("c", b)]] <- spm_run(D = Dm, label = lab, block = b)
  grp_means[[paste("c", b)]] <- data.frame(contrast = "c: profiles (within athlete)", block = b, pct = pct,
     g1 = colMeans(A1[both, ]), g2 = colMeans(A2[both, ]), n1 = length(both), n2 = length(both),
     lab1 = sprintf("Profile %d", pr[2]), lab2 = sprintf("Profile %d", pr[1]))
}
spm_cl <- bind_rows(lapply(spm_res, `[[`, "clusters")); spm_t <- bind_rows(lapply(spm_res, `[[`, "t"))
wcsv(spm_cl, "S1_spm_clusters.csv"); wcsv(spm_t, "S1_spm_tcurves.csv")
gm <- bind_rows(grp_means)
for (k in names(spm_res)) {
  r <- spm_res[[k]]; c0 <- r$clusters; nn <- gm %>% filter(paste(substr(contrast, 1, 1), block) == k) %>% slice(1)
  say("    %s | %s (n %d vs %d; thr |t| > %.2f)", r$t$contrast[1], r$t$block[1], nn$n1, nn$n2, r$t$thr[1])
  if (is.null(c0)) say("      no supra-threshold clusters") else for (i in seq_len(nrow(c0)))
    say("      %s  %s  mass %.1f  p = %.4f%s", c0$range[i], c0$direction[i], c0$mass[i], c0$p[i], ifelse(c0$p[i] < 0.05, "  *", ""))
}
# SPM figure: top row group means, bottom row t-curve with threshold and significant clusters shaded
spm_plot <- function(letter, title) {
  ps <- lapply(names(Y), function(b) {
    g <- gm %>% filter(substr(contrast, 1, 1) == letter, block == b)
    tt <- spm_t %>% filter(substr(contrast, 1, 1) == letter, block == b)
    cc <- spm_cl %>% filter(substr(contrast, 1, 1) == letter, block == b, p < 0.05)
    shade <- if (nrow(cc)) geom_rect(data = cc, aes(xmin = pct[start], xmax = pct[end], ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey85") else NULL
    gl <- g %>% select(pct, g1, g2) %>% pivot_longer(-pct) %>% mutate(name = ifelse(name == "g1", sprintf("%s (n=%d)", g$lab1[1], g$n1[1]), sprintf("%s (n=%d)", g$lab2[1], g$n2[1])))
    p1 <- ggplot(gl, aes(pct, value, linetype = name)) + shade + geom_line(linewidth = 0.6) +
      scale_linetype_manual(values = c("solid", "22")) + labs(x = NULL, y = "Force (x BW)", linetype = NULL, title = BLOCKS[b]) +
      theme(legend.position = "top", legend.text = element_text(size = 7))
    p2 <- ggplot(tt, aes(pct, t)) + shade + geom_hline(yintercept = c(-1, 1) * tt$thr[1], linetype = "dotted") +
      geom_hline(yintercept = 0, linewidth = 0.2) + geom_line(linewidth = 0.6) + labs(x = "% of phase", y = "t statistic")
    p1 / p2 + plot_layout(heights = c(1.3, 1))
  })
  wrap_plots(ps, ncol = 2) + plot_annotation(title = title,
    caption = "Shaded: cluster-corrected significant regions (cluster mass, 5000 athlete-level permutations, alpha = 0.05). Dotted: cluster-forming threshold.")
}
savefig(spm_plot("a", "SPM (a): athletes in top vs bottom tertile of mean jump height"), "fig3a_spm_jump_height_tertiles.png", 170, 130)
savefig(spm_plot("b", "SPM (b): athletes aged 18 and over vs under 18 (athlete mean age)"), "fig3b_spm_age_groups.png", 170, 130)
savefig(spm_plot("c", "SPM (c): most different profiles, paired within athlete (descriptive, circular)"), "fig3c_spm_profiles_within_athlete.png", 170, 130)

# -----------------------------------------------------------------------------
# 4. Matched-height view: trials between 45th and 55th percentile of jump height
# -----------------------------------------------------------------------------
say("\n[4] Matched-height band")
lim <- quantile(tr$jump_height_cm, c(0.45, 0.55)); inb <- tr$jump_height_cm >= lim[1] & tr$jump_height_cm <= lim[2]
say("    band %.1f-%.1f cm: %d trials, %d athletes", lim[1], lim[2], sum(inb), n_distinct(tr$athlete[inb]))
band_rows <- list(); pb <- list()
for (b in names(Y)) {
  cl <- clus[[b]]$cl
  tb <- table(factor(cl[inb], levels = 1:clus[[b]]$k)); tall <- table(factor(cl, levels = 1:clus[[b]]$k))
  sdr <- mean(apply(Y[[b]][inb, ], 2, sd)) / mean(apply(Y[[b]], 2, sd))
  band_rows[[b]] <- data.frame(block = b, cluster = names(tb), n_band = as.vector(tb), pct_band = round(100*as.vector(prop.table(tb)), 1),
                               pct_all = round(100*as.vector(prop.table(tall)), 1), mean_sd_ratio_band_vs_all = round(sdr, 3))
  say("    %s: band profile mix %s (all trials %s); mean pointwise SD ratio band/all = %.2f", b,
      paste(sprintf("%.0f%%", 100*prop.table(tb)), collapse = "/"), paste(sprintf("%.0f%%", 100*prop.table(tall)), collapse = "/"), sdr)
  d <- data.frame(id = rep(which(inb), each = 101), pct = rep(pct, sum(inb)), f = as.vector(t(Y[[b]][inb, ])),
                  cluster = factor(rep(paste("Profile", cl[inb]), each = 101)))
  mm <- d %>% group_by(cluster, pct) %>% summarise(f = mean(f), .groups = "drop")
  pb[[b]] <- ggplot(d, aes(pct, f, group = id)) + geom_line(colour = "grey75", linewidth = 0.2, alpha = 0.7) +
    geom_line(data = mm, aes(pct, f, linetype = cluster, group = cluster), inherit.aes = FALSE, linewidth = 0.9) +
    scale_linetype_manual(values = LT) + labs(x = "% of phase", y = "Force (x BW)", linetype = NULL, title = BLOCKS[b]) +
    theme(legend.direction = "vertical")
}
wcsv(bind_rows(band_rows), "M1_matched_band_profiles.csv")
wcsv(data.frame(lo_cm = lim[1], hi_cm = lim[2], n_trials = sum(inb), n_athletes = n_distinct(tr$athlete[inb])), "M2_matched_band_limits.csv")
# faceted version (one panel per profile) is easier to read in greyscale
pf <- lapply(names(Y), function(b) {
  cl <- clus[[b]]$cl
  d <- data.frame(id = rep(which(inb), each = 101), pct = rep(pct, sum(inb)), f = as.vector(t(Y[[b]][inb, ])),
                  cluster = factor(rep(sprintf("Profile %d (n=%d)", cl[inb], ave(cl[inb], cl[inb], FUN = length)), each = 101)))
  mm <- d %>% group_by(cluster, pct) %>% summarise(f = mean(f), .groups = "drop")
  ggplot(d, aes(pct, f, group = id)) + geom_line(colour = "grey70", linewidth = 0.2) +
    geom_line(data = mm, aes(pct, f, group = cluster), inherit.aes = FALSE, linewidth = 0.9) +
    facet_wrap(~cluster, nrow = 1) + labs(x = "% of phase", y = "Force (x BW)", title = BLOCKS[b])
})
savefig(wrap_plots(pf, ncol = 1) + plot_annotation(
  title = sprintf("Same jump height, different profiles: %d trials with jump height %.1f-%.1f cm (45th-55th percentile)", sum(inb), lim[1], lim[2]),
  caption = "Thin grey lines: individual trials; thick line: profile mean within the band. Profiles from the whole-sample clustering."),
  "fig4_matched_height_profiles.png", 170, 140)

# =============================================================================
# VERSION-2 ADDITIONS (see METHODS_SPEC.md)
# =============================================================================
# -----------------------------------------------------------------------------
# 5. FUNCTIONAL MIXED MODEL FoSR (refund::pffr, fREML), athlete and session
#    functional random intercepts via pcre() with multilevel-FPCA eigenfunctions;
#    Ruppert-type simultaneous bands from the posterior covariance; residual checks.
# -----------------------------------------------------------------------------
say("\n[5] Functional mixed models (pffr)")
tt <- pct[PFFR_GRID]
rm_ <- function(M, f) { s <- rowsum(M, f); s / as.vector(table(f)[rownames(s)]) }
ef_ <- function(M, kmax = 5) { e <- eigen(crossprod(scale(M, scale = FALSE)) / nrow(M), symmetric = TRUE)
  k <- min(kmax, which(cumsum(e$values) / sum(e$values) >= 0.95)[1]); list(f = e$vectors[, 1:k, drop = FALSE], v = e$values[1:k], k = k,
  share = sum(e$values[1:k]) / sum(e$values)) }
pffr_rows <- list(); pffr_coef <- list(); pffr_resid <- list(); vc_rows <- list()
for (m in names(MODELS)) for (b in names(Y)) {
  Yg <- Y[[b]][, PFFR_GRID]; dfp <- data.frame(Xdf[, MODELS[[m]]], ath = ath, ses = ses)
  X0 <- cbind(1, as.matrix(Xdf[, MODELS[[m]]])); R0 <- Yg - X0 %*% qr.solve(X0, Yg)
  am_ <- rm_(R0, ath); sm_ <- rm_(R0, ses); s2a <- as.character(ath[match(rownames(sm_), ses)])
  EA <- ef_(am_); ES <- ef_(sm_ - am_[s2a, ])
  efA <- EA$f; evA <- EA$v; efS <- ES$f; evS <- ES$v; dfp$Y <- Yg
  fml <- as.formula(paste("Y ~", paste(MODELS[[m]], collapse = " + "),
    "+ pcre(id = ath, efunctions = efA, evalues = evA, yind = tt) + pcre(id = ses, efunctions = efS, evalues = evS, yind = tt)"))
  tf <- system.time(fit <- pffr(fml, yind = tt, data = dfp, algorithm = "bam", method = "fREML", sandwich = "none", discrete = TRUE,
                                bs.yindex = list(bs = "ps", k = 20, m = c(2, 1))))[3]
  say("    model %s %-8s fitted in %.0f s (athlete efns %d [%.0f%%], session efns %d [%.0f%%])", m, b, tf, EA$k, 100*EA$share, ES$k, 100*ES$share)
  cf <- fit$coefficients; V <- fit$Vp
  for (v in MODELS[[m]]) {
    smi <- which(sapply(fit$smooth, function(s) s$by) == v); sm <- fit$smooth[[smi]]; idx <- sm$first.para:sm$last.para
    nd <- data.frame(yindex.vec = tt); nd[[v]] <- 1; Xp <- PredictMat(sm, nd)
    est <- as.vector(Xp %*% cf[idx]); Vb <- Xp %*% V[idx, idx] %*% t(Xp); se <- sqrt(diag(Vb))
    set.seed(SEED); sims <- MASS::mvrnorm(N_SIM, rep(0, length(tt)), Vb)
    cs <- quantile(apply(abs(sims) / rep(se, each = N_SIM), 1, max), 0.95)
    d <- data.frame(model = m, block = b, term = v, pct = tt, est = est, lo_pw = est - 1.96*se, hi_pw = est + 1.96*se,
                    lo_sim = est - cs*se, hi_sim = est + cs*se)
    pffr_coef[[paste(m, b, v)]] <- d
    sig <- d$lo_sim > 0 | d$hi_sim < 0
    # agreement with the OLS + athlete-bootstrap robustness version (on the same nodes)
    ols <- fosr_c %>% filter(model == m, block == b, term == v, pct %in% tt)
    sig_ols <- ols$lo_sim > 0 | ols$hi_sim < 0
    pffr_rows[[paste(m, b, v)]] <- data.frame(model = m, block = b, term = v, sim_crit = round(cs, 2),
      sig_sim_pffr = runs(sig, tt), sig_sim_ols_boot = runs(sig_ols, tt), supported_both = runs(sig & sig_ols, tt),
      max_abs_effect = round(max(abs(est)), 3), at_pct = tt[which.max(abs(est))],
      effect_ci_at_max = sprintf("%.3f [%.3f, %.3f]", est[which.max(abs(est))], d$lo_pw[which.max(abs(est))], d$hi_pw[which.max(abs(est))]))
    with(pffr_rows[[paste(m, b, v)]], say("      %-16s pffr sim-sig: %-24s | OLS-boot: %-24s | both: %s | max %s at %d%%", term, sig_sim_pffr, sig_sim_ols_boot, supported_both, effect_ci_at_max, at_pct))
  }
  # variance decomposition and residual diagnostics
  res <- residuals(fit); if (!is.matrix(res)) res <- matrix(res, nrow = n, byrow = TRUE)
  fitted_ <- Yg - res
  rc <- cor(res); lag1 <- median(diag(rc[-1, -ncol(rc)]))
  # leftover within-athlete correlation of residual curves: correlation of residual FPC1 scores between trials of the same athlete
  rp <- prcomp(res); sc1 <- rp$x[, 1]; icc_res <- { fm <- lme(sc1 ~ 1, random = ~1 | ath, data = data.frame(sc1, ath)); vc <- as.numeric(VarCorr(fm)[, 1]); vc[1] / sum(vc) }
  vc_rows[[paste(m, b)]] <- data.frame(model = m, block = b, resid_lag1_corr_median = round(lag1, 3), resid_corr_mean_offdiag = round(mean(rc[upper.tri(rc)]), 3),
    resid_fpc1_share = round(rp$sdev[1]^2 / sum(rp$sdev^2), 3), resid_fpc1_icc_athlete = round(icc_res, 3),
    var_explained_total = round(1 - sum(res^2) / sum(sweep(Yg, 2, colMeans(Yg))^2), 3))
  say("      residuals: median lag-1 corr %.3f; residual FPC1 carries %.1f%% of residual variance; athlete ICC of residual FPC1 %.3f; total R2 (fixed+random) %.3f",
      lag1, 100*vc_rows[[paste(m, b)]]$resid_fpc1_share, icc_res, vc_rows[[paste(m, b)]]$var_explained_total)
  if (m == "A") pffr_resid[[b]] <- list(res = res, rc = rc, fitted = fitted_)
}
pffr_tab <- bind_rows(pffr_rows); wcsv(pffr_tab, "F2_pffr_significance.csv"); wcsv(bind_rows(pffr_coef), "F2_pffr_coefficients.csv")
wcsv(bind_rows(vc_rows), "F2_pffr_residual_diagnostics.csv")
plot_pffr <- function(m) {
  d <- bind_rows(pffr_coef) %>% filter(model == m) %>% mutate(term = factor(term_lab[term], levels = term_lab[MODELS[[m]]]), block = factor(BLOCKS[block], levels = BLOCKS))
  sig <- d %>% filter(lo_sim > 0 | hi_sim < 0)
  ggplot(d, aes(pct, est)) + geom_ribbon(aes(ymin = lo_sim, ymax = hi_sim), fill = "grey85") + geom_ribbon(aes(ymin = lo_pw, ymax = hi_pw), fill = "grey60") +
    geom_hline(yintercept = 0, linewidth = 0.3, linetype = "dashed") + geom_line(linewidth = 0.6) +
    geom_rug(data = sig, aes(x = pct), sides = "b", inherit.aes = FALSE, linewidth = 0.4, length = unit(0.04, "npc")) +
    facet_grid(term ~ block, scales = "free_y") +
    labs(x = "% of phase", y = "Effect on force (x BW) per 1 SD of predictor", title = sprintf("Functional mixed model (pffr), model %s: coefficient functions", m),
         caption = "Athlete and session functional random intercepts; penalised splines, fREML. Dark: 95% pointwise; light: 95% simultaneous (10,000 posterior draws).\nTicks: simultaneous band excludes zero.")
}
savefig(plot_pffr("A"), "fig5a_pffr_modelA_coefficients.png", 170, 150)
savefig(plot_pffr("B"), "fig5b_pffr_modelB_coefficients.png", 170, 230)
rd <- bind_rows(lapply(names(pffr_resid), function(b) { rc <- pffr_resid[[b]]$rc
  data.frame(block = BLOCKS[b], s = rep(tt, length(tt)), t = rep(tt, each = length(tt)), r = as.vector(rc)) }))
pr1 <- ggplot(rd, aes(s, t, fill = r)) + geom_raster() + facet_wrap(~block) + scale_fill_gradient2(low = "grey10", mid = "white", high = "grey10", limits = c(-1, 1)) +
  coord_equal() + labs(x = "% of phase", y = "% of phase", fill = "Residual\ncorrelation", title = "Residual correlation surface, pffr model A")
rq <- bind_rows(lapply(names(pffr_resid), function(b) data.frame(block = BLOCKS[b], r = as.vector(pffr_resid[[b]]$res)))) %>% group_by(block) %>% slice_sample(n = 20000)
pr2 <- ggplot(rq, aes(sample = r)) + stat_qq(size = 0.3, colour = "grey30") + stat_qq_line() + facet_wrap(~block, scales = "free") + labs(title = "Residual QQ plot (20,000 random points)")
rs <- bind_rows(lapply(names(pffr_resid), function(b) data.frame(block = BLOCKS[b], pct = tt, sd = apply(pffr_resid[[b]]$res, 2, sd))))
pr3 <- ggplot(rs, aes(pct, sd)) + geom_line() + facet_wrap(~block) + labs(x = "% of phase", y = "Residual SD (x BW)", title = "Residual SD by phase position")
savefig(pr1 / pr3 / pr2 + plot_layout(heights = c(1.3, 0.8, 1)), "fig5c_pffr_residual_diagnostics.png", 170, 230)
# linearity check: FPC1/FPC2 scores vs predictors (loess)
lin <- bind_rows(lapply(names(Y), function(b) { S <- prcomp(Y[[b]])$x[, 1:2]
  bind_rows(lapply(c("jump_height", "age", "body_mass"), function(v) data.frame(block = BLOCKS[b], predictor = term_lab[v], x = Xdf[[v]],
    PC = rep(c("FPC1", "FPC2"), each = n), score = c(S[, 1], S[, 2])))) }))
pl <- ggplot(lin, aes(x, score)) + geom_point(size = 0.25, colour = "grey60") + geom_smooth(method = "loess", se = FALSE, colour = "black", linewidth = 0.6, formula = y ~ x) +
  geom_smooth(method = "lm", se = FALSE, colour = "black", linetype = "dashed", linewidth = 0.4, formula = y ~ x) +
  facet_grid(block + PC ~ predictor, scales = "free") + labs(x = "Predictor (SD units)", y = "FPC score", title = "Linearity check: loess (solid) vs linear (dashed)") +
  theme(strip.text.y = element_text(size = 6))
savefig(pl, "fig5d_linearity_check.png", 170, 200)

# -----------------------------------------------------------------------------
# 6. CLUSTER VALIDATION: gap statistic incl. k = 1, Mclust BIC incl. G = 1,
#    dip tests, cluster-wise Jaccard (athlete bootstrap; Hennig 2007)
# -----------------------------------------------------------------------------
say("\n[6] Cluster validation (k = 1 / continuum comparison)")
jac <- function(a, b) length(intersect(a, b)) / length(union(a, b))
val_rows <- list(); jac_rows <- list(); sc_plots <- list()
for (b in names(Y)) {
  S <- clus[[b]]$S; k <- clus[[b]]$k; cl <- clus[[b]]$cl
  set.seed(SEED); gp <- clusGap(S, FUNcluster = function(x, k) kmeans(x, k, nstart = 20, iter.max = 100), K.max = 6, B = N_GAP, verbose = FALSE)
  k_gap <- maxSE(gp$Tab[, "gap"], gp$Tab[, "SE.sim"], method = "firstSEmax"); k_gap_tib <- maxSE(gp$Tab[, "gap"], gp$Tab[, "SE.sim"], method = "Tibs2001SEmax")
  mc1 <- Mclust(S, G = 1:6, verbose = FALSE); bic1 <- max(mc1$BIC[1, ], na.rm = TRUE); bic2 <- max(mc1$BIC[2, ], na.rm = TRUE)
  dp1 <- dip.test(S[, 1]); dpl <- if (b == "landing") dip.test(log(tr$landing_to_lowcom_s)) else dip.test(log(tr$contraction_time_s))
  # cluster-wise Jaccard over athlete bootstrap (Hennig 2007): match each original cluster to best bootstrap cluster on the resampled trials
  set.seed(SEED + 7)
  jm <- t(replicate(N_STAB, { s <- unlist(ath_idx[sample(length(ath_idx), replace = TRUE)], use.names = FALSE); u <- unique(s)
    kb <- kmeans(S[u, ], k, nstart = 10, iter.max = 100)$cluster
    sapply(1:k, function(j) { A <- u[cl[u] == j]; max(sapply(1:k, function(h) jac(A, u[kb == h]))) }) }))
  jac_rows[[b]] <- data.frame(block = b, cluster = 1:k, jaccard_mean = colMeans(jm), jaccard_p10 = apply(jm, 2, quantile, .10), share_dissolved = colMeans(jm < 0.5))
  sil <- kc$silhouette[kc$block == b & kc$k == k]
  verdict <- if (k_gap == 1 || sil < 0.25) "no clear cluster structure (continuum)" else if (sil < 0.5 && dp1$p.value > 0.05) "weak structure: partition of a continuum" else if (sil < 0.5) "weak but non-trivial structure" else "clear structure"
  val_rows[[b]] <- data.frame(block = b, k_chosen = k, silhouette = round(sil, 3), gap_k_firstSEmax = k_gap, gap_k_Tibs2001 = k_gap_tib,
    gap_k1 = round(gp$Tab[1, "gap"], 3), gap_k2 = round(gp$Tab[2, "gap"], 3), gap_se2 = round(gp$Tab[2, "SE.sim"], 3),
    mclust_bestG = mc1$G, mclust_bic_G1 = round(bic1, 1), mclust_bic_G2 = round(bic2, 1),
    dip_FPC1_p = signif(dp1$p.value, 3), dip_logduration_p = signif(dpl$p.value, 3), jaccard_min = round(min(colMeans(jm)), 3), verdict = verdict)
  say("    %s: silhouette %.3f; gap picks k = %d (firstSEmax) / %d (Tibs2001); gap(1) = %.3f, gap(2) = %.3f (SE %.3f); Mclust best G = %d, BIC G1 %.0f vs G2 %.0f; dip p FPC1 = %.3g, log-duration = %.3g; Jaccard %s -> %s",
      b, sil, k_gap, k_gap_tib, gp$Tab[1, "gap"], gp$Tab[2, "gap"], gp$Tab[2, "SE.sim"], mc1$G, bic1, bic2, dp1$p.value, dpl$p.value,
      paste(sprintf("%.2f", colMeans(jm)), collapse = "/"), verdict)
  dd <- data.frame(PC1 = S[, 1], PC2 = S[, 2], prof = factor(paste("Profile", cl)))
  sc_plots[[b]] <- (ggplot(dd, aes(PC1, PC2, shape = prof)) + geom_point(size = 0.8, alpha = 0.7) + scale_shape_manual(values = c(1, 17, 3, 4, 8, 15)) +
      labs(shape = NULL, title = BLOCKS[b])) / (ggplot(dd, aes(PC1, fill = prof)) + geom_histogram(bins = 40, colour = "white", position = "stack") +
      scale_fill_manual(values = c("grey25", "grey70", "grey50", "grey85", "grey40", "grey60")) + labs(fill = NULL, y = "Trials")) + plot_layout(heights = c(1.4, 1))
}
wcsv(bind_rows(val_rows), "C4_cluster_validation.csv"); wcsv(bind_rows(jac_rows), "C5_cluster_jaccard.csv")
savefig(wrap_plots(sc_plots, ncol = 2) + plot_annotation(title = "Are the profiles distinct groups or slices of a continuum? FPC scores by profile",
        caption = "If clusters were distinct types, the FPC1 histogram would be multimodal with gaps; a single hump suggests a continuum cut into pieces."), "fig6_cluster_continuum_check.png", 170, 140)

# -----------------------------------------------------------------------------
# 7. SPM: Freedman-Lane adjusted contrasts + effect sizes with athlete-bootstrap CIs
# -----------------------------------------------------------------------------
say("\n[7] SPM adjusted (Freedman-Lane) and effect sizes")
am2 <- tr %>% group_by(athlete) %>% summarise(jh = mean(jump_height_cm), age = mean(age), bm = mean(body_mass_kg), ntr = n(), .groups = "drop")
tcoef <- function(Dm, M) { XtXi <- solve(crossprod(Dm)); B <- XtXi %*% crossprod(Dm, M); E <- M - Dm %*% B
  s2 <- colSums(E^2) / (nrow(Dm) - ncol(Dm)); B[1, ] / sqrt(s2 * XtXi[1, 1]) }
fl_spm <- function(M, g, Z) {  # Freedman-Lane: permute residuals of reduced model (nuisance Z incl. intercept)
  Dm <- cbind(g = as.numeric(g), Z); Hz <- Z %*% solve(crossprod(Z)) %*% t(Z); Fz <- Hz %*% M; Rz <- M - Fz
  thr <- qt(0.975, nrow(M) - ncol(Dm)); t <- tcoef(Dm, M); obs <- clmass(t, thr)
  mx <- replicate(N_PERM, { cm <- clmass(tcoef(Dm, Fz + Rz[sample(nrow(M)), ]), thr); if (nrow(cm)) max(cm$mass) else 0 })
  obs$p <- as.numeric(sapply(obs$mass, function(ms) (1 + sum(mx >= ms)) / (1 + N_PERM)))
  obs$range <- if (nrow(obs)) sprintf("%d-%d%%", pct[obs$start], pct[obs$end]) else character(); list(t = t, obs = obs, thr = thr) }
es_rows <- list(); adj_rows <- list(); delta_curves <- list()
for (b in names(Y)) {
  A <- ath_mean(Y[[b]], tr$athlete); A <- A[match(am2$athlete, rownames(A)), ]
  defs <- list(a = list(sel = am2$jh <= tert[1] | am2$jh >= tert[2], g = am2$jh >= tert[2], Z = c("age", "bm"), lab = "a: top vs bottom jump-height tertile"),
               b = list(sel = rep(TRUE, nrow(am2)), g = am2$age >= 18, Z = c("bm", "jh"), lab = "b: 18+ vs under 18"))
  for (cn in names(defs)) { D <- defs[[cn]]; Ms <- A[D$sel, ]; g <- D$g[D$sel]
    Z <- cbind(1, scale(as.matrix(am2[D$sel, D$Z]))); set.seed(SEED); fl <- fl_spm(Ms, g, Z)
    adj_rows[[paste(cn, b)]] <- if (nrow(fl$obs)) data.frame(contrast = D$lab, block = b, adjusted_for = paste(D$Z, collapse = "+"), fl$obs) else
      data.frame(contrast = D$lab, block = b, adjusted_for = paste(D$Z, collapse = "+"), range = "none")
    say("    %s | %-8s adjusted for %s: %s", D$lab, b, paste(D$Z, collapse = "+"),
        if (nrow(fl$obs)) paste(sprintf("%s (p=%.4f)%s", fl$obs$range, fl$obs$p, ifelse(fl$obs$p < 0.05, "*", "")), collapse = "; ") else "no supra-threshold cluster")
    # effect sizes: stratified athlete bootstrap of the raw difference curve
    G1 <- Ms[g, ]; G2 <- Ms[!g, ]; dhat <- colMeans(G1) - colMeans(G2)
    set.seed(SEED); bd <- t(replicate(N_BOOT, colMeans(G1[sample(nrow(G1), replace = TRUE), ]) - colMeans(G2[sample(nrow(G2), replace = TRUE), ])))
    se <- apply(bd, 2, sd); cs <- quantile(apply(abs(sweep(bd, 2, dhat)) / rep(se, each = N_BOOT), 1, max), .95)
    delta_curves[[paste(cn, b)]] <- data.frame(contrast = D$lab, block = BLOCKS[b], pct = pct, d = dhat, lo_pw = apply(bd, 2, quantile, .025),
      hi_pw = apply(bd, 2, quantile, .975), lo_sim = dhat - cs*se, hi_sim = dhat + cs*se)
    sp <- spm_cl %>% filter(substr(contrast, 1, 1) == cn, block == b, p < 0.05)
    for (i in seq_len(nrow(sp))) { tcur <- spm_t %>% filter(substr(contrast, 1, 1) == cn, block == b)
      j <- (sp$start[i]:sp$end[i])[which.max(abs(tcur$t[sp$start[i]:sp$end[i]]))]
      sdp <- sqrt(((nrow(G1) - 1) * var(G1[, j]) + (nrow(G2) - 1) * var(G2[, j])) / (nrow(G1) + nrow(G2) - 2))
      J <- 1 - 3 / (4 * (nrow(G1) + nrow(G2)) - 9); gH <- J * dhat[j] / sdp
      gb <- apply(bd, 1, function(x) x[j]) / sdp * J
      es_rows[[paste(cn, b, i)]] <- data.frame(contrast = D$lab, block = b, cluster = sp$range[i], p_raw = sp$p[i], survives_bonferroni_4 = sp$p[i] < 0.0125,
        peak_pct = pct[j], diff_bw = round(dhat[j], 3), ci_lo = round(quantile(bd[, j], .025), 3), ci_hi = round(quantile(bd[, j], .975), 3),
        mean_g1 = round(mean(G1[, j]), 3), mean_g2 = round(mean(G2[, j]), 3), hedges_g = round(gH, 2), g_ci_lo = round(quantile(gb, .025), 2), g_ci_hi = round(quantile(gb, .975), 2))
      with(es_rows[[paste(cn, b, i)]], say("      effect at %d%% (peak |t| in %s): diff %.3f BW [%.3f, %.3f]; %.2f vs %.2f BW; Hedges g %.2f [%.2f, %.2f]; Bonferroni(4) %s",
        peak_pct, cluster, diff_bw, ci_lo, ci_hi, mean_g1, mean_g2, hedges_g, g_ci_lo, g_ci_hi, ifelse(survives_bonferroni_4, "yes", "no"))) }
  }
}
wcsv(bind_rows(adj_rows), "S2_spm_adjusted_freedman_lane.csv"); wcsv(bind_rows(es_rows), "S3_spm_effect_sizes.csv"); wcsv(bind_rows(delta_curves), "S4_delta_curves.csv")
pdc <- ggplot(bind_rows(delta_curves), aes(pct, d)) + geom_ribbon(aes(ymin = lo_sim, ymax = hi_sim), fill = "grey85") +
  geom_ribbon(aes(ymin = lo_pw, ymax = hi_pw), fill = "grey60") + geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.3) + geom_line(linewidth = 0.6) +
  facet_grid(contrast ~ block, scales = "free_y") + labs(x = "% of phase", y = "Difference in mean force (x BW)",
  title = "Effect-size curves: group differences with athlete-bootstrap 95% bands", caption = "(a) top minus bottom jump-height tertile; (b) 18+ minus under-18. Dark: pointwise; light: simultaneous (sup-t). Athlete-mean curves.")
savefig(pdc, "fig7_spm_effect_size_curves.png", 170, 130)

# 8. Registration sensitivity (elastic SRVF alignment of landing): see srvf_landing.R (run by run_all.R)

say("\nRuntime: %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
close(log_con)
