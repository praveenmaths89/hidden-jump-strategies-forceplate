#!/usr/bin/env Rscript
# =============================================================================
# TIME-NORMALISATION / REGISTRATION SENSITIVITY (literature-recommended checks)
#  (i)  node count 51 / 101 / 201 and linear vs cubic-spline resampling
#  (ii) additional landmarks: take-off registered piecewise-linearly at
#       onset | min COM velocity | zero velocity (eccentric->concentric) | take-off;
#       landing registered at touch-down | peak landing force | lowest COM
# Key re-estimated quantities: FoSR (model A) jump-height regions, SPM (a)
# jump-height tertiles, PCA variance explained. Athlete-level resampling throughout.
# NOTE: only the stored 101-point curves are available (raw signals are private),
# so 201-point curves are re-interpolations of the 101-point curves: this tests
# the ANALYSIS's sensitivity to node count/interpolation, not information lost
# at the original resampling step (that is covered by the sampling audit).
# =============================================================================
t0 <- Sys.time()
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(ggplot2); library(patchwork) })
SEED <- 2026; set.seed(SEED); G <- 9.81; N_BOOT <- 2000; N_PERM <- 5000
source("data_path.R"); DATA <- cmj_data_path()
lc <- file("timenorm_log.txt", "w"); say <- function(...) { s <- sprintf(...); cat(s, "\n"); cat(s, "\n", file = lc) }
theme_set(theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(), strip.background = element_rect(fill = "grey92"),
  plot.title = element_text(face = "bold", size = 9), legend.position = "bottom"))
tr <- read.csv(DATA) %>% filter(!(is.na(body_mass_kg) | body_mass_kg <= 0), abs(quiet_mass_kg - body_mass_kg) / body_mass_kg <= 0.05,
  abs(flight_force_n) <= 50, !is.na(age), !is.na(jump_height_cm), !is.na(conc_peak_force_n), !is.na(ecc_braking_impulse_ns),
  !is.na(conc_impulse_100ms_ns), !is.na(ldc_050))
bw <- tr$body_mass_kg * G
Y0 <- list(takeoff = as.matrix(tr[, grep("^to_[0-9]", names(tr))]) / bw, landing = as.matrix(tr[, grep("^ldc_[0-9]", names(tr))]) / bw)
n <- nrow(tr); say("%d trials", n)
ath_idx <- split(seq_len(n), tr$athlete)
bsets <- replicate(N_BOOT, unlist(ath_idx[sample(length(ath_idx), replace = TRUE)], use.names = FALSE), simplify = FALSE)
z <- function(v) (v - mean(v)) / sd(v)
X <- cbind(1, z(tr$jump_height_cm), z(tr$age), z(tr$body_mass_kg))
runs <- function(lg, x) { if (!any(lg)) return("none"); r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1
  paste(sprintf("%.0f-%.0f%%", x[s[r$values]], x[e[r$values]]), collapse = ", ") }
fosr_jh <- function(M, x) {   # OLS + athlete bootstrap sup-t band for jump height
  est <- qr.solve(X, M)[2, ]; bt <- t(sapply(bsets, function(s) qr.solve(X[s, ], M[s, ])[2, ]))
  se <- apply(bt, 2, sd); cs <- quantile(apply(abs(sweep(bt, 2, est)) / rep(se, each = N_BOOT), 1, max), .95)
  list(est = est, lo = est - cs*se, hi = est + cs*se, cs = cs, sig = runs(est - cs*se > 0 | est + cs*se < 0, x)) }
tstat2 <- function(M, g) { a <- M[g, , drop = FALSE]; b <- M[!g, , drop = FALSE]
  (colMeans(a) - colMeans(b)) / sqrt(apply(a, 2, var)/nrow(a) + apply(b, 2, var)/nrow(b)) }
clmass <- function(t, thr) { lg <- abs(t) > thr; if (!any(lg)) return(data.frame(start = integer(), end = integer(), mass = numeric()))
  sg <- sign(t) * lg; r <- rle(sg); e <- cumsum(r$lengths); s <- e - r$lengths + 1; k <- r$values != 0
  data.frame(start = s[k], end = e[k], mass = mapply(function(a, b) sum(abs(t[a:b])), s[k], e[k])) }
am <- tr %>% group_by(athlete) %>% summarise(jh = mean(jump_height_cm), .groups = "drop"); tert <- quantile(am$jh, c(1/3, 2/3))
spm_a <- function(M, x) {   # athlete-mean curves, top vs bottom tertile, cluster mass; mass scaled by grid step so it is comparable across node counts
  s <- rowsum(M, tr$athlete); A <- (s / as.vector(table(tr$athlete)[rownames(s)]))[am$athlete, ]
  sel <- am$jh <= tert[1] | am$jh >= tert[2]; A <- A[sel, ]; g <- am$jh[sel] >= tert[2]; thr <- qt(.975, nrow(A) - 2)
  dx <- diff(x)[1]; set.seed(SEED); t <- tstat2(A, g); obs <- clmass(t, thr); obs$mass <- obs$mass * dx
  mx <- replicate(N_PERM, { cm <- clmass(tstat2(A, sample(g)), thr); if (nrow(cm)) max(cm$mass) * dx else 0 })
  obs$p <- as.numeric(sapply(obs$mass, function(m) (1 + sum(mx >= m)) / (1 + N_PERM)))
  ok <- obs$p < 0.05; if (!any(ok)) return("none")
  paste(sprintf("%.0f-%.0f%% (p=%.4f)", x[obs$start[ok]], x[obs$end[ok]], obs$p[ok]), collapse = "; ") }
pcvar <- function(M) { e <- prcomp(M)$sdev^2; round(100 * cumsum(e / sum(e))[1:4], 1) }
resample <- function(M, Q, method) { x0 <- 0:100; x1 <- seq(0, 100, length.out = Q)
  t(apply(M, 1, function(y) if (method == "linear") approx(x0, y, xout = x1)$y else spline(x0, y, xout = x1, method = "fmm")$y)) }

# ---- (i) node count x interpolation
rows <- list(); curves <- list()
for (b in names(Y0)) for (Q in c(51, 101, 201)) for (meth in c("linear", "spline")) {
  if (Q == 101 && meth == "spline") next
  M <- if (Q == 101) Y0[[b]] else resample(Y0[[b]], Q, meth); x <- seq(0, 100, length.out = Q)
  f <- fosr_jh(M, x); s <- spm_a(M, x); v <- pcvar(M)
  rows[[paste(b, Q, meth)]] <- data.frame(block = b, nodes = Q, interp = ifelse(Q == 101, "stored", meth), fosr_jh_sim_sig = f$sig,
    sim_crit = round(f$cs, 3), spm_a_sig = s, pc1_4_cum_var = paste(v, collapse = "/"))
  curves[[paste(b, Q, meth)]] <- data.frame(block = b, version = sprintf("%d nodes, %s", Q, ifelse(Q == 101, "stored", meth)), pct = x, est = f$est)
  say("  %-8s %3d %-7s FoSR JH sim-sig: %-22s crit %.2f | SPM(a): %s | PC cum var %s", b, Q, meth, f$sig, f$cs, s, paste(v, collapse = "/"))
}
nc <- bind_rows(rows); write.csv(nc, "tables/T1_node_count_interp_sensitivity.csv", row.names = FALSE)
p1 <- ggplot(bind_rows(curves), aes(pct, est, linetype = version)) + geom_hline(yintercept = 0, linewidth = 0.2) + geom_line(linewidth = 0.5) +
  facet_wrap(~block, scales = "free_y", labeller = labeller(block = c(takeoff = "Take-off", landing = "Landing"))) +
  scale_linetype_manual(values = c("solid", "22", "12", "4212", "dotdash")) + guides(linetype = guide_legend(nrow = 2)) +
  labs(x = "% of phase", y = "Jump-height effect (x BW per SD)", linetype = NULL, title = "FoSR jump-height coefficient under different node counts and interpolation")

# ---- (ii) additional landmarks
# take-off: reconstruct COM velocity from force (impulse-momentum), dt = contraction_time / 100
dt <- tr$contraction_time_s / 100
A <- (Y0$takeoff - 1) * G
V <- t(sapply(seq_len(n), function(i) c(0, cumsum((A[i, -1] + A[i, -101]) / 2 * dt[i]))))
v_to <- V[, 101]; v_jh <- sqrt(2 * G * tr$jump_height_cm / 100)
say("  velocity check: take-off velocity from curve vs from jump height: r = %.3f, median ratio %.3f (IQR %.3f-%.3f)",
    cor(v_to, v_jh), median(v_to / v_jh), quantile(v_to / v_jh, .25), quantile(v_to / v_jh, .75))
lm_minv <- apply(V, 1, which.min) - 1                     # end of unweighting (min velocity)
lm_v0 <- sapply(seq_len(n), function(i) { k <- which(V[i, ] >= 0 & seq_len(101) > lm_minv[i] + 1); if (length(k)) k[1] - 1 else NA })
ok_to <- !is.na(lm_v0) & lm_minv > 2 & lm_v0 < 98 & lm_v0 > lm_minv
say("  take-off landmarks found in %d/%d trials: min-velocity at %.1f%% (SD %.1f), zero-velocity at %.1f%% (SD %.1f)",
    sum(ok_to), n, mean(lm_minv[ok_to]), sd(lm_minv[ok_to]), mean(lm_v0[ok_to]), sd(lm_v0[ok_to]))
lm_pk <- apply(Y0$landing, 1, which.max) - 1
say("  landing peak force at %.1f%% of landing (SD %.1f; IQR %.0f-%.0f)", mean(lm_pk), sd(lm_pk), quantile(lm_pk, .25), quantile(lm_pk, .75))
register <- function(M, lms) {   # piecewise-linear landmark registration to mean landmark positions (spline evaluation)
  tgt <- colMeans(lms); x0 <- 0:100
  t(sapply(seq_len(nrow(M)), function(i) { h <- approx(tgt, lms[i, ], xout = x0)$y; spline(x0, M[i, ], xout = h, method = "fmm")$y }))
}
LT <- cbind(0, lm_minv, lm_v0, 100); Reg_to <- Y0$takeoff; Reg_to[ok_to, ] <- register(Y0$takeoff[ok_to, ], LT[ok_to, ])
LL <- cbind(0, lm_pk, 100); okl <- lm_pk > 0 & lm_pk < 100; Reg_ld <- Y0$landing; Reg_ld[okl, ] <- register(Y0$landing[okl, ], LL[okl, ])
say("  take-off target landmarks: %s ; landing target: %s", paste(round(colMeans(LT[ok_to, ]), 1), collapse = " | "), paste(round(colMeans(LL[okl, ]), 1), collapse = " | "))
lrows <- list(); lcurves <- list(); tim_rows <- list(data.frame(landmark = "velocity check (r, median ratio)", est = cor(v_to, v_jh), lo = median(v_to / v_jh), hi = NA))
for (b in names(Y0)) { M <- if (b == "takeoff") Reg_to else Reg_ld; x <- 0:100
  f <- fosr_jh(M, x); s <- spm_a(M, x); v <- pcvar(M)
  lrows[[b]] <- data.frame(block = b, registration = ifelse(b == "takeoff", "onset|min velocity|zero velocity|take-off", "touch-down|peak force|lowest COM"),
    fosr_jh_sim_sig = f$sig, spm_a_sig = s, pc1_4_cum_var = paste(v, collapse = "/"))
  lcurves[[b]] <- data.frame(block = b, version = "extra landmarks", pct = x, est = f$est)
  say("  %-8s extra landmarks: FoSR JH sim-sig %s | SPM(a) %s | PC cum var %s", b, f$sig, s, paste(v, collapse = "/"))
  # landmark timing (phase) vs jump height: athlete-bootstrap slope
  if (b == "takeoff") { for (L in list(list("min velocity", lm_minv), list("zero velocity", lm_v0))) { y <- L[[2]]; i <- ok_to
      est <- coef(lm(y[i] ~ X[i, 2]))[2]; bs <- sapply(bsets[1:1000], function(s) { s <- s[ok_to[s]]; coef(lm(y[s] ~ X[s, 2]))[2] })
      tim_rows[[L[[1]]]] <- data.frame(landmark = L[[1]], est = est, lo = quantile(bs, .025), hi = quantile(bs, .975))
      say("     timing of %s vs jump height: %+.2f %% of take-off per SD (95%% CI %+.2f to %+.2f)", L[[1]], est, quantile(bs, .025), quantile(bs, .975)) } }
  else { y <- lm_pk; est <- coef(lm(y ~ X[, 2]))[2]; bs <- sapply(bsets[1:1000], function(s) coef(lm(y[s] ~ X[s, 2]))[2])
      tim_rows[["peak"]] <- data.frame(landmark = "peak landing force", est = est, lo = quantile(bs, .025), hi = quantile(bs, .975))
      say("     timing of peak landing force vs jump height: %+.2f %% of landing per SD (95%% CI %+.2f to %+.2f)", est, quantile(bs, .025), quantile(bs, .975)) }
}
write.csv(bind_rows(lrows), "tables/T2_landmark_registration_sensitivity.csv", row.names = FALSE)
write.csv(rbind(bind_rows(tim_rows), data.frame(landmark = c("mean min-velocity %", "mean zero-velocity %", "mean peak-landing %", "SD peak-landing %"),
  est = c(mean(lm_minv[ok_to]), mean(lm_v0[ok_to]), mean(lm_pk), sd(lm_pk)), lo = NA, hi = NA)), "tables/T3_landmark_timing.csv", row.names = FALSE)
cmp <- bind_rows(bind_rows(curves) %>% filter(version == "101 nodes, stored"), bind_rows(lcurves)) %>%
  mutate(version = recode(version, `101 nodes, stored` = "Two landmarks per phase (as analysed)", `extra landmarks` = "Extra landmarks (see caption)"))
p2 <- ggplot(cmp, aes(pct, est, linetype = version)) + geom_hline(yintercept = 0, linewidth = 0.2) + geom_line(linewidth = 0.6) +
  facet_wrap(~block, scales = "free_y", labeller = labeller(block = c(takeoff = "Take-off", landing = "Landing"))) +
  labs(x = "% of (registered) phase", y = "Jump-height effect (x BW per SD)", linetype = NULL,
       caption = "Extra landmarks: take-off = onset | min COM velocity | zero velocity | take-off; landing = touch-down | peak force | lowest COM.")
ggsave("figs/figT1_timenorm_sensitivity.png", p1 / p2, width = 170/25.4, height = 150/25.4, dpi = 300, bg = "white")
say("Runtime %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins"))); close(lc)
