# =============================================================================
# 4_check_paper_numbers.R
# Purpose : Confirms that every number in the article that this analysis
#           produces is reproduced. data/paper_numbers.csv lists each number as
#           printed, where it appears, and the R expression that retrieves it
#           from results/results.json. Numbers taken from other publications
#           are listed with their source and are not recomputed.
# Output  : results/paper_numbers_check.csv; stops if any number differs.
# =============================================================================
log_line("4 check paper numbers: start")
R <- jsonlite::fromJSON(file.path(OUT, "results.json"), simplifyVector = TRUE)
pn <- read_csv(file.path(ROOT, "data", "paper_numbers.csv"), show_col_types = FALSE,
               col_types = cols(.default = "c"))
pn$computed <- NA_real_
for (i in seq_len(nrow(pn))) {
  e <- pn$computed_from_results_json[i]
  if (!is.na(e) && nzchar(e)) pn$computed[i] <- as.numeric(eval(parse(text = e)))
}
pn <- pn %>%
  mutate(reported_value = as.numeric(reported_value), decimals = as.integer(decimals),
         computed_rounded = round(computed, decimals),
         status = case_when(is.na(computed) ~ "external source",
                            abs(computed_rounded - reported_value) < 1e-9 ~ "reproduced",
                            TRUE ~ "DIFFERS"))
write_csv(pn, file.path(OUT, "paper_numbers_check.csv"), na = "")
n_ok <- sum(pn$status == "reproduced"); n_ext <- sum(pn$status == "external source")
bad <- pn %>% filter(status == "DIFFERS")
if (nrow(bad)) {
  print(as.data.frame(bad[, c("id", "where_in_the_article", "reported_value", "computed_rounded")]))
  stop(nrow(bad), " number(s) in the article differ from the results.", call. = FALSE)
}
log_line("4 check paper numbers:", n_ok, "of", n_ok, "computed numbers reproduced;",
         n_ext, "numbers come from other publications")
