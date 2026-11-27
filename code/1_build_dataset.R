# =============================================================================
# 1_build_dataset.R
# Purpose : Read every raw source and curated input, harmonise to ISO3 codes,
#           and write the analysis-ready country file and supporting tables.
# Inputs  : data/raw/ (third-party downloads; see README.md) and data/curated/
# Outputs : data/analysis/master_country_dataset.csv (one row per country)
#           data/analysis/*.csv long tables (see data/codebook.csv)
# =============================================================================
log_line("1 build dataset: start")

# ---- 1. Agreement ledger (author-verified; one row per agreement) ----------
ledger <- read_csv(file.path(INP, "agreement_ledger.csv"), show_col_types = FALSE)
check(nrow(ledger) == 36 && !anyDuplicated(ledger$iso3), "ledger has 36 unique agreements")
check(all(ledger$term_years %in% c(3, 5)), "agreement terms are 3 or 5 years")

# ---- 2. KFF tracker (data as of 8 Oct 2026) ---------------------------------
kff_file <- function(name) raw_file("kff", name)
kff_dates <- read_excel(kff_file("Kff_All MOU by Country.xlsx"), sheet = 1,
                        col_types = c("text", "text", rep("text", 4))) %>%
  rename(country = `Country Name`, date_txt = `Agreement Date`) %>%
  filter(!is.na(country), country != "Total") %>%
  mutate(agreement_date = case_when(
    str_detect(date_txt, "^\\d{5}$") ~ as.Date(suppressWarnings(as.numeric(date_txt)), origin = "1899-12-30"),
    str_detect(date_txt, "^12/22/25") ~ as.Date("2025-12-22"),
    TRUE ~ as.Date(NA)),
    agreement_date_flag = if_else(str_detect(date_txt, " or "),
                                  "KFF records two possible dates (22 or 23 Dec 2025)", NA_character_)) %>%
  transmute(iso3 = to_iso3(country), agreement_date, agreement_date_flag)
cofin <- read_csv(kff_file("USG Global Health MOU Co-Financing Amount by Country as of Oct.08.2026.csv"),
                  show_col_types = FALSE, na = c("", "-", " -", "NA")) %>%
  rename(country = 1, us_funding_usd = 2, coinvest_usd = 3) %>%
  mutate(across(c(us_funding_usd, coinvest_usd), ~ suppressWarnings(as.numeric(str_trim(.x)))),
         iso3 = to_iso3(country))
region <- read_csv(kff_file("Signed MOU by Country_Region.csv"), show_col_types = FALSE) %>%
  transmute(iso3 = to_iso3(Country), kff_region = Region,
            us_funding_region_file = suppressWarnings(as.numeric(`US Funding`)))
total_by_country <- read_csv(kff_file("Global Health MOU Funding by Country as of OCT.08.2026.csv"),
                             show_col_types = FALSE, na = c("", "-", " -")) %>%
  transmute(iso3 = to_iso3(`Country Name`),
            total_mou_usd_kff = suppressWarnings(as.numeric(`Overall Funding Amount`)))
hist5 <- read_csv(kff_file("Historical vs. Proposed 5-Year USG Global Health MOU Funding by Country.csv"),
                  show_col_types = FALSE, na = c("NA", "")) %>%
  transmute(iso3 = to_iso3(`Country Name`),
            us_planned_fy21_25_usd = `FY21-25 (Planned)`, us_mou_fy26_30_usd = `FY26-30 (MOU)`)
areas <- read_csv(kff_file("USG Global Health MOU Program Areas by Country.csv"),
                  show_col_types = FALSE) %>% filter(Country != "Total") %>%
  mutate(iso3 = to_iso3(Country)) %>% select(-Country) %>%
  rename_with(~ paste0("prog_", str_to_lower(str_replace_all(.x, "[^A-Za-z]+", "_"))), -iso3) %>%
  mutate(across(starts_with("prog_"), ~ .x == "Y"))
details <- read_csv(kff_file("Additional Details for Countries with Publicly Available MOUs.csv"),
                    show_col_types = FALSE, skip = 1) %>%
  filter(Country != "Total") %>%
  mutate(country = str_remove(Country, "^:[a-z]{2}: "), iso3 = to_iso3(country)) %>%
  transmute(iso3, text_public_kff = TRUE,
            data_sharing = str_detect(`Data sharing agreement (including timeframe if specified)`, "10004"),
            data_sharing_years = suppressWarnings(as.numeric(str_extract(`Data sharing agreement (including timeframe if specified)`, "\\d+(?= years)"))),
            specimen_sharing = str_detect(`Specimen sharing agreement (including timeframe if specified)`, "10004"),
            specimen_sharing_years = suppressWarnings(as.numeric(str_extract(`Specimen sharing agreement (including timeframe if specified)`, "\\d+(?= years)"))),
            penalties = str_detect(Penalties, "10004"),
            incentives = str_detect(Incentives, "10004"))

kff <- cofin %>% select(iso3, country_kff = country, us_funding_usd, coinvest_usd) %>%
  full_join(total_by_country, by = "iso3") %>%
  left_join(region, by = "iso3") %>%
  left_join(kff_dates, by = "iso3") %>%
  left_join(hist5, by = "iso3") %>%
  left_join(areas, by = "iso3") %>%
  left_join(details, by = "iso3") %>%
  left_join(ledger %>% select(iso3, term_years, term_basis, evidence_status, verification_result,
                              partner_currency_documented, evidence_locator, agreement_url, release_url,
                              kff_us_ledger = kff_us_usd, kff_partner_ledger = kff_partner_usd),
            by = "iso3") %>%
  mutate(mou_signed = TRUE,
         split_published = !is.na(coinvest_usd) & !is.na(us_funding_usd),
         total_mou_usd = if_else(split_published, us_funding_usd + coinvest_usd, total_mou_usd_kff),
         coinvest_share_pct = 100 * coinvest_usd / (us_funding_usd + coinvest_usd),
         # The annual average uses each agreement's documented term (3 or 5 years).
         coinvest_annual_usd = coinvest_usd / term_years,
         us_annual_usd = us_funding_usd / term_years,
         coinvest_annual_5yr_usd = coinvest_usd / 5,            # v4 rule, kept for the replication check
         us_change_vs_fy21_25_pct = 100 * (us_mou_fy26_30_usd / us_planned_fy21_25_usd - 1),
         text_public_kff = coalesce(text_public_kff, FALSE),
         usd_pledge_assumed = split_published & iso3 != "KEN",
         usd_pledge_documented = split_published & partner_currency_documented == "USD (signed text)",
         region_amount_discrepancy = if_else(!is.na(us_funding_region_file) &
                                               abs(us_funding_region_file - us_funding_usd) > 1,
                                             "US amount differs between KFF files", NA_character_))
check(nrow(kff) == 36 && !any(is.na(kff$iso3)), "KFF table has 36 ISO-coded agreements")
check(sum(kff$split_published) == 34, "34 agreements have both financing components")
# The ledger repeats the KFF amounts it verified; they must equal the raw KFF file.
chk <- kff %>% filter(split_published)
check(isTRUE(all.equal(chk$coinvest_usd, chk$kff_partner_ledger)) &&
        isTRUE(all.equal(chk$us_funding_usd, chk$kff_us_ledger)), "ledger amounts equal KFF file amounts")
kff <- kff %>% select(-kff_us_ledger, -kff_partner_ledger)
write_csv(kff, file.path(DER, "kff_agreements.csv"), na = "")

# KFF annual US funding 2021-2030 (countries with public texts)
annual <- read_csv(kff_file("U.S. Global Health Funding for Countries with Publicly Available MOUs, 2021-2025 vs. 2026-2030.csv"),
                   show_col_types = FALSE, na = c("NA", "")) %>%
  rename(year = Country) %>% filter(year != 2025.5) %>%
  pivot_longer(-year, names_to = "country", values_to = "us_funding_usd") %>%
  mutate(iso3 = to_iso3(str_remove_all(country, "\\*")), year = as.integer(year)) %>%
  select(iso3, year, us_funding_usd)
write_csv(annual, file.path(DER, "kff_annual_us_funding_long.csv"), na = "")

# KFF US funding by area of cooperation, 2026-2030 (17 countries)
area_raw <- read_csv(kff_file("Change in USG Global Health MOU Funding by Area of Cooperation for Countries with Publicly Available MOUs, 2026-2030.csv"),
                     show_col_types = FALSE, col_types = cols(.default = "c"))
names(area_raw)[1] <- "label"
area_long <- area_raw %>%
  mutate(area = if_else(is.na(`2026`) & is.na(`2030`), label, NA_character_)) %>%
  fill(area) %>% filter(label != area) %>%
  select(area, country = label, `2026`:`2030`) %>%
  pivot_longer(`2026`:`2030`, names_to = "year", values_to = "us_funding_usd") %>%
  mutate(iso3 = to_iso3(country), year = as.integer(year),
         us_funding_usd = as.numeric(us_funding_usd),
         health_security_area = area %in% HEALTH_SECURITY_AREAS) %>%
  select(iso3, area, health_security_area, year, us_funding_usd)
check(n_distinct(area_long$iso3) == 17, "area-of-cooperation budgets cover 17 countries")
write_csv(area_long, file.path(DER, "kff_area_of_cooperation_long.csv"), na = "")

# ---- 3. WHO Global Health Expenditure Database (release of 12 Dec 2025) -----
ghed_vars <- c("location", "code", "region", "income", "year", "pop", "gdp", "gge", "xrt",
               "gdpd", "che_usd", "gghed", "gghed_usd", "ext_usd", "gghed_pc_usd",
               "gghed_gge", "gghed_gdp", "gghed_che", "ext_che", "oops_che", "gge_gdp",
               "che_gdp", "gdp_pc_usd")
ghed <- read_excel(raw_file("who_ghed", "^GHED_data\\.xlsx$"), sheet = "Data", guess_max = 5000) %>%
  select(all_of(ghed_vars)) %>% filter(year >= 2010) %>%
  mutate(iso3 = code, gge_usd_m = gge / xrt, gdp_usd_m = gdp / xrt,
         gghed_real_ncu = gghed / (gdpd / 100))       # constant local currency (GDP deflator)
write_csv(ghed, file.path(DER, "ghed_panel_2010_2024.csv"), na = "")

g23 <- ghed %>% filter(year == GHED_BASE_YEAR) %>%
  transmute(iso3, country = location, who_region = region, income_ghed = income,
            pop_2023_thousands = pop, gghed_usd_m_2023 = gghed_usd,
            gghed_pc_usd_2023 = gghed_pc_usd, gghed_gge_2023 = gghed_gge,
            gghed_gdp_2023 = gghed_gdp, ext_che_2023 = ext_che, oops_che_2023 = oops_che,
            gge_usd_m_2023 = gge_usd_m, gdp_usd_m_2023 = gdp_usd_m, gdp_pc_usd_2023 = gdp_pc_usd)
# Spending trend: compound annual growth 2015-23. A country without a 2015
# value has no 2015-23 trend (South Sudan's series starts in 2017); its
# first-available-year trend is stored separately and flagged.
trend <- ghed %>% filter(year >= TREND_START, year <= GHED_BASE_YEAR, !is.na(gghed_usd), gghed_usd > 0) %>%
  group_by(iso3) %>% arrange(year) %>%
  summarise(trend_first_year = first(year),
            gghed_usd_first = first(gghed_usd), gghed_real_first = first(gghed_real_ncu),
            gghed_usd_last = last(gghed_usd), gghed_real_last = last(gghed_real_ncu),
            last_year = last(year), .groups = "drop") %>%
  mutate(gghed_usd_cagr_2015_23 = if_else(trend_first_year == TREND_START & last_year == GHED_BASE_YEAR,
                                          100 * cagr(gghed_usd_first, gghed_usd_last, GHED_BASE_YEAR - TREND_START), NA_real_),
         gghed_real_lcu_cagr_2015_23 = if_else(trend_first_year == TREND_START & last_year == GHED_BASE_YEAR,
                                               100 * cagr(gghed_real_first, gghed_real_last, GHED_BASE_YEAR - TREND_START), NA_real_),
         gghed_usd_cagr_first_avail = 100 * cagr(gghed_usd_first, gghed_usd_last, last_year - trend_first_year),
         gghed_real_lcu_cagr_first_avail = 100 * cagr(gghed_real_first, gghed_real_last, last_year - trend_first_year)) %>%
  select(iso3, trend_first_year, gghed_usd_cagr_2015_23, gghed_real_lcu_cagr_2015_23,
         gghed_usd_cagr_first_avail, gghed_real_lcu_cagr_first_avail)
# Exchange-rate falls, 2015-2023, from annual average rates (local currency per US$).
# Depreciation = loss of local-currency value against the dollar: 1 - xrt(t0)/xrt(t1).
fx <- ghed %>% filter(year >= TREND_START, year <= GHED_BASE_YEAR, !is.na(xrt)) %>% arrange(iso3, year) %>%
  group_by(iso3) %>%
  summarise(
    max_1y_depreciation_pct = if (n() > 1) 100 * max(1 - head(xrt, -1) / tail(xrt, -1)) else NA_real_,
    max_3y_depreciation_pct = if (n() > 3) 100 * max(1 - head(xrt, -3) / tail(xrt, -3)) else NA_real_,
    depreciation_2015_23_pct = 100 * (1 - first(xrt) / last(xrt)), .groups = "drop")
ghed_country <- g23 %>% left_join(trend, by = "iso3") %>% left_join(fx, by = "iso3")

# ---- 4. WHO IHR SPAR 2025 (self-assessment) ----------------------------------
spar_raw <- read_excel(raw_file("who_spar", "^IHRScoreperCapacity.*\\.xlsx$"),
                       sheet = 1, col_names = FALSE, .name_repair = "minimal")
hdr_row <- which(spar_raw[[1]] == "Data Received")
spar <- spar_raw[(hdr_row + 1):nrow(spar_raw), 1:55]
names(spar) <- as.character(unlist(spar_raw[hdr_row, 1:55]))
spar <- spar %>%
  rename(spar_data_received = `Data Received`, who_region_spar = Region,
         state_party = `States Party of IHR`, iso3 = `ISO Code`, spar_2025 = `Total Average`) %>%
  mutate(across(c(spar_2025, matches("^C\\.\\d+$")), ~ suppressWarnings(as.numeric(.x)))) %>%
  select(iso3, state_party, who_region_spar, spar_data_received, spar_2025,
         spar_c4_laboratory = C.4, spar_c5_surveillance = C.5, spar_c6_human_resources = C.6,
         spar_c7_emergency_mgmt = C.7) %>%
  filter(!is.na(iso3))
spar_global_check <- as.numeric(spar_raw[[5]][which(spar_raw[[1]] == "AVG Global Capacity")])
check(spar_global_check == SPAR_GLOBAL_MEAN, "WHO global SPAR average in the file equals 63")

# ---- 5. Global Health Security Index 2021 (195 countries) --------------------
ghs_src <- read_csv(raw_file("ghs_ahs", "^health-security-ghs-full.*\\.csv$"),
                    show_col_types = FALSE) %>%
  mutate(iso2 = toupper(country_code), iso3 = iso_tbl$iso3[match(iso2, iso_tbl$iso2)])
ghs21 <- ghs_src %>% filter(year == 2021)
check(nrow(ghs21) == 195 && !any(is.na(ghs21$iso3)), "GHS 2021 has 195 ISO-coded countries")
# Reference statistics are computed in the index's own population (195), then joined.
GHS_MEDIAN_2021 <- median(ghs21$overall)
ghs <- ghs21 %>% transmute(iso3, ghs_overall_2021 = overall, ghs_detect_2021 = `2`, ghs_country = country)

# ---- 6. Africa Health Security Index 2026 (54 countries) ---------------------
read_ahs <- function(yr) {
  x <- suppressMessages(read_excel(
    raw_file("ghs_ahs", "^2026-AHS-Index-workbook.*\\.xlsx$"),
    sheet = paste0("Score table_", yr), col_names = FALSE, col_types = "text",
    .name_repair = "unique", range = cell_limits(c(4, 1), c(400, 70))))
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  hdr <- as.character(unlist(x[1, ]))
  cty_cols <- which(seq_along(hdr) >= 8 & !is.na(hdr) & hdr != "")
  keep_codes <- c("0", "2", "2.1", "2.3")
  body <- x[-1, ]
  code <- body[[2]]
  num <- suppressWarnings(as.numeric(code))             # 2.3 can be stored as 2.2999999
  code <- ifelse(!is.na(num) & !grepl("\\..*\\.", code), as.character(round(num, 2)), code)
  sel <- body[code %in% keep_codes, cty_cols, drop = FALSE]
  names(sel) <- hdr[cty_cols]
  sel$code <- code[code %in% keep_codes]
  sel %>% pivot_longer(-code, names_to = "country_ahs", values_to = "score") %>%
    mutate(score = as.numeric(score), year = yr)
}
ahs_long <- read_ahs(2026) %>%
  mutate(iso3 = to_iso3(country_ahs),
         var = recode(code, "0" = "overall", "2" = "detect", "2.1" = "lab", "2.3" = "surveillance"))
check(!any(is.na(ahs_long$iso3)), "all AHS countries map to ISO3")
ahs <- ahs_long %>% select(iso3, var, year, score) %>%
  pivot_wider(names_from = c(var, year), values_from = score, names_glue = "ahs_{var}_{year}")
check(nrow(ahs) == 54, "AHS 2026 covers 54 countries")
AHS_MEDIAN_2026 <- median(ahs$ahs_overall_2026)

# Index populations for the agreement-status comparison (supplement)
index_universe <- bind_rows(
  ghs21 %>% transmute(iso3, index = "GHS 2021", score = overall),
  ahs %>% transmute(iso3, index = "AHS 2026", score = ahs_overall_2026)) %>%
  mutate(agreement = iso3 %in% kff$iso3)
write_csv(index_universe, file.path(DER, "index_universes.csv"), na = "")

# ---- 7. Debt: LIC-DSF ratings, IMF Global Debt Database, WDI API pull --------
dsf <- read_csv(raw_file("debt", "^LIC_DSF.*\\.csv$"),
                show_col_types = FALSE) %>%
  transmute(iso3 = to_iso3(Country),
            dsf_external_risk = str_replace(`Risk of external debt distress`, "^In distress$", "In debt distress"),
            dsf_overall_risk = str_replace(`Risk of overall debt distress`, "^In distress$", "In debt distress"),
            dsf_publication = `Publication Date`) %>%
  mutate(across(c(dsf_external_risk, dsf_overall_risk),
                ~ factor(.x, levels = c("Low", "Moderate", "High", "In debt distress"), ordered = TRUE)),
         dsf_high_or_distress = dsf_overall_risk >= "High")
check(!any(is.na(dsf$iso3)), "all LIC-DSF countries map to ISO3")

gdd <- read_csv(raw_file("debt", "IMF\\.FAD_GDD.*\\.csv$"),
                show_col_types = FALSE, guess_max = 3000) %>%
  filter(INDICATOR %in% c("Debt instruments, General government, Percent of GDP",
                          "Debt instruments, Central government, Percent of GDP")) %>%
  select(COUNTRY, INDICATOR, `2015`:`2024`) %>%
  pivot_longer(`2015`:`2024`, names_to = "year", values_to = "value") %>%
  filter(!is.na(value)) %>% mutate(year = as.integer(year)) %>%
  group_by(COUNTRY, INDICATOR) %>% slice_max(year, n = 1) %>% ungroup() %>%
  mutate(var = if_else(str_detect(INDICATOR, "General"), "gg", "cg")) %>%
  select(COUNTRY, var, value, year) %>%
  pivot_wider(names_from = var, values_from = c(value, year)) %>%
  transmute(iso3 = to_iso3(COUNTRY),
            gdd_gov_debt_gdp = coalesce(value_gg, value_cg),
            gdd_gov_debt_basis = if_else(!is.na(value_gg), "General government", "Central government"),
            gdd_gov_debt_year = if_else(!is.na(value_gg), year_gg, year_cg)) %>%
  filter(!is.na(iso3))

# Optional: the IDS DataBank extract was queried by creditor (AfDB, IDA, ...), so
# its headline ratios are empty. Headline ratios were pulled for counterpart
# "World" from the World Bank API on 23 Nov 2026 (data/curated/worldbank_debt_api_...).
if (length(list.files(file.path(RAW, "debt"), pattern = "_Data\\.csv$"))) {
  ids_check <- read_csv(raw_file("debt", "_Data\\.csv$"),
                        show_col_types = FALSE, locale = locale(encoding = "latin1"),
                        col_types = cols(.default = "c")) %>%
    filter(!is.na(`Series Code`)) %>%
    pivot_longer(matches("YR\\d{4}"), names_to = "yr", values_to = "v") %>%
    mutate(v = suppressWarnings(as.numeric(v))) %>%
    group_by(`Series Code`) %>% summarise(non_missing = sum(!is.na(v)), .groups = "drop")
  write_csv(ids_check, file.path(OUT_L, "ids_extract_coverage_check.csv"))
}
wb <- read_csv(file.path(INP, "worldbank_debt_api_2026-11-23.csv"), show_col_types = FALSE) %>%
  mutate(var = recode(indicator_code,
                      "DT.TDS.DECT.GN.ZS" = "debt_service_gni", "DT.TDS.DECT.EX.ZS" = "debt_service_exports",
                      "DT.DOD.DECT.GN.ZS" = "ext_debt_gni", "GC.XPN.INTP.RV.ZS" = "interest_revenue",
                      "DT.TDS.DPPG.GN.ZS" = "ppg_debt_service_gni"))
debt <- wb %>% filter(year <= 2024) %>% group_by(iso3, var) %>% slice_max(year, n = 1) %>%
  ungroup() %>% select(iso3, var, value, year) %>%
  pivot_wider(names_from = var, values_from = c(value, year), names_glue = "wb_{var}_{.value}") %>%
  rename_with(~ str_replace(.x, "_value$", ""))

# ---- 8. Health workforce (WHO GHO API pull, 23 Nov 2026) ---------------------
wf <- read_csv(file.path(INP, "who_workforce_api_2026-11-23.csv"), show_col_types = FALSE) %>%
  mutate(var = if_else(indicator_code == "HWF_0001", "doctors", "nurses_midwives")) %>%
  select(iso3, var, value_per_10000, latest_year) %>%
  pivot_wider(names_from = var, values_from = c(value_per_10000, latest_year),
              names_glue = "hwf_{var}_{.value}") %>%
  rename(hwf_doctors_per10k = hwf_doctors_value_per_10000,
         hwf_nurses_midwives_per10k = hwf_nurses_midwives_value_per_10000,
         hwf_doctors_year = hwf_doctors_latest_year,
         hwf_nurses_midwives_year = hwf_nurses_midwives_latest_year) %>%
  mutate(hwf_dnm_per10k = hwf_doctors_per10k + hwf_nurses_midwives_per10k,
         hwf_years_differ = hwf_doctors_year != hwf_nurses_midwives_year,
         hwf_below_sdg_threshold = hwf_dnm_per10k < SDG_HRH_THRESHOLD)

# ---- 9. Pandemic Fund (rounds 1-3, 2026 targeted call, Ebola financing) -------
pf_proj <- read_csv(file.path(INP, "pandemic_fund_projects.csv"), show_col_types = FALSE)
check(!anyDuplicated(pf_proj$project_id), "Pandemic Fund project IDs are unique")
pf_round_totals <- pf_proj %>% group_by(round) %>%
  summarise(n_projects = n(), grant_usd_m = sum(grant_usd) / 1e6, .groups = "drop") %>%
  mutate(published_usd_m = c(338.4, 547.0, 499.6)[round],
         published_n = c(19, 28, 20)[round],
         matches_published = abs(grant_usd_m - published_usd_m) < 0.05 & n_projects == published_n)
write_csv(pf_round_totals, file.path(OUT_L, "pandemic_fund_round_totals_check.csv"))
check(pf_round_totals$matches_published, "Pandemic Fund round totals match published totals (US$0.05m tolerance)")
pf_long <- pf_proj %>%
  mutate(country = str_split(countries_named, ";\\s*")) %>% unnest(country) %>%
  filter(!is.na(country), country != "") %>%
  group_by(project_id) %>% mutate(n_named = n()) %>% ungroup() %>%
  mutate(iso3 = to_iso3(country))
check(!any(is.na(pf_long$iso3)), "all Pandemic Fund beneficiaries map to ISO3")
check(!anyDuplicated(pf_long[c("project_id", "iso3")]), "project-country pairs are unique")
write_csv(pf_long, file.path(DER, "pandemic_fund_project_country_long.csv"), na = "")
pf_des <- read_csv(file.path(INP, "pandemic_fund_country_designations.csv"), show_col_types = FALSE) %>%
  mutate(iso3 = to_iso3(country))
check(!any(is.na(pf_des$iso3)), "all Pandemic Fund designations map to ISO3")
pf_country <- pf_long %>% group_by(iso3) %>%
  summarise(pf_single_grant_usd = sum(grant_usd[project_type == "Single"]),
            pf_single_n = sum(project_type == "Single"),
            pf_single_rounds = paste(sort(unique(round[project_type == "Single"])), collapse = ";"),
            pf_named_multi_regional_n = sum(project_type != "Single"),
            pf_projects = paste(project_id, collapse = ";"), .groups = "drop") %>%
  full_join(pf_des %>% group_by(iso3) %>%
              summarise(pf_cfp4_eligible = any(designation == "CfP4_eligible"),
                        pf_efp_2026 = paste(designation[str_detect(designation, "EFP")], collapse = ";"),
                        .groups = "drop"), by = "iso3")
write_csv(pf_country, file.path(DER, "pandemic_fund_country.csv"), na = "")

# ---- 10. Assemble the master file (one row per GHED country) ----------------
master <- ghed_country %>%
  left_join(kff %>% select(-country_kff), by = "iso3") %>%
  left_join(spar, by = "iso3") %>%
  left_join(ghs %>% select(-ghs_country), by = "iso3") %>%
  left_join(ahs, by = "iso3") %>%
  left_join(dsf, by = "iso3") %>%
  left_join(gdd, by = "iso3") %>%
  left_join(debt, by = "iso3") %>%
  left_join(wf, by = "iso3") %>%
  left_join(pf_country, by = "iso3") %>%
  mutate(mou_signed = coalesce(mou_signed, FALSE),
         split_published = coalesce(split_published, FALSE),
         across(c(pf_single_grant_usd, pf_single_n, pf_named_multi_regional_n), ~ coalesce(.x, 0)),
         pf_cfp4_eligible = coalesce(pf_cfp4_eligible, FALSE),
         pf_efp_2026 = na_if(pf_efp_2026, ""),
         pf_status = case_when(pf_single_n > 0 ~ "Single-country award",
                               pf_named_multi_regional_n > 0 ~ "Named in multi-country or regional award only",
                               TRUE ~ "Not named in any award"))
check(all(kff$iso3 %in% master$iso3), "all 36 agreements join to GHED")

# ---- 11. Derived variables -----------------------------------------------------
# pledge_share_pct: average annual partner commitment over the documented term
# as a percentage of 2023 domestic general government health expenditure.
master <- master %>%
  mutate(
    gghed_usd_2023 = gghed_usd_m_2023 * 1e6,
    pledge_share_pct = 100 * coinvest_annual_usd / gghed_usd_2023,
    pledge_share_5yr_pct = 100 * coinvest_annual_5yr_usd / gghed_usd_2023,
    pledge_share_gge_pct = 100 * coinvest_annual_usd / (gge_usd_m_2023 * 1e6),
    pledge_dep20_pct = if_else(usd_pledge_assumed, pledge_share_pct / (1 - 0.20), pledge_share_pct),
    pledge_dep30_pct = if_else(usd_pledge_assumed, pledge_share_pct / (1 - 0.30), pledge_share_pct),
    pledge_dep20_documented_pct = if_else(usd_pledge_documented, pledge_share_pct / (1 - 0.20), pledge_share_pct),
    spar_below_global = spar_2025 < SPAR_GLOBAL_MEAN,
    ghs_below_median = ghs_overall_2021 < GHS_MEDIAN_2021,
    ahs_below_median = ahs_overall_2026 < AHS_MEDIAN_2026,
    high_pledge = pledge_share_pct >= PLEDGE_THRESHOLD,
    screen_group = split_published & high_pledge & spar_below_global,
    screen_group_dep20 = split_published & pledge_dep20_pct >= PLEDGE_THRESHOLD & spar_below_global,
    quadrant = case_when(
      !split_published ~ NA_character_,
      high_pledge & spar_below_global ~ "A",
      high_pledge & !spar_below_global ~ "B",
      !high_pledge & spar_below_global ~ "C",
      TRUE ~ "D"),
    debt_group = case_when(dsf_high_or_distress %in% TRUE ~ "High risk or in debt distress",
                           !is.na(dsf_overall_risk) ~ "Low or moderate risk",
                           TRUE ~ "Not rated under LIC-DSF"))

master <- master %>% relocate(iso3, country, who_region, kff_region, mou_signed, split_published) %>%
  arrange(desc(mou_signed), country)
check(sum(master$split_published) == 34 && sum(!is.na(master$pledge_share_pct)) == 34,
      "34 pledge shares computed")
write_csv(master, file.path(DER, "master_country_dataset.csv"), na = "")
REF <- list(GHS_MEDIAN_2021 = GHS_MEDIAN_2021, AHS_MEDIAN_2026 = AHS_MEDIAN_2026,
            n_ghs = nrow(ghs21), n_ahs = nrow(ahs))
write_csv(tibble(name = names(REF), value = unlist(REF)), file.path(DER, "reference_values.csv"))
log_line("1 build dataset: done;", nrow(master), "countries;", sum(master$mou_signed), "agreements;",
         sum(master$split_published), "with both components")
