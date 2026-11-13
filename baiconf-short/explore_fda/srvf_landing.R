#!/usr/bin/env Rscript
# Section 8 of run_explore.R as a standalone script (identical method; seed 2026):
# elastic SRVF alignment of landing curves; SPM (a),(b) on aligned amplitude and
# phase; FoSR jump-height on aligned curves; k=2 ARI vs unaligned profiles.
suppressPackageStartupMessages({ library(dplyr); library(tidyr); library(ggplot2); library(patchwork); library(mclust); library(fdasrvf) })
SEED <- 2026; set.seed(SEED); G <- 9.81; N_BOOT <- 2000; N_PERM <- 5000; pct <- 0:100
lc <- file("srvf_log.txt", "w"); say <- function(...) { s <- sprintf(...); cat(s, "\n"); cat(s, "\n", file = lc) }
theme_set(theme_bw(base_size = 9) + theme(panel.grid.minor = element_blank(), strip.background = element_rect(fill = "grey92"), legend.position = "bottom", plot.title = element_text(face = "bold", size = 9)))
tr <- { source("data_path.R"); read.csv(cmj_data_path()) } %>%
  filter(!(is.na(body_mass_kg) | body_mass_kg <= 0), abs(quiet_mass_kg - body_mass_kg) / body_mass_kg <= 0.05, abs(flight_force_n) <= 50,
         !is.na(age), !is.na(jump_height_cm), !is.na(conc_peak_force_n), !is.na(ecc_braking_impulse_ns), !is.na(conc_impulse_100ms_ns), !is.na(ldc_050))
n <- nrow(tr); YL <- as.matrix(tr[, grep("^ldc_[0-9]", names(tr))]) / (tr$body_mass_kg * G)
runs <- function(lg) { if (!any(lg)) return("none"); r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1; paste(sprintf("%d-%d%%", pct[s[r$values]], pct[e[r$values]]), collapse = ", ") }
tstat2 <- function(M, g) { a <- M[g, , drop = FALSE]; b <- M[!g, , drop = FALSE]; (colMeans(a) - colMeans(b)) / sqrt(apply(a, 2, var)/nrow(a) + apply(b, 2, var)/nrow(b)) }
clmass <- function(t, thr) { t[!is.finite(t)] <- 0; lg <- abs(t) > thr; if (!any(lg)) return(data.frame(start = integer(), end = integer(), mass = numeric()))
  sg <- sign(t) * lg; r <- rle(sg); e <- cumsum(r$lengths); s <- e - r$lengths + 1; k <- r$values != 0
  data.frame(start = s[k], end = e[k], mass = mapply(function(a, b) sum(abs(t[a:b])), s[k], e[k])) }
spm <- function(M, g) { set.seed(SEED); thr <- qt(.975, nrow(M) - 2); t <- tstat2(M, g); o <- clmass(t, thr)
  mx <- replicate(N_PERM, { cm <- clmass(tstat2(M, sample(g)), thr); if (nrow(cm)) max(cm$mass) else 0 })
  o$p <- as.numeric(sapply(o$mass, function(m) (1 + sum(mx >= m)) / (1 + N_PERM))); o <- o[o$p < 0.05, , drop = FALSE]
  if (!nrow(o)) "none" else paste(sprintf("%d-%d%% (%s, p=%.4f)", pct[o$start], pct[o$end], ifelse(t[o$start] > 0, "g1>g2", "g1<g2"), o$p), collapse = "; ") }
am <- tr %>% group_by(athlete) %>% summarise(jh = mean(jump_height_cm), age = mean(age), .groups = "drop"); tert <- quantile(am$jh, c(1/3, 2/3))
amean <- function(M) { s <- rowsum(M, tr$athlete); (s / as.vector(table(tr$athlete)[rownames(s)]))[am$athlete, ] }
t0 <- Sys.time()
if (file.exists("srvf_landing_fit.rds")) {   # cache from a previous identical run (delete to refit)
  ff <- readRDS("srvf_landing_fit.rds"); Yal <- ff$Yal; Gm <- ff$Gm
  wp <- list(fmean = ff$fmean, original_variance = ff$ov, amplitude_variance = ff$av, phase_variance = ff$pv)
} else {
  wp <- time_warping(t(YL), seq(0, 1, length.out = 101), lambda = 0, max_iter = 10, parallel = FALSE)
  Yal <- t(wp$fn); Gm <- t(wp$warping_functions)
}
Ph <- 100 * (Gm - matrix(seq(0, 1, length.out = 101), n, 101, byrow = TRUE))
saveRDS(list(Yal = Yal, Gm = Gm, fmean = wp$fmean, ov = wp$original_variance, av = wp$amplitude_variance, pv = wp$phase_variance), "srvf_landing_fit.rds")
say("SRVF: %.1f min; variance total %.3f, amplitude %.3f, phase %.3f", as.numeric(difftime(Sys.time(), t0, units = "mins")), wp$original_variance, wp$amplitude_variance, wp$phase_variance)
pk_raw <- apply(YL, 1, which.max) - 1; pk_al <- apply(Yal, 1, which.max) - 1
say("peak landing force position: SD %.1f%% unaligned -> %.1f%% aligned", sd(pk_raw), sd(pk_al))
write.csv(data.frame(var_total = wp$original_variance, var_amplitude = wp$amplitude_variance, var_phase = wp$phase_variance,
  peak_sd_unaligned = sd(pk_raw), peak_sd_aligned = sd(pk_al)), "tables/R2_srvf_summary.csv", row.names = FALSE)
rows <- list()
for (what in c("aligned amplitude", "phase (gamma - t, % units)")) { M <- amean(if (grepl("aligned", what)) Yal else Ph)
  sa <- am$jh <= tert[1] | am$jh >= tert[2]
  ra <- spm(M[sa, ], am$jh[sa] >= tert[2]); rb <- spm(M, am$age >= 18)
  rows[[what]] <- data.frame(curves = what, a_top_vs_bottom_JH = ra, b_18plus_vs_u18 = rb); say("%-26s (a) %s | (b) %s", what, ra, rb) }
z <- function(v) (v - mean(v)) / sd(v); X <- cbind(1, z(tr$jump_height_cm), z(tr$age), z(tr$body_mass_kg))
idx <- split(seq_len(n), tr$athlete); bs <- replicate(N_BOOT, unlist(idx[sample(length(idx), replace = TRUE)], use.names = FALSE), simplify = FALSE)
fj <- function(M) { e <- qr.solve(X, M)[2, ]; bt <- t(sapply(bs, function(s) qr.solve(X[s, ], M[s, ])[2, ])); se <- apply(bt, 2, sd)
  ok <- se > 1e-10; cs <- quantile(apply((abs(sweep(bt, 2, e)) / rep(se, each = N_BOOT))[, ok, drop = FALSE], 1, max), .95); list(e = e, sig = runs(ok & (e - cs*se > 0 | e + cs*se < 0)), mx = max(abs(e)), at = which.max(abs(e)) - 1) }
fa <- fj(Yal); fp <- fj(Ph)
say("FoSR JH on aligned amplitude: sig %s (max %.3f BW/SD at %d%%); on phase: sig %s (max %.2f %%-units/SD at %d%%)", fa$sig, fa$mx, fa$at, fp$sig, fp$mx, fp$at)
Sal <- prcomp(Yal); q <- which(cumsum(Sal$sdev^2) / sum(Sal$sdev^2) >= 0.90)[1]
set.seed(SEED); kal <- kmeans(Sal$x[, 1:q], 2, nstart = 50)$cluster
Sun <- prcomp(YL); qu <- which(cumsum(Sun$sdev^2) / sum(Sun$sdev^2) >= 0.90)[1]; set.seed(SEED + 2); kun <- kmeans(Sun$x[, 1:qu], 2, nstart = 50)$cluster
ari <- adjustedRandIndex(kal, kun); say("k=2 aligned vs unaligned landing clustering: ARI %.3f", ari)
o <- bind_rows(rows); o$fosr_jh <- c(fa$sig, fp$sig); o$ari_k2_vs_unaligned <- c(round(ari, 3), NA); write.csv(o, "tables/R1_srvf_sensitivity.csv", row.names = FALSE)
p1 <- ggplot(data.frame(pct = rep(pct, 2), f = c(colMeans(YL), wp$fmean), v = rep(c("Cross-sectional mean (landmark-registered)", "SRVF Karcher mean (elastic)"), each = 101)), aes(pct, f, linetype = v)) +
  geom_line(linewidth = 0.7) + labs(x = "% of landing", y = "Force (x BW)", linetype = NULL, title = "Landing mean before/after elastic alignment") + guides(linetype = guide_legend(ncol = 1))
p2 <- ggplot(data.frame(id = rep(1:150, each = 101), pct = rep(pct, 150), g = as.vector(t(100 * Gm[1:150, ]))), aes(pct, g, group = id)) + geom_line(colour = "grey55", linewidth = 0.2) +
  geom_abline(linetype = "dashed") + labs(x = "Registered time (%)", y = "Original time (%)", title = "Warping functions (150 trials)")
sa <- am$jh <= tert[1] | am$jh >= tert[2]; A <- amean(Yal)
d3 <- bind_rows(data.frame(c = "(a) JH tertiles", pct = pct, hi = colMeans(A[sa, ][am$jh[sa] >= tert[2], ]), lo = colMeans(A[sa, ][am$jh[sa] < tert[2], ])),
                data.frame(c = "(b) age groups", pct = pct, hi = colMeans(A[am$age >= 18, ]), lo = colMeans(A[am$age < 18, ]))) %>% pivot_longer(c(hi, lo))
p3 <- ggplot(d3, aes(pct, value, linetype = name)) + geom_line(linewidth = 0.6) + facet_wrap(~c) +
  scale_linetype_manual(values = c(hi = "dashed", lo = "solid"), labels = c(hi = "Top tertile / 18+", lo = "Bottom tertile / under 18")) +
  labs(x = "% of landing (aligned)", y = "Force (x BW)", linetype = NULL, title = "Athlete-mean aligned landing curves")
ggsave("figs/fig8_srvf_landing_alignment.png", (p1 | p2) / p3, width = 170/25.4, height = 150/25.4, dpi = 300, bg = "white"); close(lc)
