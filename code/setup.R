# =============================================================================
# setup.R
# Project : Fixed spending targets and outbreak preparedness in US bilateral
#           health agreements (BMJ Analysis)
# Purpose : Paths, packages, constants and helper functions shared by every
#           script. Sourced by run_all.R; not meant to be run alone.
# Authors : Michael Muhoozi, Monica H Swahn (VCU School of Public Health)
# Version : 1.0.0, 24 Nov 2026
# =============================================================================

# ---- Packages ---------------------------------------------------------------
# All packages are on CRAN. renv.lock records the versions used for the
# published results; results/logs/sessionInfo.txt records the run.
pkgs <- c("readxl", "readr", "dplyr", "tidyr", "stringr", "purrr", "tibble",
          "ggplot2", "ggrepel", "scales", "boot", "jsonlite", "stringi")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install the missing R packages first:\n  install.packages(c(\"",
                          paste(missing, collapse = "\", \""), "\"))", call. = FALSE)
suppressPackageStartupMessages({
  library(readxl); library(readr); library(dplyr); library(tidyr)
  library(stringr); library(purrr); library(tibble); library(ggplot2)
  library(ggrepel); library(scales); library(boot); library(jsonlite)
})
options(dplyr.summarise.inform = FALSE, scipen = 999)
# A UTF-8 locale keeps accented country names and symbols (>=, dagger) intact.
if (!isTRUE(l10n_info()$`UTF-8`)) {
  for (loc in c("en_US.UTF-8", "C.UTF-8", "en_GB.UTF-8")) {
    if (suppressWarnings(Sys.setlocale("LC_CTYPE", loc)) != "") break
  }
}

# ---- Paths ------------------------------------------------------------------
# Every path is relative to the repository root (ROOT), which run_all.R sets.
#   data/curated/   inputs the authors transcribed or pulled from public sources
#   data/analysis/  analysis-ready files (written by 1_build_dataset.R)
#   data/raw/       third-party downloads, needed only to rebuild data/analysis
#   results/        everything the analysis writes
if (!exists("ROOT")) ROOT <- normalizePath(getwd())
RAW   <- Sys.getenv("RAW_DATA_DIR", unset = file.path(ROOT, "data", "raw"))
INP   <- file.path(ROOT, "data", "curated")
DER   <- file.path(ROOT, "data", "analysis")
OUT   <- file.path(ROOT, "results")
OUT_T <- file.path(OUT, "tables")
OUT_F <- file.path(OUT, "figures")
OUT_L <- file.path(OUT, "logs")
for (d in c(DER, OUT_T, OUT_F, OUT_L)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(INP))

# raw_file(): find a third-party file in data/raw/<folder>/ by its exact name or,
# failing that, by a name pattern, so a fresh download whose name carries a new
# date stamp is still found. It warns
# if the file differs from the version used for the article (MD5 checksum in
# data/raw/raw_files.csv); results may then differ slightly.
raw_file <- function(folder, name) {
  exact <- file.path(RAW, folder, name)
  hits <- if (file.exists(exact)) exact else
    list.files(file.path(RAW, folder), pattern = name, full.names = TRUE, ignore.case = TRUE)
  if (!length(hits)) stop("Missing raw file in data/raw/", folder, "/: '", name,
                          "'. See 'Rebuilding the analysis-ready data from the original downloads' in README.md.", call. = FALSE)
  f <- hits[1]
  man <- file.path(ROOT, "data", "raw", "raw_files.csv")
  if (file.exists(man)) {
    m <- read.csv(man, stringsAsFactors = FALSE, check.names = FALSE)
    want <- m$md5[m$folder == folder & m$file == basename(f)]
    if (length(want) && !identical(unname(tools::md5sum(f)), want))
      warning("data/raw/", folder, "/", basename(f), " differs from the version used for the article.", call. = FALSE)
  }
  f
}

# ---- Analytic constants -----------------------------------------------------
# These values were fixed before the final analysis; the supplement
# (eMethods 3) gives the reason for each.
PLEDGE_THRESHOLD   <- 10      # % of 2023 domestic government health spending
PLEDGE_GRID        <- c(5, 10, 15, 20)
SPAR_GLOBAL_MEAN   <- 63      # WHO 2025 global SPAR average (row "AVG Global Capacity")
GHED_BASE_YEAR     <- 2023    # latest year with domestic government health spending for all 34
TREND_START        <- 2015
DEPRECIATION       <- c(0.20, 0.30)
SDG_HRH_THRESHOLD  <- 44.5    # doctors + nurses/midwives per 10 000 (WHO SDG index threshold)
BOOT_R             <- 5000
BOOT_SEED          <- 20261123
HEALTH_SECURITY_AREAS <- c("Surveillance & Outbreak Response", "Laboratory Systems",
                           "Health Workforce", "Data Systems")

# ---- Country names to ISO3 --------------------------------------------------
iso_tbl <- read_csv(file.path(INP, "iso_country_codes.csv"), show_col_types = FALSE, na = "")
norm_name <- function(x) {
  x <- stringi::stri_trans_general(enc2utf8(as.character(x)), "Latin-ASCII")
  x <- tolower(x)
  x <- str_replace_all(x, "[\\*\\^~`'’\\.]", "")
  x <- str_replace_all(x, "&", "and")
  x <- str_replace_all(x, "[^a-z ]", " ")
  str_squish(x)
}
manual_iso <- c(
  "democratic republic of the congo" = "COD", "democratic republic of congo" = "COD",
  "congo dem rep" = "COD", "congo democratic republic" = "COD", "drc" = "COD",
  "congo rep" = "COG", "congo brazzaville" = "COG", "congo" = "COG",
  "republic of congo" = "COG", "cote divoire" = "CIV", "cote d ivoire" = "CIV",
  "vietnam" = "VNM", "viet nam" = "VNM", "tanzania" = "TZA",
  "united republic of tanzania" = "TZA", "bolivia" = "BOL",
  "plurinational state of bolivia" = "BOL", "gambia the" = "GMB", "gambia" = "GMB",
  "lao pdr" = "LAO", "lao" = "LAO", "kyrgyz republic" = "KGZ", "kyrgyzstan" = "KGZ",
  "yemen rep" = "YEM", "yemen" = "YEM", "micronesia" = "FSM",
  "micronesia fed sts" = "FSM", "st vincent and the grenadines" = "VCT",
  "st kitts and nevis" = "KNA", "st lucia" = "LCA", "sao tome and principe" = "STP",
  "egypt" = "EGY", "egypt arab rep" = "EGY", "turkiye" = "TUR", "turkey" = "TUR",
  "west bank and gaza" = "PSE", "kosovo" = "XKX", "swaziland" = "SWZ",
  "eswatini" = "SWZ", "cabo verde" = "CPV", "cape verde" = "CPV",
  "somalia federal rep" = "SOM", "venezuela rb" = "VEN", "venezuela" = "VEN",
  "iran" = "IRN", "iran islamic rep" = "IRN", "korea rep" = "KOR",
  "russian federation" = "RUS", "russia" = "RUS", "syria" = "SYR",
  "syrian arab republic" = "SYR", "moldova" = "MDA", "north macedonia" = "MKD",
  "bahamas the" = "BHS", "eritrea the state of" = "ERI", "naoero" = "NRU",
  "nauru" = "NRU", "south sudan" = "SSD", "sudan" = "SDN", "niger" = "NER",
  "guinea" = "GIN", "guinea bissau" = "GNB", "philippines" = "PHL",
  "united kingdom" = "GBR", "united states" = "USA", "czech republic" = "CZE",
  "slovak republic" = "SVK", "hong kong sar china" = "HKG", "macao sar china" = "MAC",
  "taiwan" = "TWN", "brunei darussalam" = "BRN", "timor leste" = "TLS",
  "antigua barbuda" = "ATG", "st kitts nevis" = "KNA", "trinidad tobago" = "TTO",
  "bosnia herzegovina" = "BIH", "sao tome principe" = "STP",
  "saint vincent and the grenadines" = "VCT", "saint kitts and nevis" = "KNA",
  "saint lucia" = "LCA", "micronesia federated states of" = "FSM",
  "korea dem peoples rep" = "PRK", "north korea" = "PRK", "south korea" = "KOR",
  "palestine" = "PSE", "cote d ivoire the" = "CIV", "curacao" = "CUW",
  "aruba kingdom of the netherlands" = "ABW", "netherlands the" = "NLD",
  "mauritania islamic republic of" = "MRT", "afghanistan islamic republic of" = "AFG")
to_iso3 <- function(x) {
  nx <- norm_name(x)
  lut <- bind_rows(
    tibble(k = norm_name(iso_tbl$name), iso3 = iso_tbl$iso3),
    tibble(k = norm_name(iso_tbl$official_name), iso3 = iso_tbl$iso3),
    tibble(k = norm_name(iso_tbl$common_name), iso3 = iso_tbl$iso3)) %>%
    filter(k != "") %>% distinct(k, .keep_all = TRUE)
  out <- unname(manual_iso[nx])
  hit <- match(nx, lut$k)
  out[is.na(out)] <- lut$iso3[hit][is.na(out)]
  out
}

# ---- Helpers ----------------------------------------------------------------
cagr <- function(v0, v1, n) ifelse(!is.na(v0) & !is.na(v1) & v0 > 0 & v1 > 0, (v1 / v0)^(1 / n) - 1, NA_real_)
write_out <- function(df, name, dir = OUT_T) {
  write_csv(df, file.path(dir, paste0(name, ".csv")), na = "")
  invisible(df)
}
log_line <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")
check <- function(cond, msg) if (!isTRUE(all(cond))) stop("Check failed: ", msg, call. = FALSE)
