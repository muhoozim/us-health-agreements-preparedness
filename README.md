# Fixed spending targets and outbreak preparedness in US bilateral health agreements

Code and data for:

> Muhoozi M, Swahn MH. Fixed spending targets and outbreak preparedness in US bilateral health agreements. *BMJ* (Analysis), submitted 2026.

Release **v1.0.0** (24 November 2026). Everything here uses public data.

## What the study does

By October 2026, 36 countries had signed bilateral health agreements with the United States. The agreements ask partner governments to raise their own health spending on fixed schedules, and some allow the United States to reduce its funding if a target is missed. We compared each government's average annual commitment with its own health spending (the **pledge share**), and asked whether countries with large commitments also report weaker outbreak preparedness or carry more debt.

## Reproduce the results in three steps

**1. Get the files.** Click the green **Code** button on this page, then **Download ZIP**, and unzip it. Or, with git:

```sh
git clone https://github.com/muhoozim/us-health-agreements-preparedness.git
```

**2. Install R and the packages.** Install [R](https://cran.r-project.org) (version 4.3 or later) and, if you like, [RStudio](https://posit.co/download/rstudio-desktop/). Then run this once in R:

```r
install.packages(c("readxl", "readr", "dplyr", "tidyr", "stringr", "purrr", "tibble",
                   "ggplot2", "ggrepel", "scales", "boot", "jsonlite", "stringi"))
```

**3. Run the analysis.** Either open `us-health-agreements-preparedness.Rproj` in RStudio, open `run_all.R` and click **Source**, or type this in a terminal inside the folder:

```sh
Rscript run_all.R
```

It takes under a minute and needs no downloads. It rewrites everything in `results/` and ends by checking every number in the article that the analysis produces. The last lines should read:

```
4 check paper numbers: 57 of 57 computed numbers reproduced; 4 numbers come from other publications
Done. Results are in .../results
```

All paths are relative to the folder, so it runs wherever you put it, on Windows, macOS or Linux.

## Where each part of the article comes from

| In the article or supplement | File in this repository |
|---|---|
| Every number in the article, with its source | `results/paper_numbers_check.csv` (list: `data/paper_numbers.csv`) |
| Every estimate, under stable names | `results/results.json` |
| Figure 1 (PNG at 600 dpi and PDF) and its data | `results/figures/Figure1_pledge_share_preparedness_debt.*`, `results/tables/Figure1_data.csv` |
| Table 1 | `results/tables/Table1_country_types.csv` |
| eTable 1 (agreement ledger) | `data/curated/agreement_ledger.csv` |
| eTable 2 (country data) | `results/tables/eTable_country_profiles.csv` |
| eTable 3 (other commitment amounts and populations) | `results/tables/eTable_numerator_scenarios.csv` |
| eTable 4 and eFigure 1 (cut-offs and preparedness measures) | `results/tables/eTable_threshold_grid.csv`, `results/figures/eFigure1_*` |
| eFigure 2 (external preparedness indices) | `results/figures/eFigure2_*` |
| eTable 5 (rank correlations) | `results/tables/eTable_correlations.csv` |
| eTable 6 and eFigure 3 (preparedness by agreement status) | `results/tables/eTable_preparedness_by_agreement_status.csv`, `results/figures/eFigure3_*` |
| eTable 7 (debt and exchange rates) | `results/tables/eTable_currency.csv` |
| eTable 8 and eFigure 4 (US funding by area) | `results/tables/eTable_us_funding_by_area*.csv`, `results/tables/eTable_us_outbreak_functions_by_country.csv`, `results/figures/eFigure4_*` |
| eTable 9 and eFigure 5 (health spending trends) | `results/tables/eTable_spending_trends.csv`, `results/figures/eFigure5_*` |
| eTable 10 (Pandemic Fund) | `results/tables/eTable_pandemic_fund.csv` |
| eTable 11 (signatories and other countries) | `results/tables/eTable_signatories_vs_other_lmic.csv` |
| eTable 12 (agreement clauses) | `data/curated/agreement_clauses_reviewed.csv` |
| eFigure 6 (country profiles) | `results/figures/eFigure6_country_profiles.*` |
| Excel versions of the data and of the main calculations | `results/Master_dataset.xlsx`, `results/Analysis_workbook.xlsx` |

## Folder layout

```
run_all.R            the only script you need to run
code/                setup.R, 1_build_dataset.R, 2_analysis.R, 3_figures.R,
                     4_check_paper_numbers.R, and two optional Excel builders
data/
  curated/           amounts and clauses the authors checked against agreement texts,
                     Pandemic Fund transcriptions, World Bank and WHO API pulls,
                     and the register of every source (sources_register.csv)
  analysis/          analysis-ready files: one row per country, plus long tables
  raw/               empty: only needed to rebuild data/analysis (see below)
  codebook.csv       definition and source of every variable
  paper_numbers.csv  each number in the article and where it comes from
results/             tables, figures, results.json, checks and Excel workbooks
```

## Key definitions

- **Pledge share**: the partner government's commitment divided by the length of its agreement (five years, or three for Bolivia, Botswana, Panama and South Sudan), as a percentage of its domestic government health spending in 2023.
- **Self-reported preparedness**: the 2025 score each government reports to WHO under the International Health Regulations (SPAR, 0 to 100). The 2025 global average is 63.
- **The group of ten**: countries with a pledge share of 10% or more and a SPAR score below 63. The cut-offs sort countries; they are not tipping points, and the supplement shows the results at other cut-offs and with two external preparedness indices.

## Data sources

All sources are public. The table gives the version used and where to find it.

| Data | Publisher | Version used | Link |
|---|---|---|---|
| Agreement amounts, dates and US funding | KFF | Data as of 8 October 2026 | [KFF agreement tracker](https://www.kff.org/global-health-policy/kff-tracker-america-first-mou-bilateral-global-health-agreements/) |
| Signed agreement texts (Uganda, Malawi, Kenya) | Released under the US Freedom of Information Act; hosted by Public Citizen | Signed Dec 2025 to Jan 2026 | [Uganda](https://www.citizen.org/wp-content/uploads/2026-0012QN-Uganda-Health-12.10.2025.pdf), [Malawi](https://www.citizen.org/wp-content/uploads/2026-0015QN-Malawi-1.13.2026.pdf), [Kenya](https://www.citizen.org/wp-content/uploads/2026-0007QN-Kenya-Health-12.4.2025.pdf) |
| Funding-reduction clauses in 17 agreement texts | Public Citizen and Partners In Health | 30 August 2026 | [Report](https://www.citizen.org/article/trumps-bilateral-agreements-reshape-global-health-funding/) |
| Government health spending, exchange rates, population | World Health Organization | Global Health Expenditure Database, release of 12 Dec 2025 | [GHED](https://apps.who.int/nha/database/Select/Indicators/en) |
| Self-reported preparedness (SPAR) | World Health Organization | 2025 reporting cycle | [e-SPAR scores by capacity](https://extranet.who.int/e-spar/Home/CapacityScoreDetails) |
| Global Health Security Index | Nuclear Threat Initiative and Johns Hopkins Center for Health Security | 2021 | [GHS Index data](https://ghsindex.org/global/data/) |
| Africa Health Security Index | Nuclear Threat Initiative and partners | 2026 | [AHS Index](https://ghsindex.org/africa/) |
| Debt distress ratings | IMF and World Bank | List of LIC debt sustainability analyses, 2026 | [IMF list](https://www.imf.org/external/Pubs/ft/dsa/DSAlist.pdf) |
| Government debt | International Monetary Fund | Global Debt Database | [IMF GDD](https://data.imf.org/en/datasets/IMF.FAD:GDD) |
| Debt service and external debt ratios | World Bank | World Development Indicators API, pulled 23 Nov 2026 | [World Development Indicators](https://databank.worldbank.org/source/world-development-indicators) (values in `data/curated/worldbank_debt_api_2026-11-23.csv`) |
| Health workforce density | World Health Organization | Global Health Observatory API, pulled 23 Nov 2026 | [HWF_0001](https://ghoapi.azureedge.net/api/HWF_0001), [HWF_0006](https://ghoapi.azureedge.net/api/HWF_0006) (values in `data/curated/who_workforce_api_2026-11-23.csv`) |
| Pandemic Fund awards, rounds 1 to 3 | The Pandemic Fund | Projects page and third-call brief, 2026 | [Projects](https://www.thepandemicfund.org/projects), [Third call](https://www.thepandemicfund.org/news/brief/pandemic-prevention-preparedness-and-response-projects-funded-pandemic-fund-third-call) |
| Pandemic Fund fourth call (debt exemption) | The Pandemic Fund | Guidance note, April 2026 | [Guidance note](https://www.thepandemicfund.org/sites/default/files/2026-04/4th%20CfP_Guidance%20Note.pdf) |
| Pandemic Fund Ebola emergency support | The Pandemic Fund | Board statement, 29 May 2026 | [Statement](https://allafrica.com/stories/202606020082.html) |

`data/curated/sources_register.csv` gives the full citation, access date, use and limitations of each source.

## Rebuilding the analysis-ready data from the original downloads (optional)

`run_all.R` starts from `data/analysis/`, which the authors built from the downloads below. To rebuild those files yourself, download the 15 files listed here, put each in the `data/raw/` subfolder shown (keep the file names), and run:

```sh
Rscript run_all.R --rebuild-data
```

| Put in | File | Download from |
|---|---|---|
| `data/raw/kff/` | 9 files: `Kff_All MOU by Country.xlsx` and 8 chart exports (names in `data/raw/raw_files.csv`) | [KFF tracker](https://www.kff.org/global-health-policy/kff-tracker-america-first-mou-bilateral-global-health-agreements/): use **Download data** under each chart or table |
| `data/raw/who_ghed/` | `GHED_data.XLSX` | [WHO GHED](https://apps.who.int/nha/database/Select/Indicators/en): download the full database |
| `data/raw/who_spar/` | `IHRScoreperCapacity_<date>.xlsx` | [WHO e-SPAR](https://extranet.who.int/e-spar/Home/CapacityScoreDetails): export scores by capacity |
| `data/raw/ghs_ahs/` | `health-security-ghs-full-<date>.csv` | [GHS Index data](https://ghsindex.org/global/data/) |
| `data/raw/ghs_ahs/` | `2026-AHS-Index-workbook_FINAL.xlsx` | [AHS Index](https://ghsindex.org/africa/) |
| `data/raw/debt/` | `LIC_DSF_Debt_Sustainability_with_metadata(LIC_DSF).csv` (country, external risk, overall risk, publication date) | [IMF list of LIC debt sustainability analyses](https://www.imf.org/external/Pubs/ft/dsa/DSAlist.pdf) |
| `data/raw/debt/` | `dataset_<date>_..._IMF.FAD_GDD_2.0.0.csv` | [IMF Global Debt Database](https://data.imf.org/en/datasets/IMF.FAD:GDD): export the dataset as CSV |

These files are not stored here because their publishers' terms differ. When the files match the versions used for the article, the rebuild reproduces the values in `data/analysis/` exactly. `data/raw/raw_files.csv` gives each file's size and MD5 and SHA-256 checksums, and the code warns if a file differs. Several publishers update their files, so a new download may give slightly different numbers; KFF in particular adds agreements as they are signed.

## Built-in checks

The code stops with a message if any of 29 checks fails. For example: 36 unique agreements with terms of three or five years; KFF amounts in the ledger equal the KFF files; WHO's global SPAR average equals 63; 195 countries in the Global Health Security Index and 54 in the Africa index; Pandemic Fund round totals equal the published totals; all 34 countries are drawn in Figure 1. It then checks the 57 numbers in `data/paper_numbers.csv` against the results.

## Excel versions (optional)

`results/Analysis_workbook.xlsx` redoes the main calculations with live Excel formulas, for readers who do not use R; its `R_vs_Excel` sheet compares 45 results with R. `results/Master_dataset.xlsx` holds every dataset with the codebook. To rebuild them after running R, install Python 3 and `pip install pandas openpyxl`, then run `python3 code/build_excel_master.py` and `python3 code/build_excel_analysis.py`.

## Software

Tested with R 4.3.3. Exact package versions are in `renv.lock` (run `renv::restore()` to install them). `results/logs/sessionInfo.txt` records the last run. Figures use the `ragg` package if it is installed and otherwise the standard graphics devices.

## Licence

Code: MIT (`LICENSE`). Data and documentation created by the authors: CC BY 4.0 (`LICENSE-data.md`). Values derived from third-party sources keep their publishers' terms; please cite the original sources.

## How to cite

Please cite the article and this repository (`CITATION.cff`, or the "Cite this repository" button on GitHub).

## Contact

Michael Muhoozi, School of Public Health, Virginia Commonwealth University, muhoozim@vcu.edu. Questions and corrections are welcome as GitHub issues.
