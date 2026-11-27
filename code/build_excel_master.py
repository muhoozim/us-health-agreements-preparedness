"""Optional. Writes results/Master_dataset.xlsx: every analysis dataset in one
documented Excel workbook. Run after run_all.R, from the repository folder:
    python3 code/build_excel_master.py
"""
import pathlib, datetime, sys
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

ROOT = pathlib.Path(__file__).resolve().parents[1]
DER, INP, DOC = ROOT / "data" / "analysis", ROOT / "data" / "curated", ROOT / "data"
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "results" / "Master_dataset.xlsx"

F = "Arial"
HDR_FILL = PatternFill("solid", fgColor="1F3864")
SUB_FILL = PatternFill("solid", fgColor="D9E1F2")
HDR_FONT = Font(name=F, bold=True, color="FFFFFF", size=10)
BODY = Font(name=F, size=10)
BOLD = Font(name=F, size=10, bold=True)
TITLE = Font(name=F, size=14, bold=True)
thin = Side(style="thin", color="BFBFBF")

master = pd.read_csv(DER / "master_country_dataset.csv", low_memory=False)
code = pd.read_csv(DOC / "codebook.csv")
ledger = pd.read_csv(INP / "agreement_ledger.csv")
alts = pd.read_csv(INP / "numerator_alternatives.csv")
sched = pd.read_csv(INP / "signed_annual_schedules.csv")
clauses = pd.read_csv(INP / "agreement_clauses_reviewed.csv")
idxu = pd.read_csv(DER / "index_universes.csv")
src = pd.read_csv(INP / "sources_register.csv")
pf = pd.read_csv(INP / "pandemic_fund_projects.csv")
pfl = pd.read_csv(DER / "pandemic_fund_project_country_long.csv")
pfd = pd.read_csv(INP / "pandemic_fund_country_designations.csv")
ann = pd.read_csv(DER / "kff_annual_us_funding_long.csv")
area = pd.read_csv(DER / "kff_area_of_cooperation_long.csv")
ghed = pd.read_csv(DER / "ghed_panel_2010_2024.csv")
wbapi = pd.read_csv(INP / "worldbank_debt_api_2026-11-23.csv")
wfapi = pd.read_csv(INP / "who_workforce_api_2026-11-23.csv")

sig = master[master.mou_signed == True].copy()
sig = sig.sort_values(["split_published", "pledge_share_pct"], ascending=[False, False])
key_cols = ["iso3", "country", "kff_region", "split_published", "agreement_date", "term_years", "evidence_status",
            "us_funding_usd", "coinvest_usd", "coinvest_share_pct", "coinvest_annual_usd", "partner_currency_documented",
            "pop_2023_thousands", "gghed_usd_m_2023", "gghed_gge_2023", "ext_che_2023", "pledge_share_pct", "pledge_share_5yr_pct",
            "spar_2025", "ghs_overall_2021", "ahs_overall_2026", "quadrant", "screen_group",
            "gghed_usd_cagr_2015_23", "gghed_real_lcu_cagr_2015_23", "max_1y_depreciation_pct", "max_3y_depreciation_pct",
            "pledge_dep20_pct", "screen_group_dep20", "dsf_overall_risk", "dsf_publication", "gdd_gov_debt_gdp",
            "wb_debt_service_gni", "wb_interest_revenue", "hwf_dnm_per10k", "hwf_below_sdg_threshold",
            "pf_status", "pf_single_grant_usd", "pf_cfp4_eligible", "pf_efp_2026"]
analytic = sig[key_cols]

wb = Workbook()

def write_df(ws, df, start_row=1, widths=None, number_formats=None):
    for j, c in enumerate(df.columns, 1):
        cell = ws.cell(row=start_row, column=j, value=c)
        cell.font = HDR_FONT; cell.fill = HDR_FILL
        cell.alignment = Alignment(wrap_text=True, vertical="center")
    for i, row in enumerate(df.itertuples(index=False), start_row + 1):
        for j, v in enumerate(row, 1):
            if isinstance(v, float) and pd.isna(v): v = None
            cell = ws.cell(row=i, column=j, value=v)
            cell.font = BODY
    ws.freeze_panes = ws.cell(row=start_row + 1, column=3 if df.shape[1] > 3 else 1)
    for j, c in enumerate(df.columns, 1):
        w = (widths or {}).get(c, min(max(len(str(c)) + 2, 11), 28))
        ws.column_dimensions[get_column_letter(j)].width = w
        fmt = (number_formats or {}).get(c)
        if fmt:
            for i in range(start_row + 1, start_row + 1 + len(df)):
                ws.cell(row=i, column=j).number_format = fmt
    ws.auto_filter.ref = f"A{start_row}:{get_column_letter(df.shape[1])}{start_row + len(df)}"

# ---- README -------------------------------------------------------------------
ws = wb.active; ws.title = "README"
lines = [
    ("Master dataset: US bilateral health agreements, domestic health spending, preparedness, debt and grants", TITLE),
    ("Companion to: Muhoozi M, Swahn MH. Fixed spending targets and outbreak preparedness in US bilateral health agreements (BMJ Analysis). Release v1.0.0, 24 Nov 2026.", BODY),
    ("", BODY),
    ("What this workbook is", BOLD),
    ("The analysis-ready master data, one row per country, assembled by code/1_build_dataset.R from the raw source files and the curated inputs in data/curated/. Values are exports, not formulas; the formula version of the main results is Analysis_workbook_v5.xlsx.", BODY),
    ("", BODY),
    ("Sheets", BOLD),
    ("Analytic_36  - the 36 agreements (34 with both amounts first, sorted by pledge share), 40 key variables", BODY),
    ("All_countries_195  - every country in the WHO expenditure file with all 125 variables", BODY),
    ("Codebook  - label, unit, source, reference year, derivation and completeness for every variable", BODY),
    ("Agreement_ledger  - term, evidence, amounts, page locators, interpretation and document links for all 36 agreements", BODY),
    ("Numerator_alternatives / Signed_schedules / Clauses_reviewed  - Malawi and Philippine alternatives, signed annual schedules (Uganda, Malawi, Kenya) and clauses reviewed in full text", BODY),
    ("Index_universes  - all 195 GHS 2021 and 54 AHS 2026 scores with agreement status", BODY),
    ("Sources  - source register with citation, version, URL, access date, project file, use and limitations", BODY),
    ("PF_projects / PF_project_country / PF_designations  - Pandemic Fund rounds 1-3 grants (67 projects), project-country links, 2026 targeted call and Ebola emergency financing", BODY),
    ("KFF_annual_US_2021_30 / KFF_area_2026_30  - KFF annual US funding (16 countries) and US funding by area of cooperation (17 countries)", BODY),
    ("GHED_panel_signatories  - WHO GHED 2010-2024 for the 36 signatories (2024 preliminary)", BODY),
    ("WB_debt_API / WHO_workforce_API  - values pulled on 23 Nov 2026 to fill gaps in the curated files (see Sources)", BODY),
    ("", BODY),
    ("Key definitions", BOLD),
    ("Pledge share (pledge_share_pct) = (partner commitment / documented term of 3 or 5 years) / 2023 domestic general government health expenditure (current US$) x 100.", BODY),
    ("Screening group (screen_group) = pledge share >= 10% and SPAR 2025 score below the WHO global average of 63. Groups A-D in quadrant.", BODY),
    ("Percentages are stored as percentage points (for example 27.3 = 27.3%). Monetary values are US$ unless the column name says _m (US$ million).", BODY),
    ("", BODY),
    ("Data gaps found in the curated files and how they were handled", BOLD),
    ("1. Health workforce values were pulled from the WHO GHO API (HWF_0001, HWF_0006).", BODY),
    ("2. The World Bank IDS extract was queried by creditor counterpart, so headline ratios are empty; World Bank WDI debt indicators were pulled from the API for counterpart World.", BODY),
    ("3. Pandemic Fund round 3 amounts are not in the 2024 PDFs; they were transcribed from the Pandemic Fund third-call brief (Feb 2026).", BODY),
    ("", BODY),
    ("Suggested citation", BOLD),
    ("Muhoozi M, Swahn MH. Master dataset (release v1.0.0) for 'Fixed spending targets and outbreak preparedness in US bilateral health agreements'. Virginia Commonwealth University; 24 Nov 2026.", BODY),
]
for i, (t, f) in enumerate(lines, 1):
    c = ws.cell(row=i, column=1, value=t); c.font = f
    c.alignment = Alignment(wrap_text=True, vertical="top")
ws.column_dimensions["A"].width = 150

pctfmt = "0.0"
nf = {c: "#,##0" for c in ["us_funding_usd", "coinvest_usd", "coinvest_annual_usd", "pf_single_grant_usd"]}
nf.update({c: "0.00" for c in ["pledge_share_pct", "pledge_share_5yr_pct", "pledge_dep20_pct"]})
nf.update({c: pctfmt for c in ["coinvest_share_pct", "gghed_gge_2023", "ext_che_2023", "gghed_usd_cagr_2015_23",
                               "gghed_real_lcu_cagr_2015_23", "max_3y_depreciation_pct", "gdd_gov_debt_gdp",
                               "wb_debt_service_gni", "wb_interest_revenue", "hwf_dnm_per10k", "max_1y_depreciation_pct",
                               "gghed_usd_m_2023", "ahs_overall_2026"]})
ws = wb.create_sheet("Analytic_36"); write_df(ws, analytic, number_formats=nf)
ws = wb.create_sheet("All_countries_195"); write_df(ws, master)
ws = wb.create_sheet("Codebook"); write_df(ws, code, widths={"label": 70, "derivation_or_source_field": 60, "variable": 30})
ws = wb.create_sheet("Agreement_ledger"); write_df(ws, ledger, widths={"interpretation": 70, "term_basis": 40, "evidence_locator": 30}, number_formats={"kff_us_usd": "#,##0", "kff_partner_usd": "#,##0", "kff_total_usd": "#,##0"})
ws = wb.create_sheet("Numerator_alternatives"); write_df(ws, alts, widths={"measure_label": 60})
ws = wb.create_sheet("Signed_schedules"); write_df(ws, sched, number_formats={"amount": "#,##0"})
ws = wb.create_sheet("Clauses_reviewed"); write_df(ws, clauses, widths={"finding": 90})
ws = wb.create_sheet("Index_universes"); write_df(ws, idxu)
ws = wb.create_sheet("Sources"); write_df(ws, src, widths={"full_citation": 60, "used_for": 50, "notes_and_limitations": 70, "url": 45})
ws = wb.create_sheet("PF_projects"); write_df(ws, pf, widths={"project_title": 60, "countries_named": 50}, number_formats={"grant_usd": "#,##0", "cofinancing_usd": "#,##0", "coinvestment_usd": "#,##0"})
ws = wb.create_sheet("PF_project_country"); write_df(ws, pfl[["project_id", "round", "project_type", "country", "iso3", "n_named", "grant_usd"]], number_formats={"grant_usd": "#,##0"})
ws = wb.create_sheet("PF_designations"); write_df(ws, pfd, widths={"note": 60})
annw = ann.pivot(index="iso3", columns="year", values="us_funding_usd").reset_index()
annw.columns = [str(c) for c in annw.columns]
annw = master[["iso3", "country"]].merge(annw, on="iso3")
ws = wb.create_sheet("KFF_annual_US_2021_30"); write_df(ws, annw, number_formats={str(y): "#,##0" for y in range(2021, 2031)})
area2 = master[["iso3", "country"]].merge(area, on="iso3")
ws = wb.create_sheet("KFF_area_2026_30"); write_df(ws, area2, number_formats={"us_funding_usd": "#,##0"})
gp = ghed[ghed.iso3.isin(sig.iso3) & (ghed.year >= 2010)]
ws = wb.create_sheet("GHED_panel_signatories"); write_df(ws, gp)
ws = wb.create_sheet("WB_debt_API"); write_df(ws, wbapi)
ws = wb.create_sheet("WHO_workforce_API"); write_df(ws, wfapi)

OUT.parent.mkdir(parents=True, exist_ok=True); wb.save(OUT)
print("wrote", OUT, "sheets:", wb.sheetnames)
