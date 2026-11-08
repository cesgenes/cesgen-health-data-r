# Lesson 31 - worked solutions
# Run from the repository root. Simulated data for teaching purposes.
# Educational material; it does not replace a health professional.

# Run the lesson first: it creates `release`, `geno`, `snp_cols` and the helper functions.
source("lessons/L31_reidentification_simulation.R")

# ---- Exercise 1: a generalisation with k >= 5 --------------------------------------------
candidates <- expand.grid(band_width = c(10, 20, 30), district_block = c(5, 10))
res <- lapply(seq_len(nrow(candidates)), function(i) {
  bw <- candidates$band_width[i]
  db <- candidates$district_block[i]
  tmp <- release
  tmp$band <- floor(tmp$birth_year / bw) * bw                                  # age band
  tmp$block <- ceiling(as.integer(sub("D", "", tmp$district)) / db)            # area block
  r <- k_anonymity(tmp, c("sex", "band", "block"))
  data.frame(band_width = bw, district_block = db, k = r$k,
             n_groups = r$n_groups, n_unique = r$n_unique)
})
res <- do.call(rbind, res)
res <- res[order(-res$k, -res$n_groups), ]
print(res)

ok <- res[res$k >= 5, ]
stopifnot(nrow(ok) >= 1)
# Among the options with k >= 5, keep the one that preserves most detail (most groups)
best <- ok[which.max(ok$n_groups), ]
print(best)
stopifnot(best$k >= 5)

# ---- Exercise 2: how many SNPs until 95% of people are unique? -----------------------------
shares <- sapply(seq_along(snp_cols), function(m) {
  k_anonymity(geno, snp_cols[seq_len(m)])$n_unique / nrow(geno)
})
m_95 <- min(which(shares >= 0.95))
message("Smallest number of SNPs giving at least 95% unique profiles: ", m_95)
stopifnot(is.finite(m_95), m_95 >= 5)

# ---- Exercise 3: a model answer for the data-sharing request ------------------------------
# Release sex, birth decade and area block (k >= 5), plus the condition flag, and keep the
# register and the exact birth year and district inside the secure environment: the released
# table then does not single out anyone, and the loss of detail is stated in the methods.
# Do not release individual-level genotypes outside a controlled-access agreement.
