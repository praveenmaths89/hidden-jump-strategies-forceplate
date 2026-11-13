# =============================================================================
# 03_analysis.R (= R/run_all.R of the paper repository; only output folders renamed) -- Hidden jump strategies beyond conventional force-plate metrics
# One end-to-end, sectioned R pipeline: de-identified data -> QC -> body-weight
# and phase normalisation -> PCA -> interpretation -> matched-band dispersion
# -> regression -> robustness -> variance decomposition -> reproduction check
# -> manuscript figures, LaTeX tables and in-text numbers.
#
# Usage (from the repository root):   Rscript R/run_all.R
# Input : data/cmj_trials_deidentified.csv (833 trials, pseudonymous codes)
# Output: outputs/main_lowest_com/      main analysis (landing to lowest COM)
#         outputs/sensitivity_1s/       sensitivity (landing = 1 s after touch-down)
#         outputs/reproduction_check.csv  comparison with the BAICONF 2026 report
#         paper/figures, paper/submission_figures, paper/tables, paper/generated
# Every number, table and figure in the manuscript is written by this script.
# =============================================================================

# -----------------------------------------------------------------------------
# 0. SETUP: packages, constants, folders, plotting style
# -----------------------------------------------------------------------------
t_start <- Sys.time()
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(patchwork); library(nlme)
})
if (!file.exists("data/cmj_trials_deidentified.csv"))
  stop("Run from the package root: Rscript R/00_run_all.R")

SEED      <- 2026   # one seed for every random step (CV folds, one-trial draw, bootstrap)
G         <- 9.81   # gravitational acceleration (m s^-2)
N_KEEP_PC <- 4      # retained principal components (fixed a priori, as in the abstract)
K_SD      <- 2      # perturbation size for mean +/- k SD reconstructions
BAND_LOW  <- 0.45   # matched band: trials between the 45th ...
BAND_HIGH <- 0.55   # ... and 55th percentile of the matching metric
N_BOOT    <- 2000   # athlete-level bootstrap resamples
N_FOLD    <- 5      # athlete-grouped cross-validation folds
WINDOWS <- list(
  main_lowest_com = list(prefix = "^ldc_", label = "Touch-down to lowest centre of mass", qc_r5 = TRUE),
  sensitivity_1s  = list(prefix = "^ld_",  label = "Touch-down to 1 s after touch-down", qc_r5 = FALSE))
PREDICTORS <- c("jump_height_cm", "conc_peak_force_n", "ecc_braking_impulse_ns",
                "conc_impulse_100ms_ns", "age", "body_mass_kg")
RHS <- paste(PREDICTORS, collapse = " + ")

DIR_PAPER_FIG <- "output/paper_figures"; DIR_SUB_FIG <- "output/paper_figures_eps"
DIR_PAPER_TAB <- "output/paper_tables_latex";  DIR_GEN     <- "output/paper_numbers"
for (d in c("output", DIR_PAPER_FIG, DIR_SUB_FIG, DIR_PAPER_TAB, DIR_GEN))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

OKABE <- c(blue = "#0072B2", vermillion = "#D55E00", green = "#009E73",
           orange = "#E69F00", sky = "#56B4E9", purple = "#CC79A7", black = "#000000")
theme_paper <- theme_bw(base_size = 8, base_family = "Arial") +
  theme(panel.grid.minor = element_blank(), strip.background = element_rect(fill = "grey95"),
        legend.key.height = unit(3, "mm"), plot.title = element_text(size = 8, face = "bold"),
        plot.tag = element_text(size = 9, face = "bold"))
theme_set(theme_paper)
X_BREAKS <- c(1, 51, 101.5, 152, 202)
X_LABELS <- c("0", "50", "100 | 0", "50", "100")

# Save a ggplot as 300-dpi PNG (outputs), vector PDF (manuscript) and EPS (submission)
save_fig <- function(p, name, w_mm, h_mm, out_dir = NULL, paper = TRUE) {
  w <- w_mm / 25.4; h <- h_mm / 25.4
  if (!is.null(out_dir)) ggsave(file.path(out_dir, paste0(name, ".png")), p, width = w, height = h, dpi = 300)
  if (paper) {
    ggsave(file.path(DIR_PAPER_FIG, paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
    ggsave(file.path(DIR_SUB_FIG, paste0(name, ".eps")), p, width = w, height = h,
           device = function(...) cairo_ps(..., fallback_resolution = 600))
  }
}
fmt <- function(x, d = 2) formatC(x, format = "f", digits = d)
neg <- function(s) { s <- sub("^-(0\\.?0*)$", "\\1", s); gsub("^-", "$-$", s) }   # LaTeX minus; no "-0.00"
write_tab <- function(x, dir, name) write.csv(x, file.path(dir, paste0(name, ".csv")), row.names = FALSE)

# -----------------------------------------------------------------------------
# 1. LOAD the de-identified trial file
# -----------------------------------------------------------------------------
trials_raw <- read.csv("data/cmj_trials_deidentified.csv")
cat(sprintf("[1] Loaded %d trials, %d athletes, %d sessions\n", nrow(trials_raw),
            n_distinct(trials_raw$athlete), n_distinct(trials_raw$test_code)))

# -----------------------------------------------------------------------------
# Analysis of one landing-window definition (sections 2-9). Returns a list of
# results; writes tables/figures to outputs/<window>/.
# -----------------------------------------------------------------------------
run_window <- function(win_name) {
  win <- WINDOWS[[win_name]]
  out <- file.path("output", win_name)
  dir_tab <- file.path(out, "tables"); dir_fig <- file.path(out, "figures"); dir_int <- file.path(out, "intermediate")
  for (d in c(dir_tab, dir_fig, dir_int)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  cat(sprintf("\n==== Analysis: %s (%s) ====\n", win_name, win$label))

  # ---------------------------------------------------------------------------
  # 2. QUALITY CONTROL (rules fixed before any result was examined)
  #   R1 valid VALD body mass; R2 quiet-stance mass within 5 % of body mass;
  #   R3 mean force during flight <= 50 N; R4 complete metrics and age;
  #   R5 landing end (lowest COM) found -- lowest-COM window only
  # ---------------------------------------------------------------------------
  tr <- trials_raw %>% mutate(
    fail_r1 = is.na(body_mass_kg) | body_mass_kg <= 0,
    fail_r2 = !fail_r1 & abs(quiet_mass_kg - body_mass_kg) / body_mass_kg > 0.05,
    fail_r3 = abs(flight_force_n) > 50,
    fail_r4 = is.na(age) | is.na(jump_height_cm) | is.na(conc_peak_force_n) |
              is.na(ecc_braking_impulse_ns) | is.na(conc_impulse_100ms_ns),
    fail_r5 = win$qc_r5 & is.na(ldc_050))
  steps <- list(tr)
  for (r in paste0("fail_r", 1:5)) steps[[length(steps) + 1]] <- steps[[length(steps)]][!steps[[length(steps)]][[r]], ]
  qc_flow <- data.frame(
    step = c("All male football CMJ trials", "R1: valid body mass",
             "R2: quiet-stance mass within 5% of body mass", "R3: no force on plate during flight",
             "R4: complete metrics and age", "R5: end of landing (lowest COM) found"),
    trials = sapply(steps, nrow), athletes = sapply(steps, function(s) n_distinct(s$athlete)),
    sessions = sapply(steps, function(s) n_distinct(s$test_code)))
  if (!win$qc_r5) qc_flow <- qc_flow[1:5, ]
  write_tab(qc_flow, dir_tab, "T0_qc_flow"); print(qc_flow)
  tr <- steps[[if (win$qc_r5) 6 else 5]]

  # ---------------------------------------------------------------------------
  # 3. NORMALISATION: force / body weight; take-off and landing each resampled
  #    to 101 points (done in the private extraction step) and joined end to
  #    end without flight -> 202-point curve per trial
  # ---------------------------------------------------------------------------
  bw_n <- tr$body_mass_kg * G
  to_bw <- as.matrix(tr[, grep("^to_", names(tr))]) / bw_n
  ld_bw <- as.matrix(tr[, grep(win$prefix, names(tr))]) / bw_n
  curves <- cbind(to_bw, ld_bw)
  colnames(curves) <- c(sprintf("to_bw_%03d", 0:100), sprintf("ld_bw_%03d", 0:100))
  meta <- tr %>% transmute(athlete, test_code, trial_no, age, body_mass_kg, native_fs,
    jump_height_cm, conc_peak_force_n, rel_conc_peak_force_bw = conc_peak_force_n / (body_mass_kg * G),
    ecc_braking_impulse_ns, conc_impulse_100ms_ns, peak_landing_force_n,
    landing_peak_force_bw = peak_landing_force_n / (body_mass_kg * G),
    cm_depth_cm, contraction_time_s, landing_to_lowcom_s)
  write.csv(cbind(meta, round(curves, 4)), file.path(dir_int, "cmj_curves_bw_concatenated.csv"), row.names = FALSE)

  # ---------------------------------------------------------------------------
  # 4. PCA (centred, unscaled covariance PCA of the 202-point curves)
  # ---------------------------------------------------------------------------
  pca <- prcomp(curves, center = TRUE, scale. = FALSE)
  ev <- pca$sdev^2
  var_tab <- data.frame(component = paste0("PC", seq_along(ev)), sd_score = pca$sdev,
                        variance_pct = 100 * ev / sum(ev), cumulative_pct = 100 * cumsum(ev) / sum(ev))[1:10, ]
  write_tab(var_tab, dir_tab, "T2_pca_variance_explained")
  scores <- as.data.frame(pca$x[, 1:N_KEEP_PC])
  for (k in 1:N_KEEP_PC) {        # sign convention: largest absolute loading positive
    j <- which.max(abs(pca$rotation[, k]))
    if (pca$rotation[j, k] < 0) { pca$rotation[, k] <- -pca$rotation[, k]; scores[, k] <- -scores[, k] }
  }
  pcs <- paste0("PC", 1:N_KEEP_PC)
  dat <- cbind(meta, scores)
  write.csv(cbind(meta[, c("athlete", "test_code", "trial_no")], round(scores, 5)),
            file.path(dir_tab, "pc_scores_deidentified.csv"), row.names = FALSE)

  # ---------------------------------------------------------------------------
  # 5. INTERPRETATION: loading share by phase, location of largest loading,
  #    Pearson correlations with interpretable descriptors
  # ---------------------------------------------------------------------------
  phase <- do.call(rbind, lapply(1:N_KEEP_PC, function(k) {
    l2 <- pca$rotation[, k]^2
    j <- which.max(abs(pca$rotation[, k]))
    data.frame(component = pcs[k], takeoff_share_pct = 100 * sum(l2[1:101]),
               landing_share_pct = 100 * sum(l2[102:202]), peak_point = names(j),
               peak_phase = ifelse(j <= 101, "Take-off", "Landing"), peak_pct = (j - 1) %% 101)
  }))
  write_tab(phase, dir_tab, "T5b_pc_loading_by_phase")
  descriptors <- c("Landing peak force (x BW)" = "landing_peak_force_bw",
    "Contraction time (s)" = "contraction_time_s", "Countermovement depth (cm)" = "cm_depth_cm",
    "Jump height (cm)" = "jump_height_cm", "Concentric peak force (N)" = "conc_peak_force_n",
    "Concentric peak force (x BW)" = "rel_conc_peak_force_bw",
    "Eccentric braking impulse (N s)" = "ecc_braking_impulse_ns",
    "Concentric impulse 100 ms (N s)" = "conc_impulse_100ms_ns", "Age (years)" = "age",
    "Body mass (kg)" = "body_mass_kg",
    "Touch-down to lowest COM (s)" = "landing_to_lowcom_s")
  cors <- data.frame(descriptor = names(descriptors))
  for (pc in pcs) cors[[pc]] <- sapply(descriptors, function(d) cor(dat[[pc]], dat[[d]], use = "complete.obs"))
  write_tab(cors, dir_tab, "T5_pc_correlations_with_descriptors")

  # ---------------------------------------------------------------------------
  # 6. MATCHED-BAND DISPERSION: SD of each PC score among trials in the
  #    45th-55th percentile of jump height (or relative peak force) divided
  #    by its SD in the full sample; whole curve = sqrt(total variance ratio)
  # ---------------------------------------------------------------------------
  jh_lim <- quantile(dat$jump_height_cm, c(BAND_LOW, BAND_HIGH))
  rpf_lim <- quantile(dat$rel_conc_peak_force_bw, c(BAND_LOW, BAND_HIGH))
  in_jh <- dat$jump_height_cm >= jh_lim[1] & dat$jump_height_cm <= jh_lim[2]
  in_rpf <- dat$rel_conc_peak_force_bw >= rpf_lim[1] & dat$rel_conc_peak_force_bw <= rpf_lim[2]
  tv <- function(rows) sum(apply(curves[rows, , drop = FALSE], 2, var))
  band <- do.call(rbind, lapply(pcs, function(pc) data.frame(component = pc,
    sd_full_sample = sd(dat[[pc]]), sd_jump_height_band = sd(dat[[pc]][in_jh]),
    ratio_jump_height = sd(dat[[pc]][in_jh]) / sd(dat[[pc]]),
    sd_rel_peak_force_band = sd(dat[[pc]][in_rpf]), ratio_rel_peak_force = sd(dat[[pc]][in_rpf]) / sd(dat[[pc]]))))
  all_rows <- rep(TRUE, nrow(dat))
  band <- rbind(band, data.frame(component = "Whole curve (sqrt total variance)",
    sd_full_sample = sqrt(tv(all_rows)), sd_jump_height_band = sqrt(tv(in_jh)),
    ratio_jump_height = sqrt(tv(in_jh) / tv(all_rows)), sd_rel_peak_force_band = sqrt(tv(in_rpf)),
    ratio_rel_peak_force = sqrt(tv(in_rpf) / tv(all_rows))))
  write_tab(band, dir_tab, "T3_matched_band_dispersion")
  band_def <- data.frame(band = c("Jump height (cm)", "Concentric peak force (x BW)"),
    lower = c(jh_lim[1], rpf_lim[1]), upper = c(jh_lim[2], rpf_lim[2]),
    n_trials = c(sum(in_jh), sum(in_rpf)),
    n_athletes = c(n_distinct(dat$athlete[in_jh]), n_distinct(dat$athlete[in_rpf])),
    band_mean = c(mean(dat$jump_height_cm[in_jh]), mean(dat$rel_conc_peak_force_bw[in_rpf])),
    band_sd = c(sd(dat$jump_height_cm[in_jh]), sd(dat$rel_conc_peak_force_bw[in_rpf])))
  write_tab(band_def, dir_tab, "T3b_matched_band_definitions")

  # ---------------------------------------------------------------------------
  # 7. REGRESSION: PC score ~ 4 vendor metrics + age + body mass (OLS)
  # ---------------------------------------------------------------------------
  r2 <- do.call(rbind, lapply(pcs, function(pc) {
    fit <- lm(as.formula(paste(pc, "~", RHS)), data = dat)
    co <- as.data.frame(summary(fit)$coefficients); co$term <- rownames(co)
    write_tab(co, dir_tab, paste0("S1_regression_coefficients_", pc))
    data.frame(component = pc, n_trials = nobs(fit), r_squared = summary(fit)$r.squared,
               adj_r_squared = summary(fit)$adj.r.squared, unexplained_pct = 100 * (1 - summary(fit)$r.squared))
  }))
  write_tab(r2, dir_tab, "T4_regression_variance_explained")

  # ---------------------------------------------------------------------------
  # 8. ROBUSTNESS (random steps in a fixed order after one seed)
  #   A athlete-grouped 5-fold CV R^2; B one random trial per athlete and
  #   athlete means; C athlete bootstrap CIs of band SD ratios; D band widths
  # ---------------------------------------------------------------------------
  set.seed(SEED)
  ath <- unique(dat$athlete)
  fold <- sample(rep(1:N_FOLD, length.out = length(ath)))[match(dat$athlete, ath)]
  cv <- do.call(rbind, lapply(pcs, function(pc) {
    pred <- rep(NA_real_, nrow(dat))
    for (f in 1:N_FOLD) pred[fold == f] <- predict(lm(as.formula(paste(pc, "~", RHS)), data = dat[fold != f, ]),
                                                   newdata = dat[fold == f, ])
    data.frame(component = pc, cv_r_squared = 1 - sum((dat[[pc]] - pred)^2) / sum((dat[[pc]] - mean(dat[[pc]]))^2))
  }))
  write_tab(cv, dir_tab, "R1_cv_variance_explained")
  shuffled <- dat[sample(nrow(dat)), ]
  one_trial <- shuffled[!duplicated(shuffled$athlete), ]
  ath_mean <- dat %>% group_by(athlete) %>% summarise(across(all_of(c(pcs, PREDICTORS)), mean), .groups = "drop")
  rb <- do.call(rbind, lapply(pcs, function(pc) {
    f1 <- lm(as.formula(paste(pc, "~", RHS)), data = one_trial)
    f2 <- lm(as.formula(paste(pc, "~", RHS)), data = ath_mean)
    data.frame(component = pc, r2_one_trial_per_athlete = summary(f1)$r.squared, n_one_trial = nobs(f1),
               r2_athlete_means = summary(f2)$r.squared, n_athletes = nobs(f2))
  }))
  write_tab(rb, dir_tab, "R2_one_trial_and_athlete_mean")
  rows_of <- split(seq_len(nrow(dat)), dat$athlete)
  boot_jh <- boot_rpf <- matrix(NA, N_BOOT, N_KEEP_PC, dimnames = list(NULL, pcs))
  for (b in 1:N_BOOT) {
    rows <- unlist(rows_of[sample(names(rows_of), replace = TRUE)])
    bd <- dat[rows, ]; bj <- in_jh[rows]; br <- in_rpf[rows]
    for (pc in pcs) { boot_jh[b, pc] <- sd(bd[[pc]][bj]) / sd(bd[[pc]]); boot_rpf[b, pc] <- sd(bd[[pc]][br]) / sd(bd[[pc]]) }
  }
  ci <- data.frame(component = pcs, jh_ratio = band$ratio_jump_height[1:N_KEEP_PC],
    jh_ci_low = apply(boot_jh, 2, quantile, 0.025), jh_ci_high = apply(boot_jh, 2, quantile, 0.975),
    rpf_ratio = band$ratio_rel_peak_force[1:N_KEEP_PC],
    rpf_ci_low = apply(boot_rpf, 2, quantile, 0.025), rpf_ci_high = apply(boot_rpf, 2, quantile, 0.975))
  write_tab(ci, dir_tab, "R3_bootstrap_band_sd_ratio")
  jh <- dat$jump_height_cm
  rules <- list("45th-55th percentile (main)" = jh >= quantile(jh, .45) & jh <= quantile(jh, .55),
                "40th-60th percentile" = jh >= quantile(jh, .40) & jh <= quantile(jh, .60),
                "Median +/- 1 cm" = abs(jh - median(jh)) <= 1, "Median +/- 2 cm" = abs(jh - median(jh)) <= 2)
  bw <- do.call(rbind, lapply(names(rules), function(r) { i <- rules[[r]]
    x <- data.frame(band = r, n_trials = sum(i), jh_mean = mean(jh[i]), jh_sd = sd(jh[i]))
    for (pc in pcs) x[[paste0(pc, "_sd_ratio")]] <- sd(dat[[pc]][i]) / sd(dat[[pc]]); x }))
  write_tab(bw, dir_tab, "R4_band_width_sensitivity")

  # ---------------------------------------------------------------------------
  # 9. VARIANCE DECOMPOSITION (added for the journal paper): three-level
  #    random-intercept model PC ~ 1 + (1 | athlete / session), REML.
  #    Shares of between-athlete, between-session (within athlete) and
  #    between-trial (within session) variance of each component score.
  # ---------------------------------------------------------------------------
  vd <- do.call(rbind, lapply(pcs, function(pc) {
    d <- data.frame(y = dat[[pc]], athlete = factor(dat$athlete), session = factor(dat$test_code))
    m <- lme(y ~ 1, random = ~ 1 | athlete / session, data = d, method = "REML")
    vc <- suppressWarnings(as.numeric(VarCorr(m)[c(2, 4, 5), "Variance"]))
    data.frame(component = pc, between_athlete_pct = 100 * vc[1] / sum(vc),
               between_session_pct = 100 * vc[2] / sum(vc), within_session_pct = 100 * vc[3] / sum(vc))
  }))
  write_tab(vd, dir_tab, "R5_variance_decomposition")

  # ---------------------------------------------------------------------------
  # 10. DESCRIPTIVES (athlete-level rows use each athlete's first trial in file)
  # ---------------------------------------------------------------------------
  desc <- function(x, label) data.frame(variable = label, n = sum(!is.na(x)), mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE), median = median(x, na.rm = TRUE), q1 = quantile(x, .25, na.rm = TRUE),
    q3 = quantile(x, .75, na.rm = TRUE), min = min(x, na.rm = TRUE), max = max(x, na.rm = TRUE))
  first <- dat[!duplicated(dat$athlete), ]
  t1 <- rbind(desc(first$age, "Age at first test (years)"), desc(first$body_mass_kg, "Body mass at first test (kg)"),
    desc(dat$jump_height_cm, "Jump height, flight time (cm)"), desc(dat$conc_peak_force_n, "Concentric peak force (N)"),
    desc(dat$rel_conc_peak_force_bw, "Concentric peak force (x BW)"),
    desc(dat$ecc_braking_impulse_ns, "Eccentric braking impulse (N s)"),
    desc(dat$conc_impulse_100ms_ns, "Concentric impulse, first 100 ms (N s)"),
    desc(dat$landing_peak_force_bw, "Peak landing force (x BW)"), desc(dat$contraction_time_s, "Contraction time (s)"),
    desc(dat$cm_depth_cm, "Countermovement depth (cm)"), desc(dat$landing_to_lowcom_s, "Touch-down to lowest COM (s)"),
    desc(as.numeric(table(dat$athlete)), "Trials per athlete"),
    desc(as.numeric(table(dat$test_code)), "Trials per session"),
    desc(as.numeric(tapply(dat$test_code, dat$athlete, n_distinct)), "Sessions per athlete"))
  rownames(t1) <- NULL
  write_tab(t1, dir_tab, "T1_descriptives")

  # ---------------------------------------------------------------------------
  # 11. WINDOW-SPECIFIC FIGURES (PNG in outputs/<window>/figures)
  # ---------------------------------------------------------------------------
  mc <- data.frame(position = 1:202, mean_bw = colMeans(curves), sd_bw = apply(curves, 2, sd))
  pert <- do.call(rbind, lapply(1:N_KEEP_PC, function(k) {
    s <- K_SD * pca$sdev[k] * pca$rotation[, k]
    lab <- sprintf("PC%d (%.1f%% of variance)", k, var_tab$variance_pct[k])
    rbind(data.frame(pc = lab, position = 1:202, curve = "Mean", force = pca$center),
          data.frame(pc = lab, position = 1:202, curve = sprintf("+%d SD", K_SD), force = pca$center + s),
          data.frame(pc = lab, position = 1:202, curve = sprintf("\u2212%d SD", K_SD), force = pca$center - s))
  }))
  pert$curve <- factor(pert$curve, levels = c("Mean", sprintf("+%d SD", K_SD), sprintf("\u2212%d SD", K_SD)))
  fig_pert <- ggplot(pert, aes(position, force, colour = curve, linetype = curve)) +
    geom_vline(xintercept = 101.5, colour = "grey60", linewidth = 0.3) +
    geom_line(linewidth = 0.45) + facet_wrap(~ pc, ncol = 2) +
    scale_colour_manual(values = c("black", unname(OKABE["vermillion"]), unname(OKABE["blue"]))) +
    scale_linetype_manual(values = c("dashed", "solid", "solid")) +
    scale_x_continuous(breaks = X_BREAKS, labels = X_LABELS) +
    labs(x = "Take-off phase (%)  |  Landing phase (%)", y = "Vertical force (\u00d7 body weight)",
         colour = NULL, linetype = NULL) + theme(legend.position = "bottom")
  save_fig(fig_pert, "pc_perturbations", 174, 110, out_dir = dir_fig, paper = FALSE)

  list(name = win_name, label = win$label, qc = qc_flow, meta = meta, dat = dat, curves = curves, pca = pca,
       var = var_tab, phase = phase, cors = cors, band = band, band_def = band_def, in_jh = in_jh, in_rpf = in_rpf,
       r2 = r2, cv = cv, rb = rb, ci = ci, bw = bw, vd = vd, t1 = t1, mc = mc, fig_pert = fig_pert)
}

RES <- lapply(names(WINDOWS), run_window); names(RES) <- names(WINDOWS)
M <- RES$main_lowest_com; S <- RES$sensitivity_1s

# -----------------------------------------------------------------------------
# 12. REPRODUCTION CHECK against the numbers printed in the delivered BAICONF
#     2026 analysis report (validation/baiconf_report_values.csv)
# -----------------------------------------------------------------------------
key_values <- function(R) {
  lp <- function(pc, d) R$cors[R$cors$descriptor == d, pc]
  c(trials_after_qc = nrow(R$dat), athletes_after_qc = n_distinct(R$dat$athlete),
    setNames(R$var$variance_pct[1:4], paste0("pc", 1:4, "_variance_pct")),
    cum4_variance_pct = R$var$cumulative_pct[4],
    setNames(R$phase$landing_share_pct, paste0("pc", 1:4, "_landing_share_pct")),
    jh_band_n_trials = R$band_def$n_trials[1], jh_band_mean_cm = R$band_def$band_mean[1],
    jh_band_sd_cm = R$band_def$band_sd[1], rpf_band_n_trials = R$band_def$n_trials[2],
    pc1_sd_full = R$band$sd_full_sample[1], pc1_sd_jh_band = R$band$sd_jump_height_band[1],
    setNames(R$ci$jh_ratio, paste0("pc", 1:4, "_jh_ratio")),
    pc1_jh_ratio_ci_low = R$ci$jh_ci_low[1], pc1_jh_ratio_ci_high = R$ci$jh_ci_high[1],
    whole_curve_jh_ratio = R$band$ratio_jump_height[5], whole_curve_rpf_ratio = R$band$ratio_rel_peak_force[5],
    setNames(100 * R$r2$r_squared, paste0("pc", 1:4, "_r2_pct")),
    setNames(100 * R$cv$cv_r_squared, paste0("pc", 1:4, "_cv_r2_pct")),
    pc3_r2_athlete_means_pct = 100 * R$rb$r2_athlete_means[3],
    r_pc1_landing_peak_force = lp("PC1", "Landing peak force (x BW)"),
    r_pc4_landing_peak_force = lp("PC4", "Landing peak force (x BW)"),
    r_pc1_contraction_time = lp("PC1", "Contraction time (s)"),
    r_pc3_contraction_time = lp("PC3", "Contraction time (s)"))
}
ref <- read.csv("validation/baiconf_report_values.csv")
kv <- list(main = key_values(M), sensitivity_1s = key_values(S))
ref$this_run <- mapply(function(a, q) unname(kv[[a]][q]), ref$analysis, ref$quantity)
ref$this_run_rounded <- mapply(function(x, d) round(x, d), ref$this_run, ref$decimals)
ref$match <- abs(ref$this_run_rounded - ref$report_value) < 1e-9
write.csv(ref, "output/reproduction_check.csv", row.names = FALSE)
cat(sprintf("\n[12] Reproduction check: %d of %d report values reproduced exactly at printed precision\n",
            sum(ref$match), nrow(ref)))
if (any(!ref$match)) print(ref[!ref$match, ])

# -----------------------------------------------------------------------------
# 13. MANUSCRIPT FIGURES (vector PDF + EPS at final print size; Arial 8 pt;
#     Okabe-Ito colours). Figure 1 (pipeline) is TikZ in paper/floats.
# -----------------------------------------------------------------------------
# Figure 2: mean curve +/- 1 SD (A) and scree plot (B), main analysis
fig2a <- ggplot(M$mc, aes(position, mean_bw)) +
  geom_ribbon(aes(ymin = mean_bw - sd_bw, ymax = mean_bw + sd_bw), fill = "grey80") +
  geom_line(linewidth = 0.5) + geom_vline(xintercept = 101.5, linetype = "dashed", linewidth = 0.3) +
  geom_hline(yintercept = 1, colour = "grey50", linewidth = 0.25, linetype = "dotted") +
  annotate("text", x = 51, y = max(M$mc$mean_bw + M$mc$sd_bw) * 1.04, label = "Take-off: onset to take-off", size = 2.6, family = "Arial") +
  annotate("text", x = 152, y = max(M$mc$mean_bw + M$mc$sd_bw) * 1.04, label = "Landing: touch-down to lowest COM", size = 2.6, family = "Arial") +
  scale_x_continuous(breaks = X_BREAKS, labels = X_LABELS) +
  labs(tag = "A", x = "Take-off phase (%)  |  Landing phase (%)", y = "Vertical force (\u00d7 body weight)")
sc <- M$var; sc$component <- factor(sc$component, levels = sc$component)
fig2b <- ggplot(sc, aes(component)) + geom_col(aes(y = variance_pct), fill = "grey60", width = 0.7) +
  geom_line(aes(y = cumulative_pct, group = 1), linewidth = 0.4) + geom_point(aes(y = cumulative_pct), size = 1) +
  geom_vline(xintercept = N_KEEP_PC + 0.5, linetype = "dashed", linewidth = 0.3) +
  scale_x_discrete(labels = sub("PC", "", levels(sc$component))) +
  labs(tag = "B", x = "Principal component", y = "Variance explained (%)")
save_fig(fig2a + fig2b + plot_layout(widths = c(2.2, 1)), "Fig2_mean_curve_scree", 174, 70)

# Figure 3: PC reconstructions, main analysis; Figure 6: same for 1-s window
save_fig(M$fig_pert, "Fig3_pc_reconstructions_main", 174, 110)
save_fig(S$fig_pert, "Fig6_pc_reconstructions_1s", 174, 110)

# Figure 4: matched band (A) curves of the jump-height band coloured by PC1; (B) SD ratios with 95% CI
bc <- as.data.frame(M$curves[M$in_jh, ]); bc$trial <- seq_len(nrow(bc)); bc$PC1 <- M$dat$PC1[M$in_jh]
bl <- bc %>% pivot_longer(-c(trial, PC1), values_to = "force") %>% group_by(trial) %>% mutate(position = row_number()) %>% ungroup()
fig4a <- ggplot(bl, aes(position, force, group = trial, colour = PC1)) + geom_line(alpha = 0.7, linewidth = 0.25) +
  geom_vline(xintercept = 101.5, linetype = "dashed", linewidth = 0.3) +
  scale_colour_gradient2(low = OKABE["blue"], mid = "grey85", high = OKABE["vermillion"]) +
  scale_x_continuous(breaks = X_BREAKS, labels = X_LABELS) +
  labs(tag = "A", x = "Take-off phase (%)  |  Landing phase (%)", y = "Vertical force (\u00d7 body weight)", colour = "PC1 score")
fr <- rbind(data.frame(component = M$ci$component, band = "Jump height", ratio = M$ci$jh_ratio, lo = M$ci$jh_ci_low, hi = M$ci$jh_ci_high),
            data.frame(component = M$ci$component, band = "Relative concentric peak force", ratio = M$ci$rpf_ratio, lo = M$ci$rpf_ci_low, hi = M$ci$rpf_ci_high))
fr$component <- factor(fr$component, levels = rev(paste0("PC", 1:N_KEEP_PC)))
fig4b <- ggplot(fr, aes(ratio, component, colour = band, shape = band)) +
  geom_vline(xintercept = 1, colour = "grey50", linewidth = 0.3) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, orientation = "y", position = position_dodge(width = 0.5), linewidth = 0.4) +
  geom_point(position = position_dodge(width = 0.5), size = 1.6) +
  scale_colour_manual(values = unname(OKABE[c("blue", "vermillion")])) +
  labs(tag = "B", x = "SD ratio, band / full sample (95% CI)", y = NULL, colour = "Matched on", shape = "Matched on") +
  theme(legend.position = "bottom", legend.direction = "vertical")
save_fig(fig4a + fig4b + plot_layout(widths = c(1.7, 1)), "Fig4_matched_band", 174, 80)

# Figure 5: variance explained by the conventional metrics under four evaluation schemes, both windows
r2l <- do.call(rbind, lapply(list(M, S), function(R) rbind(
  data.frame(window = R$label, component = R$r2$component, scheme = "In-sample (all trials)", r2 = 100 * R$r2$r_squared),
  data.frame(window = R$label, component = R$cv$component, scheme = "Athlete-grouped 5-fold CV", r2 = 100 * R$cv$cv_r_squared),
  data.frame(window = R$label, component = R$rb$component, scheme = "One trial per athlete", r2 = 100 * R$rb$r2_one_trial_per_athlete),
  data.frame(window = R$label, component = R$rb$component, scheme = "Athlete means", r2 = 100 * R$rb$r2_athlete_means))))
r2l$scheme <- factor(r2l$scheme, levels = unique(r2l$scheme)); r2l$window <- factor(r2l$window, levels = c(M$label, S$label))
fig5 <- ggplot(r2l, aes(component, r2, fill = scheme)) + geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  facet_wrap(~ window) + scale_fill_manual(values = unname(OKABE[c("black", "blue", "orange", "sky")])) +
  scale_y_continuous(limits = c(0, 100), expand = expansion(mult = c(0, 0.02))) +
  labs(x = NULL, y = expression("Variance of component score explained, " * R^2 * " (%)"), fill = NULL) +
  theme(legend.position = "bottom") + guides(fill = guide_legend(nrow = 2))
save_fig(fig5, "Fig5_variance_explained", 174, 80)

# -----------------------------------------------------------------------------
# 14. LATEX TABLES (paper/tables/*.tex), written from the result objects
# -----------------------------------------------------------------------------
tex_rows <- function(df) paste(apply(df, 1, function(r) paste(r, collapse = " & ")), "\\\\")
write_tex <- function(lines, name) writeLines(lines, file.path(DIR_PAPER_TAB, paste0(name, ".tex")))
lab_tex <- function(s) { s <- gsub("x BW", "$\\\\times$\\\\,BW", s); gsub("N s", "N\\\\,s", s) }

# Table 1: QC flow (main window; 1-s window differs only by R5)
q <- M$qc
write_tex(c("\\begin{tabular}{lrrr}", "\\toprule", "Step & Trials & Sessions & Athletes \\\\", "\\midrule",
  tex_rows(data.frame(gsub("%", "\\%", q$step, fixed = TRUE), q$trials, q$sessions, q$athletes)), "\\bottomrule", "\\end{tabular}"), "tab1_qc")  # FIX (package): escape % so the R2 row is not swallowed by LaTeX

# Table 2: descriptives (main window)
d <- M$t1
d2 <- data.frame(lab_tex(d$variable), d$n, paste0(neg(fmt(d$mean)), " $\\pm$ ", fmt(d$sd)),
  paste0(neg(fmt(d$median)), " (", neg(fmt(d$q1)), " to ", neg(fmt(d$q3)), ")"),
  paste0(neg(fmt(d$min)), " to ", neg(fmt(d$max))))
write_tex(c("\\begin{tabular}{lrlll}", "\\toprule", "Variable & $n$ & Mean $\\pm$ SD & Median (IQR) & Range \\\\", "\\midrule",
  tex_rows(d2), "\\bottomrule", "\\end{tabular}"), "tab2_descriptives")

# Table 3: retained components (variance, location, correlations), main window
cr <- function(R, d) R$cors[R$cors$descriptor == d, paste0("PC", 1:N_KEEP_PC)]
t3 <- data.frame(M$var$component[1:4], fmt(M$var$variance_pct[1:4], 1), fmt(M$var$cumulative_pct[1:4], 1),
  fmt(M$phase$landing_share_pct, 1), paste0(M$phase$peak_phase, " ", M$phase$peak_pct, "\\%"),
  neg(fmt(unlist(cr(M, "Landing peak force (x BW)")))), neg(fmt(unlist(cr(M, "Jump height (cm)")))),
  neg(fmt(unlist(cr(M, "Contraction time (s)")))), neg(fmt(unlist(cr(M, "Countermovement depth (cm)")))), neg(fmt(unlist(cr(M, "Touch-down to lowest COM (s)")))))
write_tex(c("\\begin{tabular}{lrrrlrrrrr}", "\\toprule",
  " & Variance & Cumulative & Landing share & Largest & \\multicolumn{5}{c}{Pearson $r$ with} \\\\",
  "\\cmidrule(l){6-10}", "Component & (\\%) & (\\%) & of loading (\\%) & loading at & LPF & JH & CT & CMD & LD \\\\", "\\midrule",
  tex_rows(t3), "\\bottomrule", "\\end{tabular}"), "tab3_components")

# Table 4: matched-band dispersion with bootstrap CIs (main window)
ciw <- function(r, l, h) paste0(fmt(r), " (", fmt(l), "--", fmt(h), ")")
t4 <- data.frame(M$ci$component, fmt(M$band$sd_full_sample[1:4]), fmt(M$band$sd_jump_height_band[1:4]),
  ciw(M$ci$jh_ratio, M$ci$jh_ci_low, M$ci$jh_ci_high), fmt(M$band$sd_rel_peak_force_band[1:4]),
  ciw(M$ci$rpf_ratio, M$ci$rpf_ci_low, M$ci$rpf_ci_high))
t4 <- rbind(t4, c("Whole curve$^a$", fmt(M$band$sd_full_sample[5]), fmt(M$band$sd_jump_height_band[5]),
  fmt(M$band$ratio_jump_height[5]), fmt(M$band$sd_rel_peak_force_band[5]), fmt(M$band$ratio_rel_peak_force[5])))
write_tex(c("\\begin{tabular}{lrrlrl}", "\\toprule",
  " & SD, full & \\multicolumn{2}{c}{Jump-height band} & \\multicolumn{2}{c}{Relative peak-force band} \\\\",
  "\\cmidrule(lr){3-4}\\cmidrule(l){5-6}", "Component & sample & SD & Ratio (95\\% CI) & SD & Ratio (95\\% CI) \\\\", "\\midrule",
  tex_rows(t4), "\\bottomrule", "\\end{tabular}"), "tab4_bands")

# Table 5: variance explained under four evaluation schemes + variance decomposition (main window)
p1 <- function(x) fmt(100 * x, 1)
t5 <- data.frame(M$r2$component, p1(M$r2$r_squared), p1(M$r2$adj_r_squared), neg(p1(M$cv$cv_r_squared)),
  p1(M$rb$r2_one_trial_per_athlete), p1(M$rb$r2_athlete_means),
  fmt(M$vd$between_athlete_pct, 1), fmt(M$vd$between_session_pct, 1), fmt(M$vd$within_session_pct, 1))
write_tex(c("\\begin{tabular}{lrrrrrrrr}", "\\toprule",
  " & \\multicolumn{5}{c}{$R^2$ of component score on metrics, age and body mass (\\%)} & \\multicolumn{3}{c}{Variance of component score (\\%)} \\\\",
  "\\cmidrule(lr){2-6}\\cmidrule(l){7-9}",
  "Component & In-sample & Adjusted & Athlete CV & One trial & Athlete & Between & Between & Within \\\\",
  " & & & & per athlete & means & athletes & sessions & session \\\\", "\\midrule",
  tex_rows(t5), "\\bottomrule", "\\end{tabular}"), "tab5_r2")

# Table 6: main analysis versus 1-s landing window
tw <- function(R) c(paste0(nrow(R$dat), " / ", n_distinct(R$dat$athlete)),
  paste(fmt(R$var$variance_pct[1:4], 1), collapse = ", "), fmt(R$var$cumulative_pct[4], 1),
  paste(fmt(R$phase$landing_share_pct, 1), collapse = ", "),
  ciw(R$ci$jh_ratio[1], R$ci$jh_ci_low[1], R$ci$jh_ci_high[1]), fmt(R$band$ratio_jump_height[5]),
  paste(fmt(100 * R$r2$r_squared, 1), collapse = ", "), paste(neg(fmt(100 * R$cv$cv_r_squared, 1)), collapse = ", "),
  paste(fmt(R$vd$between_athlete_pct, 1), collapse = ", "),
  neg(fmt(cr(R, "Landing peak force (x BW)")[[1]])), neg(fmt(cr(R, "Contraction time (s)")[[3]])))
t6 <- data.frame(c("Trials / athletes after QC", "Variance explained, PC1--PC4 (\\%)", "Cumulative, PC1--PC4 (\\%)",
  "Landing share of loading, PC1--PC4 (\\%)", "PC1 SD ratio, jump-height band (95\\% CI)", "Whole-curve SD ratio, jump-height band",
  "In-sample $R^2$, PC1--PC4 (\\%)", "Athlete-CV $R^2$, PC1--PC4 (\\%)", "Between-athlete variance, PC1--PC4 (\\%)",
  "$r$(PC1, landing peak force)", "$r$(PC3, contraction time)"), tw(M), tw(S))
write_tex(c("\\begin{tabular}{lll}", "\\toprule", "Quantity & Main: landing to lowest COM & Sensitivity: 1-s landing \\\\", "\\midrule",
  tex_rows(t6), "\\bottomrule", "\\end{tabular}"), "tab6_windows")

# -----------------------------------------------------------------------------
# 15. IN-TEXT NUMBERS as LaTeX macros (paper/generated/numbers.tex)
# -----------------------------------------------------------------------------
mac <- character(0)
m <- function(name, value) mac <<- c(mac, sprintf("\\newcommand{\\%s}{%s}", name, value))
rng <- function(x, d = 1) paste0(neg(fmt(min(x), d)), "--", neg(fmt(max(x), d)))
m("nTrialsAll", nrow(trials_raw)); m("nAthAll", n_distinct(trials_raw$athlete)); m("nSessAll", n_distinct(trials_raw$test_code))
m("nTrials", nrow(M$dat)); m("nAth", n_distinct(M$dat$athlete)); m("nSess", n_distinct(M$dat$test_code))
m("nTrialsS", nrow(S$dat)); m("nLowcomMissing", S$qc$trials[5] - nrow(M$dat))
m("nFsLow", sum(trials_raw$native_fs == 500, na.rm = TRUE))
m("ageMedian", fmt(M$t1$median[1], 1)); m("ageMin", fmt(M$t1$min[1], 1)); m("ageMax", fmt(M$t1$max[1], 1))
m("ageQone", fmt(M$t1$q1[1], 1)); m("ageQthree", fmt(M$t1$q3[1], 1))
first <- M$dat[!duplicated(M$dat$athlete), ]
m("nMinors", sum(first$age < 18)); m("pctMinors", fmt(100 * mean(first$age < 18), 0))
m("trialsPerAthMean", fmt(M$t1$mean[M$t1$variable == "Trials per athlete"], 1))
m("trialsPerAthMax", M$t1$max[M$t1$variable == "Trials per athlete"])
m("sessPerAthMedian", fmt(M$t1$median[M$t1$variable == "Sessions per athlete"], 0))
m("sessPerAthMax", M$t1$max[M$t1$variable == "Sessions per athlete"])
m("trialsPerSessMedian", fmt(M$t1$median[M$t1$variable == "Trials per session"], 0))
m("jhMean", fmt(M$t1$mean[3], 1)); m("jhSD", fmt(M$t1$sd[3], 1))
m("lpfMean", fmt(M$t1$mean[8], 2)); m("lpfSD", fmt(M$t1$sd[8], 2)); m("lpfMin", fmt(M$t1$min[8], 2)); m("lpfMax", fmt(M$t1$max[8], 2))
m("lowcomTimeMedian", fmt(M$t1$median[11], 2))
for (k in 1:4) { L <- LETTERS[k]
  m(paste0("varPC", L), fmt(M$var$variance_pct[k], 1)); m(paste0("varSPC", L), fmt(S$var$variance_pct[k], 1))
  m(paste0("ldsPC", L), fmt(M$phase$landing_share_pct[k], 1)); m(paste0("ldsSPC", L), fmt(S$phase$landing_share_pct[k], 1))
  m(paste0("peakPC", L), M$phase$peak_pct[k])
  m(paste0("rLpfPC", L), neg(fmt(cr(M, "Landing peak force (x BW)")[[k]])))
  m(paste0("rJhPC", L), neg(fmt(cr(M, "Jump height (cm)")[[k]])))
  m(paste0("rCtPC", L), neg(fmt(cr(M, "Contraction time (s)")[[k]])))
  m(paste0("rCmdPC", L), neg(fmt(cr(M, "Countermovement depth (cm)")[[k]])))
  m(paste0("rLdPC", L), neg(fmt(cr(M, "Touch-down to lowest COM (s)")[[k]])))
  m(paste0("rtwoPC", L), fmt(100 * M$r2$r_squared[k], 1)); m(paste0("rtwoSPC", L), fmt(100 * S$r2$r_squared[k], 1))
  m(paste0("cvPC", L), neg(fmt(100 * M$cv$cv_r_squared[k], 1))); m(paste0("cvSPC", L), neg(fmt(100 * S$cv$cv_r_squared[k], 1)))
  m(paste0("jhRatioPC", L), fmt(M$ci$jh_ratio[k])); m(paste0("rpfRatioPC", L), fmt(M$ci$rpf_ratio[k]))
  m(paste0("jhLoPC", L), fmt(M$ci$jh_ci_low[k])); m(paste0("jhHiPC", L), fmt(M$ci$jh_ci_high[k]))
  m(paste0("betweenPC", L), fmt(M$vd$between_athlete_pct[k], 1)); m(paste0("withinPC", L), fmt(M$vd$within_session_pct[k], 1))
  m(paste0("sessPC", L), fmt(M$vd$between_session_pct[k], 1))
  m(paste0("betweenSPC", L), fmt(S$vd$between_athlete_pct[k], 1))
}
m("cumFour", fmt(M$var$cumulative_pct[4], 1)); m("cumFourS", fmt(S$var$cumulative_pct[4], 1))
m("cumTen", fmt(M$var$cumulative_pct[10], 1))
m("rtwoRange", rng(100 * M$r2$r_squared)); m("unexplRange", rng(M$r2$unexplained_pct))
m("cvRange", rng(100 * M$cv$cv_r_squared)); m("oneTrialRange", rng(100 * M$rb$r2_one_trial_per_athlete))
m("athMeanRange", rng(100 * M$rb$r2_athlete_means)); m("adjRange", rng(100 * M$r2$adj_r_squared))
m("rtwoLandingSRange", rng(100 * S$r2$r_squared[-3])); m("unexplSRange", rng(S$r2$unexplained_pct))
m("lpfCorRange", rng(unlist(cr(M, "Landing peak force (x BW)")), 2))
m("ctAbsMax", fmt(max(abs(unlist(cr(M, "Contraction time (s)")))), 2))
m("cmdAbsMax", fmt(max(abs(unlist(cr(M, "Countermovement depth (cm)")))), 2))
vend <- c("Jump height (cm)", "Concentric peak force (N)", "Concentric peak force (x BW)",
          "Eccentric braking impulse (N s)", "Concentric impulse 100 ms (N s)")
m("vendorAbsMax", fmt(max(abs(as.matrix(M$cors[M$cors$descriptor %in% vend, -1]))), 2))
m("rLpfSPCA", neg(fmt(cr(S, "Landing peak force (x BW)")[[1]])))
m("rLdSPCA", neg(fmt(cr(S, "Touch-down to lowest COM (s)")[[1]])))
m("ldsSPCCtakeoff", fmt(S$phase$takeoff_share_pct[3], 1))
m("rCtSPCC", neg(fmt(cr(S, "Contraction time (s)")[[3]])))
m("rRpfSPCC", neg(fmt(cr(S, "Concentric peak force (x BW)")[[3]])))
m("jhBandN", M$band_def$n_trials[1]); m("jhBandAth", M$band_def$n_athletes[1])
m("jhBandLo", fmt(M$band_def$lower[1], 1)); m("jhBandHi", fmt(M$band_def$upper[1], 1))
m("jhBandMean", fmt(M$band_def$band_mean[1], 1)); m("jhBandSD", fmt(M$band_def$band_sd[1], 2))
m("rpfBandN", M$band_def$n_trials[2]); m("rpfBandAth", M$band_def$n_athletes[2])
m("rpfBandLo", fmt(M$band_def$lower[2], 2)); m("rpfBandHi", fmt(M$band_def$upper[2], 2))
m("jhBandSDfactor", fmt(M$t1$sd[3] / M$band_def$band_sd[1], 0))
m("wholeJh", fmt(M$band$ratio_jump_height[5])); m("wholeRpf", fmt(M$band$ratio_rel_peak_force[5]))
m("wholeJhS", fmt(S$band$ratio_jump_height[5]))
m("rpfRatioRange", rng(M$ci$rpf_ratio, 2)); m("jhRatioRange", rng(M$ci$jh_ratio, 2))
m("jhRatioOtherRange", rng(M$ci$jh_ratio[2:4], 2))
m("jhRatioSPCA", fmt(S$ci$jh_ratio[1])); m("jhLoSPCA", fmt(S$ci$jh_ci_low[1])); m("jhHiSPCA", fmt(S$ci$jh_ci_high[1]))
m("bwPCARange", rng(M$bw$PC1_sd_ratio, 2)); m("bwAllRange", rng(as.matrix(M$bw[, paste0("PC", 1:4, "_sd_ratio")]), 2))
m("betweenRange", rng(M$vd$between_athlete_pct)); m("withinRange", rng(M$vd$within_session_pct))
m("sessRange", rng(M$vd$between_session_pct))
m("nBoot", format(N_BOOT, big.mark = ",")); m("seedValue", SEED)
m("nRepro", sum(ref$match)); m("nReproTotal", nrow(ref))
writeLines(c("% Generated by R/run_all.R -- do not edit by hand", mac), file.path(DIR_GEN, "numbers.tex"))

# -----------------------------------------------------------------------------
# 16. SOFTWARE RECORD
# -----------------------------------------------------------------------------
pk <- c("dplyr", "tidyr", "ggplot2", "patchwork", "nlme")
write.csv(data.frame(package = pk, version = sapply(pk, function(p) as.character(packageVersion(p)))),
          "packages.csv", row.names = FALSE)
writeLines(capture.output(sessionInfo()), "output/sessionInfo.txt")
cat(sprintf("\nDone in %.1f s. R %s\n", as.numeric(difftime(Sys.time(), t_start, units = "secs")), getRversion()))
