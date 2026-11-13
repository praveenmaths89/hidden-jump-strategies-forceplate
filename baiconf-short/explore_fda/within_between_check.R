#!/usr/bin/env Rscript
# Follow-up to pffr vs OLS discrepancy: split jump height (and body mass, age) into
# athlete-mean (between) and within-athlete deviation; OLS on the 101-point grid,
# athlete-block bootstrap sup-t bands (2000). Seed 2026.
suppressPackageStartupMessages(library(dplyr)); set.seed(2026); G <- 9.81; NB <- 2000
tr <- { source("data_path.R"); read.csv(cmj_data_path()) } %>%
  filter(!(is.na(body_mass_kg) | body_mass_kg <= 0), abs(quiet_mass_kg - body_mass_kg) / body_mass_kg <= 0.05, abs(flight_force_n) <= 50,
         !is.na(age), !is.na(jump_height_cm), !is.na(conc_peak_force_n), !is.na(ecc_braking_impulse_ns), !is.na(conc_impulse_100ms_ns), !is.na(ldc_050))
bw <- tr$body_mass_kg * G
Y <- list(takeoff = as.matrix(tr[, grep("^to_[0-9]", names(tr))]) / bw, landing = as.matrix(tr[, grep("^ldc_[0-9]", names(tr))]) / bw)
sdj <- sd(tr$jump_height_cm)
tr <- tr %>% group_by(athlete) %>% mutate(jh_b = mean(jump_height_cm), jh_w = jump_height_cm - jh_b, age_b = mean(age), age_w = age - age_b,
  bm_b = mean(body_mass_kg), bm_w = body_mass_kg - bm_b) %>% ungroup()
X <- cbind(1, jh_between = (tr$jh_b - mean(tr$jh_b)) / sdj, jh_within = tr$jh_w / sdj, age = scale(tr$age_b), age_w = tr$age_w / sd(tr$age),
           bm = scale(tr$bm_b), bm_w = tr$bm_w / sd(tr$body_mass_kg))
idx <- split(seq_len(nrow(tr)), tr$athlete); bs <- replicate(NB, unlist(idx[sample(length(idx), replace = TRUE)], use.names = FALSE), simplify = FALSE)
runs <- function(lg) { if (!any(lg)) return("none"); r <- rle(lg); e <- cumsum(r$lengths); s <- e - r$lengths + 1; paste(sprintf("%d-%d%%", (0:100)[s[r$values]], (0:100)[e[r$values]]), collapse = ", ") }
out <- list()
for (b in names(Y)) { est <- qr.solve(X, Y[[b]]); bt <- array(NA, c(NB, ncol(X), 101)); for (i in 1:NB) bt[i, , ] <- qr.solve(X[bs[[i]], ], Y[[b]][bs[[i]], ])
  for (j in 2:3) { se <- apply(bt[, j, ], 2, sd); cs <- quantile(apply(abs(sweep(bt[, j, ], 2, est[j, ])) / rep(se, each = NB), 1, max), .95)
    k <- which.max(abs(est[j, ]))
    out[[paste(b, j)]] <- data.frame(block = b, term = colnames(X)[j], sig_sim = runs(est[j, ] - cs*se > 0 | est[j, ] + cs*se < 0),
      max_effect_per_SD_JH = round(est[j, k], 3), ci = sprintf("[%.3f, %.3f]", quantile(bt[, j, k], .025), quantile(bt[, j, k], .975)), at_pct = k - 1) } }
o <- bind_rows(out); print(o); write.csv(o, "tables/F3_within_between_jump_height.csv", row.names = FALSE)
cat(sprintf("SD of within-athlete JH deviation = %.2f cm; SD of athlete-mean JH = %.2f cm\n", sd(tr$jh_w), sd(tr$jh_b)))
