# Simulated genotype data. Everything here is invented for teaching purposes.

#' Anchor variants: real rsIDs with their (GRCh37) coordinates, simulated genotypes
#' Coordinates (GRCh37) checked against dbSNP (NCBI Variation API) on 2026-11-08.
anchor_variants <- function() {
  data.frame(
    rsid = c("rs1801133", "rs4988235", "rs12913832", "rs429358", "rs7412", "rs1805007"),
    chromosome = c("1", "2", "15", "19", "19", "16"),
    position = c(11856378L, 136608646L, 28365618L, 45411941L, 45412079L, 89986117L),
    ref = c("G", "G", "A", "T", "C", "C"),
    alt = c("A", "A", "G", "C", "T", "T"),
    alt_freq = c(0.30, 0.45, 0.35, 0.15, 0.08, 0.08),
    stringsAsFactors = FALSE
  )
}

#' Write a simulated raw file in the style of consumer genotyping platforms
#' @return invisibly, the data frame that was written
simulate_consumer_file <- function(path, n_snps = 1500, seed = 2026,
                                   build = "GRCh37", nocall_rate = 0.01) {
  set.seed(seed)
  anchors <- anchor_variants()
  n_bg <- n_snps - nrow(anchors)
  chr_bg <- sample(as.character(c(1:22, "X", "MT")), n_bg, replace = TRUE,
                   prob = c(rep(1, 22), 0.5, 0.2))
  bg <- data.frame(
    rsid = sprintf("sim%06d", seq_len(n_bg)),
    chromosome = chr_bg,
    position = sample(1e6:2e8, n_bg),
    stringsAsFactors = FALSE
  )
  bases <- c("A", "C", "G", "T")
  bg$ref <- sample(bases, n_bg, replace = TRUE)
  bg$alt <- vapply(bg$ref, function(r) sample(setdiff(bases, r), 1), character(1))
  bg$alt_freq <- runif(n_bg, 0.05, 0.5)
  all <- rbind(anchors, bg)
  chr_order <- factor(all$chromosome, levels = c(1:22, "X", "MT"))
  all <- all[order(chr_order, all$position), ]
  mk_gt <- function(ref, alt, f, chr) {
    n_alleles <- if (chr == "MT") 1 else 2
    a <- ifelse(runif(n_alleles) < f, alt, ref)
    paste(sort(a), collapse = "")
  }
  all$genotype <- mapply(mk_gt, all$ref, all$alt, all$alt_freq, all$chromosome, USE.NAMES = FALSE)
  nc <- runif(nrow(all)) < nocall_rate
  all$genotype[nc] <- "--"
  out <- all[, c("rsid", "chromosome", "position", "genotype")]
  header <- c(
    "# SIMULATED raw data file. Not a real person. Datos simulados con fin didactico.",
    sprintf("# Format modelled on consumer genotyping files. Reference build: %s (build 37).", build),
    "# Genotypes are reported on the forward (+) strand. '--' means no call.",
    "# rsid\tchromosome\tposition\tgenotype"
  )
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(c(header, paste(out$rsid, out$chromosome, out$position, out$genotype, sep = "\t")), path)
  invisible(out)
}

#' Simulate a small population with known genetic effects ("known truth")
#' Three ancestry groups (labelled G1, G2, G3) differ in allele frequencies at some SNPs.
#' @return list(geno, pheno, truth)
simulate_population <- function(n = 3000, n_snps = 40, seed = 2026) {
  set.seed(seed)
  group <- sample(c("G1", "G2", "G3"), n, replace = TRUE, prob = c(0.7, 0.2, 0.1))
  base_f <- runif(n_snps, 0.1, 0.5)
  shift <- matrix(rnorm(n_snps * 3, 0, 0.06), nrow = n_snps, dimnames = list(NULL, c("G1", "G2", "G3")))
  shift[, "G1"] <- 0
  freq_by_group <- pmin(pmax(base_f + shift, 0.02), 0.98)
  geno <- matrix(0L, n, n_snps, dimnames = list(sprintf("P%05d", seq_len(n)), sprintf("snp%02d", seq_len(n_snps))))
  for (j in seq_len(n_snps)) {
    f <- freq_by_group[j, group]
    geno[, j] <- rbinom(n, 2, f)
  }
  causal <- sort(sample(n_snps, 8))
  beta <- numeric(n_snps); beta[causal] <- rnorm(8, 0, 0.35)
  lin <- as.vector(geno %*% beta)
  trait <- 50 + 4 * lin + rnorm(n, 0, 4)                         # a continuous trait
  disease <- rbinom(n, 1, plogis(-2.2 + lin - mean(lin)))       # a binary outcome
  pheno <- data.frame(patient_id = rownames(geno), group = group, trait = trait, disease = disease,
                      stringsAsFactors = FALSE)
  truth <- data.frame(snp = colnames(geno), beta = beta, causal = beta != 0)
  list(geno = geno, pheno = pheno, truth = truth, freq_by_group = freq_by_group)
}
