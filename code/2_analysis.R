# =============================================================================
# 2_analysis.R
# Purpose : Every estimate reported in the article and supplement. Results are
#           written to results/results.json under stable keys, and
#           results/paper_numbers.csv links each number in the article to its
#           key. Tables behind every exhibit go to results/tables/.
# Input   : data/analysis/ (written by 1_build_dataset.R) and data/curated/
# =============================================================================
log_line("2 analysis: start")
master <- read_csv(file.path(DER, "master_country_dataset.csv"), show_col_types = FALSE, guess_max = 1000)
REF <- read_csv(file.path(DER, "reference_values.csv"), show_col_types = FALSE)
REF <- as.list(setNames(REF$value, REF$name))
area_long <- read_csv(file.path(DER, "kff_area_of_cooperation_long.csv"), show_col_types = FALSE)
annual <- read_csv(file.path(DER, "kff_annual_us_funding_long.csv"), show_col_types = FALSE)
idx <- read_csv(file.path(DER, "index_universes.csv"), show_col_types = FALSE)
ledger <- read_csv(file.path(INP, "agreement_ledger.csv"), show_col_types = FALSE)
alts <- read_csv(file.path(INP, "numerator_alternatives.csv"), show_col_types = FALSE)
sched <- read_csv(file.path(INP, "signed_annual_schedules.csv"), show_col_types = FALSE)
pf_des <- read_csv(file.path(INP, "pandemic_fund_country_designations.csv"), show_col_types = FALSE)

R <- list()
mou <- master %>% filter(mou_signed)
s34 <- master %>% filter(split_published)
grp <- s34 %>% filter(screen_group)
check(nrow(mou) == 36 && nrow(s34) == 34, "analysis populations: 36 agreements, 34 with both components")
names_of <- function(d) d %>% arrange(country) %>% pull(country)
R$populations <- list(n_agreements = 36, n_both_components = 34, n_ghs_index = REF$n_ghs,
                      n_ahs_index = REF$n_ahs, n_ahs_signatories = sum(!is.na(s34$ahs_overall_2026)),
                      n_signed_texts = sum(s34$evidence_status == "Signed text"),
                      n_announcements = sum(s34$evidence_status != "Signed text"))

# ---- A. Agreement portfolio --------------------------------------------------
led <- ledger
R$portfolio <- list(
  first_signed = as.character(min(mou$agreement_date, na.rm = TRUE)),
  last_signed = as.character(max(mou$agreement_date, na.rm = TRUE)),
  n_known_totals = sum(!is.na(led$kff_total_usd)),
  total_known_usd_bn = sum(led$kff_total_usd, na.rm = TRUE) / 1e9,
  n_known_us = sum(!is.na(led$kff_us_usd)),
  us_known_usd_bn = sum(led$kff_us_usd, na.rm = TRUE) / 1e9,
  us_34_usd_bn = sum(s34$us_funding_usd) / 1e9,
  partner_34_usd_bn = sum(s34$coinvest_usd) / 1e9,
  partner_share_34_pct = 100 * sum(s34$coinvest_usd) / sum(s34$us_funding_usd + s34$coinvest_usd),
  partner_share_min_pct = min(s34$coinvest_share_pct), partner_share_max_pct = max(s34$coinvest_share_pct),
  n_term3 = sum(s34$term_years == 3), term3 = names_of(filter(s34, term_years == 3)),
  n_hist = sum(!is.na(mou$us_planned_fy21_25_usd) & !is.na(mou$us_mou_fy26_30_usd)),
  hist_prior_usd_bn = sum(mou$us_planned_fy21_25_usd[!is.na(mou$us_mou_fy26_30_usd)], na.rm = TRUE) / 1e9,
  hist_new_usd_bn = sum(mou$us_mou_fy26_30_usd[!is.na(mou$us_planned_fy21_25_usd)], na.rm = TRUE) / 1e9,
  n_africa_34 = sum(s34$kff_region == "Africa"))
R$portfolio$hist_change_pct <- 100 * (R$portfolio$hist_new_usd_bn / R$portfolio$hist_prior_usd_bn - 1)

# ---- B. Pledge share (primary measure) --------------------------------------
q <- quantile(s34$pledge_share_pct, c(.25, .5, .75))
R$pledge <- list(
  median = unname(q[2]), q1 = unname(q[1]), q3 = unname(q[3]),
  min = min(s34$pledge_share_pct), min_country = s34$country[which.min(s34$pledge_share_pct)],
  max = max(s34$pledge_share_pct), max_country = s34$country[which.max(s34$pledge_share_pct)],
  max_non_africa = max(s34$pledge_share_pct[s34$kff_region != "Africa"]),
  max_non_africa_country = s34$country[s34$kff_region != "Africa"][which.max(s34$pledge_share_pct[s34$kff_region != "Africa"])],
  n_ge5 = sum(s34$pledge_share_pct >= 5), n_ge10 = sum(s34$pledge_share_pct >= 10),
  n_ge20 = sum(s34$pledge_share_pct >= 20),
  top6 = s34 %>% arrange(desc(pledge_share_pct)) %>% slice(1:6) %>% transmute(country, pledge_share_pct),
  botswana_5yr = s34$pledge_share_5yr_pct[s34$iso3 == "BWA"], botswana = s34$pledge_share_pct[s34$iso3 == "BWA"],
  south_sudan_5yr = s34$pledge_share_5yr_pct[s34$iso3 == "SSD"], south_sudan = s34$pledge_share_pct[s34$iso3 == "SSD"])

# Signed annual schedules: Uganda illustration (2023 spending held fixed)
g23 <- setNames(s34$gghed_usd_2023, s34$iso3)
uga <- sched %>% filter(iso3 == "UGA")
R$uganda <- list(
  y2026_usd_m = uga$amount[uga$year == 2026] / 1e6, y2030_usd_m = uga$amount[uga$year == 2030] / 1e6,
  total_usd_m = sum(uga$amount) / 1e6,
  y2030_pct_2023 = 100 * uga$amount[uga$year == 2030] / g23[["UGA"]],
  mean_pct_2023 = 100 * mean(uga$amount) / g23[["UGA"]],
  gghed_2023_usd_m = g23[["UGA"]] / 1e6)
check(abs(R$uganda$total_usd_m - s34$coinvest_usd[s34$iso3 == "UGA"] / 1e6) < 0.001,
      "Uganda signed schedule sums to the KFF amount")
mwi_s51 <- sched %>% filter(iso3 == "MWI", str_detect(schedule, "5.1"))
mwi_app <- sched %>% filter(iso3 == "MWI", str_detect(schedule, "Appendix"))
check(abs(sum(mwi_s51$amount) - 313.6e6) < 1 && abs(sum(mwi_app$amount) - 55e6) < 1,
      "Malawi signed schedules sum to US$313.6m and US$55m")

# ---- C. Preparedness ----------------------------------------------------------
R$preparedness <- list(
  spar_global_mean = SPAR_GLOBAL_MEAN,
  n_below_63 = sum(s34$spar_2025 < SPAR_GLOBAL_MEAN), n_below_50 = sum(s34$spar_2025 < 50),
  spar_min = min(s34$spar_2025), spar_max = max(s34$spar_2025),
  ghs_median_195 = REF$GHS_MEDIAN_2021, ahs_median_54 = REF$AHS_MEDIAN_2026,
  n_ghs_below = sum(s34$ghs_below_median), n_ahs_below = sum(s34$ahs_below_median, na.rm = TRUE),
  n_ahs = sum(!is.na(s34$ahs_overall_2026)))

spearman_ci <- function(x, y, R_ = BOOT_R) {
  ok <- complete.cases(x, y); x <- x[ok]; y <- y[ok]
  est <- suppressWarnings(cor(x, y, method = "spearman"))
  set.seed(BOOT_SEED)
  b <- boot(data.frame(x, y), function(d, i) cor(d$x[i], d$y[i], method = "spearman"), R = R_)
  ci <- boot.ci(b, type = "perc")$percent[4:5]
  tibble(n = length(x), rho = est, lo = ci[1], hi = ci[2])
}
cor_spec <- list(
  pledge_spar = list(s34$pledge_share_pct, s34$spar_2025, "Pledge share vs SPAR 2025", "34 signatories"),
  pledge_ghs = list(s34$pledge_share_pct, s34$ghs_overall_2021, "Pledge share vs GHS Index 2021", "34 signatories"),
  pledge_ahs = list(s34$pledge_share_pct, s34$ahs_overall_2026, "Pledge share vs AHS Index 2026", "African signatories"),
  pledge_ext = list(s34$pledge_share_pct, s34$ext_che_2023, "Pledge share vs external share of current health spending", "34 signatories"),
  pledge_gge = list(s34$pledge_share_pct, s34$gghed_gge_2023, "Pledge share vs health share of government spending", "34 signatories"),
  spar_ghs_all = list(master$spar_2025, master$ghs_overall_2021, "SPAR 2025 vs GHS 2021", "All countries with both"),
  spar_ahs_all = list(master$spar_2025, master$ahs_overall_2026, "SPAR 2025 vs AHS 2026", "African countries with both"),
  ghs_ahs_all = list(master$ghs_overall_2021, master$ahs_overall_2026, "GHS 2021 vs AHS 2026", "African countries with both"),
  lab_lab = list(master$spar_c4_laboratory, master$ahs_lab_2026, "SPAR laboratory (C4) vs AHS laboratory", "African countries with both"),
  surv_surv = list(master$spar_c5_surveillance, master$ahs_surveillance_2026, "SPAR surveillance (C5) vs AHS surveillance", "African countries with both"))
cors <- imap_dfr(cor_spec, ~ spearman_ci(.x[[1]], .x[[2]]) %>%
                   mutate(key = .y, pair = .x[[3]], population = .x[[4]])) %>% relocate(key, pair, population)
write_out(cors, "eTable_correlations")
R$cor <- split(cors, cors$key) %>% map(~ as.list(.x))

# ---- D. Screening group (pledge share >=10% and SPAR below 63) --------------
R$group <- list(
  n = nrow(grp), countries = names_of(grp), iso3 = sort(grp$iso3),
  us_usd_bn = sum(grp$us_funding_usd) / 1e9, partner_usd_bn = sum(grp$coinvest_usd) / 1e9,
  pop_m = sum(grp$pop_2023_thousands) / 1e3,
  ext_che_median = median(grp$ext_che_2023), gghed_gge_median = median(grp$gghed_gge_2023),
  n_rated = sum(!is.na(grp$dsf_overall_risk)),
  n_high_or_distress = sum(grp$dsf_high_or_distress %in% TRUE),
  high_or_distress = names_of(filter(grp, dsf_high_or_distress %in% TRUE)),
  in_distress = names_of(filter(grp, dsf_overall_risk == "In debt distress")),
  not_rated = names_of(filter(grp, is.na(dsf_overall_risk))),
  n_no_single = sum(grp$pf_single_n == 0),
  no_single = names_of(filter(grp, pf_single_n == 0)),
  no_single_named_regional = names_of(filter(grp, pf_single_n == 0, pf_named_multi_regional_n > 0)),
  cfp4_eligible = names_of(filter(grp, pf_cfp4_eligible)),
  n_signed_text = sum(grp$evidence_status == "Signed text"),
  announcement_only = names_of(filter(grp, evidence_status != "Signed text")),
  n_workforce_below = sum(grp$hwf_below_sdg_threshold %in% TRUE))
R$quadrants <- s34 %>% count(quadrant) %>% { setNames(as.list(.$n), .$quadrant) }
check(R$group$n == 10 && identical(R$group$iso3, sort(c("BWA","CMR","COD","LBR","LSO","MWI","NGA","SLE","SSD","UGA"))),
      "primary screening group is the 10 countries verified in the audit")

# Table 1 cells, generated from the same country IDs as Figure 1
tab1 <- s34 %>% group_by(quadrant) %>% arrange(desc(pledge_share_pct), .by_group = TRUE) %>%
  summarise(n = n(), countries = paste(country, collapse = "; "),
            pledge_min = min(pledge_share_pct), pledge_max = max(pledge_share_pct),
            spar_min = min(spar_2025), spar_max = max(spar_2025),
            n_rated = sum(!is.na(dsf_overall_risk)), n_high_or_distress = sum(dsf_high_or_distress %in% TRUE),
            n_no_single = sum(pf_single_n == 0),
            n_cross10_dep20 = sum(!high_pledge & pledge_dep20_pct >= PLEDGE_THRESHOLD),
            us_usd_bn = sum(us_funding_usd) / 1e9, .groups = "drop")
write_out(tab1, "Table1_country_types")
R$table1 <- split(tab1, tab1$quadrant) %>% map(~ as.list(.x))

# ---- E. Sensitivity analyses --------------------------------------------------
# E1. Threshold x preparedness measure (country IDs retained)
prep_defs <- list(
  "SPAR 2025 below WHO global mean (63)" = s34$spar_below_global,
  "GHS 2021 below index median (34.9, 195 countries)" = s34$ghs_below_median,
  "AHS 2026 below index median (54 countries)" = s34$ahs_below_median)
grid <- expand_grid(threshold = PLEDGE_GRID, measure = names(prep_defs)) %>%
  mutate(eligible = map_int(measure, ~ sum(!is.na(prep_defs[[.x]]))),
         ids = map2(threshold, measure, ~ sort(s34$iso3[s34$pledge_share_pct >= .x & prep_defs[[.y]] %in% TRUE])),
         n = lengths(ids),
         n_in_primary = map_int(ids, ~ sum(.x %in% grp$iso3)),
         countries = map_chr(ids, ~ paste(s34$country[match(.x, s34$iso3)], collapse = "; ")),
         iso3 = map_chr(ids, ~ paste(.x, collapse = " "))) %>% select(-ids)
write_out(grid, "eTable_threshold_grid")
R$grid <- grid
R$robust <- list(
  n_two_of_three = sum(s34$high_pledge & ((s34$spar_below_global + s34$ghs_below_median + coalesce(s34$ahs_below_median, FALSE)) >= 2)),
  two_of_three = names_of(filter(s34, high_pledge, (spar_below_global + ghs_below_median + coalesce(ahs_below_median, FALSE)) >= 2)),
  spar_and_ghs = names_of(filter(s34, high_pledge, spar_below_global, ghs_below_median)),
  spar_only = names_of(filter(s34, high_pledge, spar_below_global, !ghs_below_median)),
  ghs_only = names_of(filter(s34, high_pledge, !spar_below_global, ghs_below_median)))

# E2. Numerator and population scenarios (all with the 10% / SPAR 63 screen)
run_scenario <- function(d, label, note) {
  d <- d %>% mutate(share = 100 * (coinvest_usd / term_years) / gghed_usd_2023,
                    share_dep20 = if_else(usd_pledge_assumed, share / 0.8, share),
                    in_grp = share >= PLEDGE_THRESHOLD & spar_below_global,
                    in_dep20 = share_dep20 >= PLEDGE_THRESHOLD & spar_below_global)
  ids <- sort(d$iso3[d$in_grp])
  tibble(scenario = label, note = note, n_countries = nrow(d),
         median = median(d$share), q3 = unname(quantile(d$share, .75)),
         n_ge10 = sum(d$share >= 10), n_group = length(ids),
         group_iso3 = paste(ids, collapse = " "),
         gained = paste(setdiff(ids, grp$iso3), collapse = " "),
         lost = paste(setdiff(grp$iso3, ids), collapse = " "),
         n_group_dep20 = sum(d$in_dep20),
         malawi_share = if ("MWI" %in% d$iso3) d$share[d$iso3 == "MWI"] else NA_real_,
         rho_spar = cor(d$share, d$spar_2025, method = "spearman"))
}
mwi_alt <- function(measure) {
  a <- alts %>% filter(iso3 == "MWI", measure_id == measure)
  s34 %>% mutate(coinvest_usd = if_else(iso3 == "MWI", a$partner_usd, coinvest_usd))
}
phl <- alts %>% filter(iso3 == "PHL")
phl_row <- master %>% filter(iso3 == "PHL") %>%
  mutate(coinvest_usd = phl$partner_usd, us_funding_usd = phl$us_usd, term_years = phl$term_years,
         usd_pledge_assumed = TRUE)
scen <- bind_rows(
  run_scenario(s34, "Primary: KFF amounts, documented 3- or 5-year terms", "Main analysis"),
  run_scenario(s34 %>% mutate(term_years = 5), "Version 4 rule: every amount divided by five", "Replicates the earlier draft"),
  run_scenario(mwi_alt("signed_programme_schedule"), "Malawi: signed programme schedule (US$55m)", "Appendix 1"),
  run_scenario(mwi_alt("signed_budget_increases"), "Malawi: signed budget increases (US$313.6m)", "Section 5.1"),
  run_scenario(s34 %>% filter(iso3 != "MWI"), "Malawi excluded", "33 countries"),
  run_scenario(bind_rows(s34, phl_row), "Philippines added (embassy split)", "35 countries"),
  run_scenario(s34 %>% filter(evidence_status == "Signed text"), "Signed texts only", "Amounts verified against a signed text"))
write_out(scen, "eTable_numerator_scenarios")
R$scenarios <- split(scen, seq_len(nrow(scen))) %>% setNames(c("primary", "v4_five_year", "mwi_programme",
                                                               "mwi_budget", "mwi_excluded", "phl_added", "signed_only"))
R$scenarios <- map(R$scenarios, ~ as.list(.x))
check(R$scenarios$v4_five_year$n_group == 9, "version 4 rule reproduces the earlier nine-country group")
R$malawi <- list(
  kff = s34$pledge_share_pct[s34$iso3 == "MWI"],
  programme = R$scenarios$mwi_programme$malawi_share, budget = R$scenarios$mwi_budget$malawi_share,
  y2030_budget_pct_2023 = 100 * 143.8e6 / g23[["MWI"]])

# E3. Currency scenarios
R$currency <- list(
  n_dep3y_ge20 = sum(s34$max_3y_depreciation_pct >= 20, na.rm = TRUE),
  n_dep1y_ge20 = sum(s34$max_1y_depreciation_pct >= 20, na.rm = TRUE),
  n_fx_obs = sum(!is.na(s34$max_3y_depreciation_pct)),
  group_dep3y_ge20 = sum(grp$max_3y_depreciation_pct >= 20, na.rm = TRUE),
  dep20_new = names_of(filter(s34, screen_group_dep20, !screen_group)),
  n_dep20 = sum(s34$screen_group_dep20),
  n_dep30 = sum(s34$pledge_dep30_pct >= PLEDGE_THRESHOLD & s34$spar_below_global),
  dep20_documented_new = names_of(filter(s34, pledge_dep20_documented_pct >= PLEDGE_THRESHOLD, spar_below_global, !screen_group)),
  n_usd_documented = sum(s34$usd_pledge_documented),
  n_usd_assumed = sum(s34$usd_pledge_assumed))
write_out(s34 %>% transmute(iso3, country, partner_currency_documented, max_1y_depreciation_pct,
                            max_3y_depreciation_pct, depreciation_2015_23_pct, pledge_share_pct,
                            pledge_dep20_pct, pledge_dep30_pct, pledge_dep20_documented_pct) %>%
            arrange(desc(max_3y_depreciation_pct)), "eTable_currency")

# ---- F. Spending trends 2015-23 (history, before the agreements) -------------
R$trends <- list(
  n_complete = sum(!is.na(s34$gghed_usd_cagr_2015_23)),
  incomplete = names_of(filter(s34, is.na(gghed_usd_cagr_2015_23))),
  usd_cagr_median = median(s34$gghed_usd_cagr_2015_23, na.rm = TRUE),
  real_cagr_median = median(s34$gghed_real_lcu_cagr_2015_23, na.rm = TRUE),
  usd_decline = names_of(filter(s34, gghed_usd_cagr_2015_23 < 0)),
  real_decline = names_of(filter(s34, gghed_real_lcu_cagr_2015_23 < 0)),
  usd_decline_real_growth = names_of(filter(s34, gghed_usd_cagr_2015_23 < 0, gghed_real_lcu_cagr_2015_23 >= 0)))
write_out(s34 %>% transmute(iso3, country, trend_first_year, gghed_usd_m_2023,
                            gghed_usd_cagr_2015_23, gghed_real_lcu_cagr_2015_23,
                            gghed_usd_cagr_first_avail, gghed_real_lcu_cagr_first_avail) %>%
            arrange(gghed_usd_cagr_2015_23), "eTable_spending_trends")

# ---- G. Debt ------------------------------------------------------------------
R$debt <- list(
  n_rated = sum(!is.na(s34$dsf_overall_risk)),
  n_high = sum(s34$dsf_overall_risk == "High", na.rm = TRUE),
  n_distress = sum(s34$dsf_overall_risk == "In debt distress", na.rm = TRUE),
  distress = names_of(filter(s34, dsf_overall_risk == "In debt distress")),
  n_high_or_distress = sum(s34$dsf_high_or_distress %in% TRUE),
  pub_first = format(min(as.Date(paste0("01/", s34$dsf_publication[!is.na(s34$dsf_overall_risk)]), "%d/%m/%y")), "%B %Y"),
  pub_last = format(max(as.Date(paste0("01/", s34$dsf_publication[!is.na(s34$dsf_overall_risk)]), "%d/%m/%y")), "%B %Y"),
  interest_revenue_median = median(s34$wb_interest_revenue, na.rm = TRUE),
  n_interest = sum(!is.na(s34$wb_interest_revenue)))

# ---- H. US funding for four outbreak-related functions ------------------------
hs <- area_long %>% filter(health_security_area, year %in% c(2026, 2030)) %>%
  group_by(iso3, year) %>% summarise(usd = sum(us_funding_usd, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = usd, names_prefix = "hs_") %>%
  left_join(s34 %>% select(iso3, country, gghed_usd_2023, screen_group, term_years), by = "iso3") %>%
  mutate(hs_drop_usd = hs_2026 - hs_2030, hs_drop_pct = 100 * (1 - hs_2030 / hs_2026),
         hs_drop_pct_gghed = 100 * hs_drop_usd / gghed_usd_2023)
write_out(hs, "eTable_us_outbreak_functions_by_country")
area_tot <- area_long %>% filter(year %in% c(2026, 2030)) %>% group_by(area, year) %>%
  summarise(usd = sum(us_funding_usd, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = usd, names_prefix = "y") %>%
  mutate(change_pct = 100 * (y2030 / y2026 - 1), outbreak_function = area %in% HEALTH_SECURITY_AREAS) %>%
  arrange(change_pct)
write_out(area_tot, "eTable_us_funding_by_area")
hs5 <- hs %>% filter(iso3 != "BWA")
# Botswana's agreement ends in 2028, so its 2030 value reflects expiry, not a cut.
area_tot5 <- area_long %>% filter(year %in% c(2026, 2030), iso3 != "BWA") %>% group_by(area, year) %>%
  summarise(usd = sum(us_funding_usd, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = year, values_from = usd, names_prefix = "y") %>%
  mutate(change_pct = 100 * (y2030 / y2026 - 1), outbreak_function = area %in% HEALTH_SECURITY_AREAS) %>%
  arrange(change_pct)
write_out(area_tot5, "eTable_us_funding_by_area_16_five_year")
ann <- annual %>% filter(year %in% c(2026, 2030)) %>%
  pivot_wider(names_from = year, values_from = us_funding_usd, names_prefix = "y")
ann_both <- ann %>% filter(!is.na(y2026), !is.na(y2030))
R$us_functions <- list(
  n_countries = nrow(hs),
  total_2026_usd_m = sum(hs$hs_2026) / 1e6, total_2030_usd_m = sum(hs$hs_2030) / 1e6,
  change_pct = 100 * (sum(hs$hs_2030) / sum(hs$hs_2026) - 1),
  excl_bwa_2026_usd_m = sum(hs5$hs_2026) / 1e6, excl_bwa_2030_usd_m = sum(hs5$hs_2030) / 1e6,
  excl_bwa_change_pct = 100 * (sum(hs5$hs_2030) / sum(hs5$hs_2026) - 1),
  by_area_16 = area_tot5 %>% select(area, change_pct) %>% { setNames(as.list(.$change_pct), .$area) },
  by_area = area_tot %>% select(area, change_pct) %>% { setNames(as.list(.$change_pct), .$area) },
  drop_pct_gghed_max = max(hs$hs_drop_pct_gghed), drop_pct_gghed_max_country = hs$country[which.max(hs$hs_drop_pct_gghed)],
  top4 = hs %>% arrange(desc(hs_drop_pct_gghed)) %>% slice(1:4) %>% transmute(country, hs_drop_pct_gghed),
  group_in_area_file = names_of(filter(hs, screen_group)),
  annual_n_columns = n_distinct(annual$iso3), annual_n_2026 = sum(!is.na(ann$y2026)),
  annual_n_both = nrow(ann_both), annual_both_2026_usd_bn = sum(ann_both$y2026) / 1e9,
  annual_both_2030_usd_bn = sum(ann_both$y2030) / 1e9)
R$us_functions$annual_both_change_pct <- 100 * (R$us_functions$annual_both_2030_usd_bn / R$us_functions$annual_both_2026_usd_bn - 1)
check(R$us_functions$n_countries == 17, "outbreak-function budgets for 17 countries")

# ---- I. Pandemic Fund ---------------------------------------------------------
efp <- pf_des %>% filter(designation == "EFP_Ebola_2026_reprogramming") %>% mutate(iso3 = to_iso3(country)) %>%
  left_join(master %>% select(iso3, agreement_date, mou_signed), by = "iso3")
R$pandemic_fund <- list(
  n_single = sum(s34$pf_single_n > 0), single_total_usd_m = sum(s34$pf_single_grant_usd) / 1e6,
  n_named_only = sum(s34$pf_single_n == 0 & s34$pf_named_multi_regional_n > 0),
  n_not_named = sum(s34$pf_single_n == 0 & s34$pf_named_multi_regional_n == 0),
  n_cfp4 = sum(s34$pf_cfp4_eligible),
  efp_n = nrow(efp), efp_all_signed_by_oct = all(efp$mou_signed %in% TRUE),
  efp_signed_by_29may = sum(efp$agreement_date <= as.Date("2026-05-29"), na.rm = TRUE),
  efp_signed_after = names_of(efp %>% mutate(country = master$country[match(iso3, master$iso3)]) %>%
                                filter(agreement_date > as.Date("2026-05-29"))))
write_out(s34 %>% transmute(iso3, country, screen_group, pf_status, pf_single_n, pf_single_rounds,
                            pf_single_grant_usd, pf_named_multi_regional_n, pf_projects, pf_cfp4_eligible,
                            pf_efp_2026) %>% arrange(desc(screen_group), country), "eTable_pandemic_fund")

# ---- J. Workforce -------------------------------------------------------------
R$workforce <- list(n_obs = sum(!is.na(s34$hwf_dnm_per10k)), n_below = sum(s34$hwf_below_sdg_threshold %in% TRUE),
                    n_years_differ = sum(s34$hwf_years_differ %in% TRUE),
                    median = median(s34$hwf_dnm_per10k, na.rm = TRUE))

# ---- K. Preparedness by agreement status (all index countries) ---------------
q3 <- function(x) tibble(n = length(x), p25 = unname(quantile(x, .25)), median = median(x), p75 = unname(quantile(x, .75)))
lmic_iso <- master$iso3[master$income_ghed %in% c("Low", "Lower-middle", "Upper-middle")]
africa_iso <- idx$iso3[idx$index == "AHS 2026"]
status_cmp <- bind_rows(
  idx %>% group_by(index, agreement) %>% reframe(q3(score)) %>% mutate(population = "All index countries"),
  idx %>% filter(index == "GHS 2021", iso3 %in% africa_iso) %>% group_by(index, agreement) %>% reframe(q3(score)) %>%
    mutate(population = "African countries in both indices"),
  idx %>% filter(index == "GHS 2021", iso3 %in% lmic_iso) %>% group_by(index, agreement) %>% reframe(q3(score)) %>%
    mutate(population = "Low and middle income (WHO expenditure file)"),
  idx %>% filter(index == "GHS 2021", iso3 != "USA") %>% group_by(index, agreement) %>% reframe(q3(score)) %>%
    mutate(population = "All index countries except the United States")) %>%
  mutate(agreement = if_else(agreement, "Agreement", "No agreement")) %>% relocate(population, index)
write_out(status_cmp, "eTable_preparedness_by_agreement_status")
R$status_cmp <- status_cmp

# Context ratios: signatories vs other low and middle income countries (medians, n)
cmp <- master %>% filter(iso3 %in% lmic_iso) %>%
  mutate(group = if_else(mou_signed, "Agreement", "Other low and middle income")) %>%
  group_by(group) %>%
  summarise(n = n(), n_ext = sum(!is.na(ext_che_2023)), ext_che_median = median(ext_che_2023, na.rm = TRUE),
            n_gge = sum(!is.na(gghed_gge_2023)), gghed_gge_median = median(gghed_gge_2023, na.rm = TRUE),
            n_spar = sum(!is.na(spar_2025)), spar_median = median(spar_2025, na.rm = TRUE), .groups = "drop")
write_out(cmp, "eTable_signatories_vs_other_lmic")
R$lmic_compare <- cmp

# ---- L. Country profile table (supplement) ------------------------------------
profile <- s34 %>% arrange(desc(pledge_share_pct)) %>%
  transmute(iso3, Country = country, Region = kff_region, `Signature date` = agreement_date,
            `Term (years)` = term_years, `Evidence` = evidence_status,
            `US funding (US$m)` = us_funding_usd / 1e6, `Partner commitment (US$m)` = coinvest_usd / 1e6,
            `2023 domestic government health spending (US$m)` = gghed_usd_m_2023,
            `Pledge share (%)` = pledge_share_pct, `SPAR 2025` = spar_2025, `GHS 2021` = ghs_overall_2021,
            `AHS 2026` = ahs_overall_2026, `Debt distress rating` = as.character(dsf_overall_risk),
            `Rating date` = dsf_publication, `External share of health spending (%)` = ext_che_2023,
            `Pandemic Fund` = pf_status, `Type` = quadrant)
write_out(profile, "eTable_country_profiles")

# ---- M. Replication of version 4 ----------------------------------------------
v4 <- tribble(~metric, ~v4_value, ~v5_rule_v4, ~v5_primary,
  "Median pledge share (%)", 6.76, median(s34$pledge_share_5yr_pct), R$pledge$median,
  "Upper quartile (%)", 16.42, unname(quantile(s34$pledge_share_5yr_pct, .75)), R$pledge$q3,
  "Countries in screening group", 9, R$scenarios$v4_five_year$n_group, R$group$n,
  "Botswana pledge share (%)", 8.33, R$pledge$botswana_5yr, R$pledge$botswana,
  "South Sudan pledge share (%)", 11.09, R$pledge$south_sudan_5yr, R$pledge$south_sudan,
  "Countries added by 20% depreciation", 4, R$scenarios$v4_five_year$n_group_dep20 - 9, length(R$currency$dep20_new))
write_out(v4, "eTable_replication_v4")
R$replication <- v4

write_json(R, file.path(OUT, "results.json"), auto_unbox = TRUE, digits = 8, pretty = TRUE, na = "null")
obj <- list(R = R, s34 = s34, grp = grp, hs = hs, cors = cors, grid = grid, scen = scen, area_tot = area_tot, area_tot5 = area_tot5,
             status_cmp = status_cmp, REF = REF)
log_line("2 analysis: done")
