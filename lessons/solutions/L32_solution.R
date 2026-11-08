# Lesson 32 - worked solutions
# Run from the repository root. Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.

# Run the lesson first: it creates `dat`, `test`, `threshold`, the helper functions and the
# simulation function used below.
source("lessons/L32_bias_audit_and_double_dipping.R")

# ---- Exercise 1: fewer noise features and fewer selected ------------------------------------
set.seed(101)
sim_small <- as.data.frame(t(replicate(100, simulate_double_dip(n = 200, p = 50, k = 5))))
means_small <- round(colMeans(sim_small), 3)
print(means_small)
message("Gap with p = 500, k = 20: ", round(mean(sim$apparent) - mean(sim$honest), 3))
message("Gap with p = 50,  k = 5:  ", round(means_small[["apparent"]] - means_small[["honest"]], 3))
# With fewer candidate features and fewer selected, selection has less room to exploit chance,
# so the gap shrinks; it does not vanish, and the honest figure stays near 0.5.
stopifnot(means_small[["apparent"]] < mean(sim$apparent))
stopifnot(abs(means_small[["honest"]] - 0.5) < 0.05)

# ---- Exercise 2: the audit with a stricter threshold (top 10% flagged) ----------------------
train_scores <- dat$score[dat$part == "train"]
threshold_90 <- unname(quantile(train_scores, 0.9))
set.seed(102)
audit_90 <- audit_by_group(test, "group", "disease", "score", "risk", threshold_90)
audit_90_show <- audit_90[, c("group", "n", "events", "share_flagged", "sensitivity")]
audit_90_show[-1] <- round(audit_90_show[-1], 3)   # round the numeric columns only
print(audit_90_show)
# Reading: sensitivity is computed among people with the outcome, so the smallest group has
# very few of them and its estimate is unstable. State the numbers with their sample sizes;
# do not claim that the score works equally well, or worse, for that group.
stopifnot(sum(audit_90$n) == nrow(test))

# ---- Exercise 3: correct the measurement drift with a calibration sample ---------------------
set.seed(103)
g3_rows <- which(dat$group == "G3")
stopifnot(length(g3_rows) >= 100)
calib_rows <- sample(g3_rows, 100)                  # people measured with a reference method too
offset <- mean(dat$trait_measured[calib_rows] - dat$trait[calib_rows])
message("Estimated G3 offset: ", round(offset, 2), " (planted: 3)")
dat$trait_corrected <- ifelse(dat$group == "G3", dat$trait_measured - offset, dat$trait_measured)
cut_corrected <- unname(quantile(dat$trait_corrected, 0.9))
fixed_tab <- dat %>%
  group_by(group) %>%
  summarise(flagged_true = mean(trait > cut_true),
            flagged_measured = mean(trait_measured > cut_measured),
            flagged_corrected = mean(trait_corrected > cut_corrected),
            .groups = "drop")
print(fixed_tab)
g3 <- fixed_tab[fixed_tab$group == "G3", ]
stopifnot(abs(g3$flagged_corrected - g3$flagged_true) < abs(g3$flagged_measured - g3$flagged_true))
