# Runs every lesson script (and solution) in a clean R process and prints a status table.
# From the repository root:  Rscript tests/run_all_lessons.R
files <- sort(c(list.files("lessons", pattern = "\\.R$", full.names = TRUE),
                list.files("lessons/solutions", pattern = "\\.R$", full.names = TRUE)))
res <- lapply(files, function(f) {
  t0 <- Sys.time()
  out <- suppressWarnings(system2("Rscript", c("--vanilla", shQuote(f)), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status"); if (is.null(status)) status <- 0L
  data.frame(script = f, status = ifelse(status == 0L, "OK", "FAIL"),
             seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
             last_line = if (status == 0L) "" else tail(out, 1), stringsAsFactors = FALSE)
})
tab <- do.call(rbind, res)
print(tab, row.names = FALSE)
dir.create("output", showWarnings = FALSE)
write.csv(tab, "output/run_all_lessons_status.csv", row.names = FALSE)
if (any(tab$status == "FAIL")) quit(status = 1)
