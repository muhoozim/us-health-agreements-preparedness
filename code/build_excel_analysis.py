"""Optional. Writes results/Analysis_workbook.xlsx: the main calculations redone
with live Excel formulas, for readers who do not use R. Inputs (blue) are the
34-country data and the assumptions; everything else is a formula. The last
sheet compares each Excel result with the R result (results/results.json).
Run after run_all.R, from the repository folder:
    python3 code/build_excel_analysis.py
Excel calculates the formulas when the file is opened.
"""
import json, pathlib
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter
from openpyxl.comments import Comment
from openpyxl.chart import ScatterChart, Reference, Series
from openpyxl.chart.marker import Marker

ROOT = pathlib.Path(__file__).resolve().parents[1]
import sys
OUTX = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "results" / "Analysis_workbook.xlsx"
m = pd.read_csv(ROOT / "data" / "analysis" / "master_country_dataset.csv", low_memory=False)
hs = pd.read_csv(ROOT / "results" / "tables" / "eTable_us_outbreak_functions_by_country.csv")
R = json.load(open(ROOT / "results" / "results.json"))
d = m[m.split_published == True].copy().sort_values("pledge_share_pct", ascending=False).reset_index(drop=True)
d = d.merge(hs[["iso3", "hs_2026", "hs_2030"]], on="iso3", how="left")
N = len(d); assert N == 34
first, last = 2, N + 1

F = "Arial"
BLUE = Font(name=F, size=10, color="0000FF")
BLACK = Font(name=F, size=10, color="000000")
GREEN = Font(name=F, size=10, color="008000")
BOLD = Font(name=F, size=10, bold=True)
HDR = Font(name=F, size=10, bold=True, color="FFFFFF")
HFILL = PatternFill("solid", fgColor="1F3864")
YELLOW = PatternFill("solid", fgColor="FFFF00")
TITLE = Font(name=F, size=13, bold=True)

wb = Workbook()
# ---- README ---------------------------------------------------------------------
ws = wb.active; ws.title = "README"
txt = [
    ("Analysis workbook - Excel replication of the main R results", TITLE),
    ("Fixed spending targets and outbreak preparedness in US bilateral health agreements (BMJ Analysis; release v1.0.0). The pledge share is called exposure in column names.", BLACK),
    ("", BLACK),
    ("Colour legend", BOLD),
    ("Blue text = hard-coded inputs (source data or assumptions). Black text = formulas. Green text = links to another sheet. Yellow fill = key assumptions you can change.", BLACK),
    ("", BLACK),
    ("How to use", BOLD),
    ("1. Change any yellow cell on 'Inputs' (for example the 10% cut-off or the 20% currency fall), or a blue term or amount on 'Data' (for example Malawi's amount: 143.8, 55 or 313.6); every result recalculates.", BLACK),
    ("2. 'Data' holds the 34-country inputs exported from the R master dataset (values; sources in Master_dataset.xlsx, sheet Sources).", BLACK),
    ("3. 'Calc' derives exposure, flags, scenarios and ranks country by country.", BLACK),
    ("4. 'Summary' reproduces every number in the manuscript; 'Sensitivity' reproduces the threshold-by-measure grid; 'Chart' plots Figure 1 natively.", BLACK),
    ("5. 'R_vs_Excel' compares each Excel result with the R output (results/results.json). At default inputs every row should read MATCH.", BLACK),
    ("", BLACK),
    ("Conventions", BOLD),
    ("Percentages are stored as fractions and formatted as %. Money in US$ million unless labelled. Spearman correlations are Pearson correlations of average ranks (ties share the mean rank), which equals Spearman's rho.", BLACK),
    ("Example of an input row: Data row 2 = Tanzania, term 5 years, partner commitment US$1800m, 2023 domestic government health spending US$765.0m, SPAR 66. Results not reproduced here (bootstrap intervals, figures, index-status comparisons) come from R only.", BLACK),
]
for i, (t, f) in enumerate(txt, 1):
    c = ws.cell(row=i, column=1, value=t); c.font = f; c.alignment = Alignment(wrap_text=True)
ws.column_dimensions["A"].width = 140

# ---- Inputs ---------------------------------------------------------------------
wi = wb.create_sheet("Inputs")
wi["A1"] = "Assumptions and reference values"; wi["A1"].font = TITLE
inputs = [
    ("(Agreement terms are on Data, column Term)", 0, "0", "Four agreements run for three years; see the agreement ledger."),
    ("Pledge share cut-off (share of 2023 domestic government health spending)", 0.10, "0%", "Main cut-off, a round analytical choice; 5-20% on 'Sensitivity'."),
    ("SPAR global average, 2025", 63, "0", "WHO e-SPAR 2025 file, row 'AVG Global Capacity' (updated 12 Nov 2026)."),
    ("Currency fall scenario", 0.20, "0%", "13 of 34 currencies lost >=20% over a three-year interval, 2015-23 (WHO GHED annual average exchange rates)."),
    ("(not used)", 0, "0", "Version 4 projection to 2028 removed."),
    ("Health workforce threshold (doctors + nurses/midwives per 10 000)", 44.5, "0.0", "WHO SDG index threshold."),
    ("External dependence threshold (external share of CHE)", 0.25, "0%", "Descriptive flag used in supplement."),
    ("Pandemic Fund grant period, years", 3, "0", "Typical project duration; used to annualise grants."),
    ("GHS Index 2021 median (195 countries)", R["preparedness"]["ghs_median_195"], "0.00", "Computed in R in the index's own 195-country population (results.json)."),
    ("AHS Index 2026 median (54 countries)", R["preparedness"]["ahs_median_54"], "0.00", "Computed in R from all 54 African countries (results.json)."),
    ("(not used)", 0, "0", "SPAR detection-core measure not used."),
]
wi["A3"], wi["B3"], wi["C3"] = "Parameter", "Value", "Source or rationale"
for c in ("A3", "B3", "C3"): wi[c].font = HDR; wi[c].fill = HFILL
for i, (lab, val, fmt, note) in enumerate(inputs, 4):
    wi.cell(row=i, column=1, value=lab).font = BLACK
    c = wi.cell(row=i, column=2, value=val); c.font = BLUE; c.fill = YELLOW; c.number_format = fmt
    wi.cell(row=i, column=3, value=note).font = BLACK
wi.column_dimensions["A"].width = 62; wi.column_dimensions["B"].width = 12; wi.column_dimensions["C"].width = 95
IN = {k: f"Inputs!$B${i}" for i, k in enumerate(["years", "thr", "spar", "dep", "horizon", "hrh", "ext", "pfyears", "ghsmed", "ahsmed", "spcore"], 4)}

# ---- Data -----------------------------------------------------------------------
wd = wb.create_sheet("Data")
def pct(x): return None if pd.isna(x) else float(x) / 100
def num(x, s=1.0): return None if pd.isna(x) else float(x) * s
cols = [
    ("ISO3", lambda r: r.iso3, "@"), ("Country", lambda r: r.country, "@"), ("Region (KFF)", lambda r: r.kff_region, "@"),
    ("Term (years)", lambda r: int(r.term_years), "0"),
    ("US funding 2026-30 (US$m)", lambda r: num(r.us_funding_usd, 1e-6), "#,##0.0"),
    ("Co-investment 2026-30 (US$m)", lambda r: num(r.coinvest_usd, 1e-6), "#,##0.0"),
    ("GGHE-D 2023 (US$m)", lambda r: num(r.gghed_usd_m_2023), "#,##0.0"),
    ("GGE 2023 (US$m)", lambda r: num(r.gge_usd_m_2023), "#,##0"),
    ("GDP 2023 (US$m)", lambda r: num(r.gdp_usd_m_2023), "#,##0"),
    ("Population 2023 (thousands)", lambda r: num(r.pop_2023_thousands), "#,##0"),
    ("SPAR 2025", lambda r: num(r.spar_2025), "0"),
    ("Evidence (signed text = 1)", lambda r: int(r.evidence_status == "Signed text"), "0"),
    ("GHS Index 2021", lambda r: num(r.ghs_overall_2021), "0.0"),
    ("AHS Index 2026", lambda r: num(r.ahs_overall_2026), "0.00"),
    ("External share of CHE 2023", lambda r: pct(r.ext_che_2023), "0.0%"),
    ("GGHE-D share of GGE 2023", lambda r: pct(r.gghed_gge_2023), "0.0%"),
    ("GGHE-D growth 2015-23, current US$ (per year)", lambda r: pct(r.gghed_usd_cagr_2015_23), "0.0%"),
    ("GGHE-D growth 2015-23, constant local currency (per year)", lambda r: pct(r.gghed_real_lcu_cagr_2015_23), "0.0%"),
    ("Largest 3-year depreciation 2015-23", lambda r: pct(r.max_3y_depreciation_pct), "0.0%"),
    ("Pledge in US$ (1) or local currency (0)", lambda r: int(bool(r.usd_pledge_assumed)), "0"),
    ("LIC-DSF overall risk", lambda r: None if pd.isna(r.dsf_overall_risk) else r.dsf_overall_risk, "@"),
    ("External debt service (% GNI)", lambda r: pct(r.wb_debt_service_gni), "0.0%"),
    ("Interest payments (% revenue)", lambda r: pct(r.wb_interest_revenue), "0.0%"),
    ("Doctors + nurses/midwives per 10 000", lambda r: num(r.hwf_dnm_per10k), "0.0"),
    ("Pandemic Fund single-country grants (US$m)", lambda r: num(r.pf_single_grant_usd, 1e-6), "#,##0.00"),
    ("Pandemic Fund multi-country/regional grants naming country (n)", lambda r: int(r.pf_named_multi_regional_n), "0"),
    ("Eligible for 2026 targeted call (1/0)", lambda r: int(bool(r.pf_cfp4_eligible)), "0"),
    ("US funding for surveillance, labs, workforce, data 2026 (US$m)", lambda r: num(r.hs_2026, 1e-6), "#,##0.0"),
    ("Same, 2030 (US$m)", lambda r: num(r.hs_2030, 1e-6), "#,##0.0"),
    ("Five-year agreement in area budgets (1/0)", lambda r: int(r.term_years == 5), "0"),
]
for j, (h, _, _) in enumerate(cols, 1):
    c = wd.cell(row=1, column=j, value=h); c.font = HDR; c.fill = HFILL; c.alignment = Alignment(wrap_text=True, vertical="center")
    wd.column_dimensions[get_column_letter(j)].width = 14 if j > 3 else (24 if j == 2 else 8)
for i, r in enumerate(d.itertuples(index=False), first):
    for j, (_, f, fmt) in enumerate(cols, 1):
        c = wd.cell(row=i, column=j, value=f(r)); c.font = BLUE; c.number_format = fmt
wd.row_dimensions[1].height = 75; wd.freeze_panes = "C2"
src_note = f"Sources: KFF tracker (8 Oct 2026); WHO GHED (Dec 2025); WHO e-SPAR 2025; GHS Index 2021; AHS Index 2026; IMF-World Bank LIC-DSF; World Bank WDI API (23 Nov 2026); WHO NHWA via GHO API (23 Nov 2026); Pandemic Fund documents. Full register: Master_dataset.xlsx, sheet Sources."
wd.cell(row=last + 2, column=1, value=src_note).font = Font(name=F, size=9, italic=True)
COL = {h: get_column_letter(j) for j, (h, _, _) in enumerate(cols, 1)}
def D(h, r): return f"Data!{COL[h]}{r}"
def DR(h): return f"Data!${COL[h]}${first}:${COL[h]}${last}"

# ---- Calc -----------------------------------------------------------------------
wc = wb.create_sheet("Calc")
calc = [
    ("ISO3", lambda r: f"={D('ISO3', r)}", "@", GREEN),
    ("Country", lambda r: f"={D('Country', r)}", "@", GREEN),
    ("Annual co-investment pledge (US$m)", lambda r: f"={D('Co-investment 2026-30 (US$m)', r)}/{D('Term (years)', r)}", "#,##0.0", BLACK),
    ("Exposure: pledge / GGHE-D 2023", lambda r: f"=C{r}/{D('GGHE-D 2023 (US$m)', r)}", "0.00%", BLACK),
    ("Pledge / GGE 2023", lambda r: f"=C{r}/{D('GGE 2023 (US$m)', r)}", "0.00%", BLACK),
    ("Pledge / GDP 2023", lambda r: f"=C{r}/{D('GDP 2023 (US$m)', r)}", "0.000%", BLACK),
    ("High exposure (1/0)", lambda r: f"=IF(D{r}>={IN['thr']},1,0)", "0", BLACK),
    ("SPAR below global average (1/0)", lambda r: f"=IF({D('SPAR 2025', r)}<{IN['spar']},1,0)", "0", BLACK),
    ("Both risks (1/0)", lambda r: f"=G{r}*H{r}", "0", BLACK),
    ("Quadrant", lambda r: f'=IF(G{r}=1,IF(H{r}=1,"A","B"),IF(H{r}=1,"C","D"))', "@", BLACK),
    ("Exposure after depreciation", lambda r: f"=IF({D('Pledge in US$ (1) or local currency (0)', r)}=1,D{r}/(1-{IN['dep']}),D{r})", "0.00%", BLACK),
    ("Both risks after depreciation (1/0)", lambda r: f"=IF(AND(K{r}>={IN['thr']},H{r}=1),1,0)", "0", BLACK),
    ("Enters group under depreciation (1/0)", lambda r: f"=IF(AND(L{r}=1,I{r}=0),1,0)", "0", BLACK),
    ("Signed-text amount (1/0)", lambda r: f'={D("Evidence (signed text = 1)", r)}', "0", GREEN),
    ("Group A among signed-text amounts (1/0)", lambda r: f"=I{r}*N{r}", "0", BLACK),
    ("GGHE-D shrank in US$ 2015-23 (1/0)", lambda r: f'=IF({D("GGHE-D growth 2015-23, current US$ (per year)", r)}="","",IF({D("GGHE-D growth 2015-23, current US$ (per year)", r)}<0,1,0))', "0", BLACK),
    ("GGHE-D shrank in constant local currency (1/0)", lambda r: f'=IF({D("GGHE-D growth 2015-23, constant local currency (per year)", r)}="","",IF({D("GGHE-D growth 2015-23, constant local currency (per year)", r)}<0,1,0))', "0", BLACK),
    ("Depreciation >= scenario within 3 years (1/0)", lambda r: f'=IF({D("Largest 3-year depreciation 2015-23", r)}="","",IF({D("Largest 3-year depreciation 2015-23", r)}>={IN["dep"]},1,0))', "0", BLACK),
    ("Debt risk high or in distress (1/0)", lambda r: f'=IF(OR({D("LIC-DSF overall risk", r)}="High",{D("LIC-DSF overall risk", r)}="In debt distress"),1,0)', "0", BLACK),
    ("External share >= threshold (1/0)", lambda r: f"=IF({D('External share of CHE 2023', r)}>={IN['ext']},1,0)", "0", BLACK),
    ("Workforce below threshold (1/0)", lambda r: f"=IF({D('Doctors + nurses/midwives per 10 000', r)}<{IN['hrh']},1,0)", "0", BLACK),
    ("No Pandemic Fund single-country grant (1/0)", lambda r: f"=IF({D('Pandemic Fund single-country grants (US$m)', r)}=0,1,0)", "0", BLACK),
    ("Number of risk flags (of 6)", lambda r: f"=G{r}+H{r}+S{r}+T{r}+U{r}+V{r}", "0", BLACK),
    ("Pandemic Fund grant per year / annual pledge", lambda r: f"=({D('Pandemic Fund single-country grants (US$m)', r)}/{IN['pfyears']})/C{r}", "0.0%", BLACK),
    ("Fall in US health-security funding 2026-30 (US$m)", lambda r: f'=IF({D("US funding for surveillance, labs, workforce, data 2026 (US$m)", r)}="","",{D("US funding for surveillance, labs, workforce, data 2026 (US$m)", r)}-{D("Same, 2030 (US$m)", r)})', "#,##0.0", BLACK),
    ("Same, as share of GGHE-D 2023", lambda r: f'=IF(Y{r}="","",Y{r}/{D("GGHE-D 2023 (US$m)", r)})', "0.0%", BLACK),
    ("Rank: exposure (average ranks)", lambda r: f"=RANK(D{r},$D${first}:$D${last},1)+(COUNTIF($D${first}:$D${last},D{r})-1)/2", "0.0", BLACK),
    ("Rank: SPAR", lambda r: f"=RANK({D('SPAR 2025', r)},{DR('SPAR 2025')},1)+(COUNTIF({DR('SPAR 2025')},{D('SPAR 2025', r)})-1)/2", "0.0", BLACK),
    ("Rank: external share", lambda r: f"=RANK({D('External share of CHE 2023', r)},{DR('External share of CHE 2023')},1)+(COUNTIF({DR('External share of CHE 2023')},{D('External share of CHE 2023', r)})-1)/2", "0.0", BLACK),
    ("Rank: GHS 2021", lambda r: f"=RANK({D('GHS Index 2021', r)},{DR('GHS Index 2021')},1)+(COUNTIF({DR('GHS Index 2021')},{D('GHS Index 2021', r)})-1)/2", "0.0", BLACK),
    ("Group A: external share", lambda r: f'=IF(I{r}=1,{D("External share of CHE 2023", r)},"")', "0.0%", BLACK),
    ("Group A: GGHE-D share of GGE", lambda r: f'=IF(I{r}=1,{D("GGHE-D share of GGE 2023", r)},"")', "0.0%", BLACK),
    ("Group A: workforce density", lambda r: f'=IF(I{r}=1,{D("Doctors + nurses/midwives per 10 000", r)},"")', "0.0", BLACK),
    ("GHS 2021 below global median (1/0)", lambda r: f"=IF({D('GHS Index 2021', r)}<{IN['ghsmed']},1,0)", "0", BLACK),
    ("AHS 2026 below African median (1/0; blank outside Africa)", lambda r: f'=IF({D("AHS Index 2026", r)}="","",IF({D("AHS Index 2026", r)}<{IN["ahsmed"]},1,0))', "0", BLACK),
    ("Five-year area budget, 2026 (US$m)", lambda r: f'=IF(OR({D("US funding for surveillance, labs, workforce, data 2026 (US$m)", r)}="",{D("Five-year agreement in area budgets (1/0)", r)}=0),"",{D("US funding for surveillance, labs, workforce, data 2026 (US$m)", r)})', "#,##0.0", BLACK),
    ("Preparedness measures below reference (of 2-3)", lambda r: f'=H{r}+AH{r}+IF(AI{r}="",0,AI{r})', "0", BLACK),
    ("Robust core: high exposure and >=2 measures below (1/0)", lambda r: f"=IF(AND(G{r}=1,AK{r}>=2),1,0)", "0", BLACK),
    ("Name if group A", lambda r: f'=IF(I{r}=1,B{r},"")', "@", BLACK),
    ("Name if enters under depreciation", lambda r: f'=IF(M{r}=1,B{r},"")', "@", BLACK),
    ("Name if robust core", lambda r: f'=IF(AL{r}=1,B{r},"")', "@", BLACK),
    ("Name if group A without Pandemic Fund single grant", lambda r: f'=IF(AND(I{r}=1,V{r}=1),B{r},"")', "@", BLACK),
    ("Name if exposure >=10% and debt risk high/distress", lambda r: f'=IF(AND(G{r}=1,S{r}=1),B{r},"")', "@", BLACK),
]
for j, (h, _, _, _) in enumerate(calc, 1):
    c = wc.cell(row=1, column=j, value=h); c.font = HDR; c.fill = HFILL; c.alignment = Alignment(wrap_text=True, vertical="center")
    wc.column_dimensions[get_column_letter(j)].width = 13 if j > 2 else (8 if j == 1 else 24)
for r in range(first, last + 1):
    for j, (_, f, fmt, font) in enumerate(calc, 1):
        c = wc.cell(row=r, column=j, value=f(r)); c.number_format = fmt; c.font = font
wc.row_dimensions[1].height = 90; wc.freeze_panes = "C2"
CC = {h: get_column_letter(j) for j, (h, _, _, _) in enumerate(calc, 1)}
assert CC["Exposure: pledge / GGHE-D 2023"] == "D" and CC["Both risks (1/0)"] == "I" and CC["Fall in US health-security funding 2026-30 (US$m)"] == "Y"
assert CC["GHS 2021 below global median (1/0)"] == "AH" and CC["Preparedness measures below reference (of 2-3)"] == "AK"
def CRng(col): return f"Calc!${col}${first}:${col}${last}"

# ---- Summary --------------------------------------------------------------------
wsu = wb.create_sheet("Summary")
wsu["A1"] = "Key results (all formulas)"; wsu["A1"].font = TITLE
rows = [
    ("Agreement portfolio", None, None, None),
    ("Countries with published split", f"=COUNTA({DR('ISO3')})", "0", "n_split"),
    ("US funding, 34 countries (US$bn)", f"=SUM({DR('US funding 2026-30 (US$m)')})/1000", "0.00", "us_bn"),
    ("Co-investment, 34 countries (US$bn)", f"=SUM({DR('Co-investment 2026-30 (US$m)')})/1000", "0.00", "co_bn"),
    ("Co-investment share of total", "=@@co_bn@@/(@@us_bn@@+@@co_bn@@)", "0.0%", "co_share"),
    ("Fiscal exposure", None, None, None),
    ("Median exposure", f"=MEDIAN({CRng('D')})", "0.00%", "exp_median"),
    ("Lower quartile", f"=QUARTILE({CRng('D')},1)", "0.00%", "exp_q1"),
    ("Upper quartile", f"=QUARTILE({CRng('D')},3)", "0.00%", "exp_q3"),
    ("Maximum exposure", f"=MAX({CRng('D')})", "0.00%", "exp_max"),
    ("Country with maximum exposure", f"=INDEX({CRng('B')},MATCH(@@exp_max@@,{CRng('D')},0))", "@", None),
    ("Countries with exposure >= 5%", f'=COUNTIF({CRng("D")},">="&0.05)', "0", "n_ge5"),
    ("Countries with pledge share >= cut-off", f'=COUNTIF({CRng("D")},">="&{IN["thr"]})', "0", "n_ge10"),
    ("Countries with exposure >= 20%", f'=COUNTIF({CRng("D")},">="&0.2)', "0", "n_ge20"),
    ("Preparedness", None, None, None),
    ("SPAR below global average", f'=COUNTIF({DR("SPAR 2025")},"<"&{IN["spar"]})', "0", "n_below_63"),
    ("SPAR below 50", f'=COUNTIF({DR("SPAR 2025")},"<"&50)', "0", "n_below_50"),
    ("Spearman rho: exposure vs SPAR", f"=CORREL({CRng('AA')},{CRng('AB')})", "0.000", "rho_exp_spar"),
    ("Spearman rho: exposure vs GHS 2021", f"=CORREL({CRng('AA')},{CRng('AD')})", "0.000", "rho_exp_ghs"),
    ("Spearman rho: exposure vs external share", f"=CORREL({CRng('AA')},{CRng('AC')})", "0.000", "rho_exp_ext"),
    ("High-risk group (exposure >= threshold and SPAR below average)", None, None, None),
    ("Countries in group A", f"=SUM({CRng('I')})", "0", "groupA_n"),
    ("Countries", f'=_xlfn.TEXTJOIN("; ",TRUE,{CRng("AM")})', "@", None),
    ("US funding to group A (US$bn)", f"=SUMIF({CRng('I')},1,{DR('US funding 2026-30 (US$m)')})/1000", "0.00", "groupA_us_bn"),
    ("Co-investment pledged by group A (US$bn)", f"=SUMIF({CRng('I')},1,{DR('Co-investment 2026-30 (US$m)')})/1000", "0.00", "groupA_co_bn"),
    ("Population of group A (millions)", f"=SUMIF({CRng('I')},1,{DR('Population 2023 (thousands)')})/1000", "0.0", "groupA_pop"),
    ("Median external share, group A", f"=MEDIAN({CRng('AE')})", "0.0%", "groupA_ext"),
    ("Median GGHE-D share of GGE, group A", f"=MEDIAN({CRng('AF')})", "0.0%", "groupA_gge"),
    ("Group A members whose amount matches a signed text", f"=SUM({CRng('O')})", "0", "groupA_signed"),
    ("Country types", None, None, None),
    ("A: high exposure, below-average preparedness", f'=COUNTIF({CRng("J")},"A")', "0", "qA"),
    ("B: high exposure, above-average preparedness", f'=COUNTIF({CRng("J")},"B")', "0", "qB"),
    ("C: lower exposure, below-average preparedness", f'=COUNTIF({CRng("J")},"C")', "0", "qC"),
    ("D: lower exposure, above-average preparedness", f'=COUNTIF({CRng("J")},"D")', "0", "qD"),
    ("Robust core (>= threshold and below on >= 2 of SPAR, GHS, AHS)", f'=_xlfn.TEXTJOIN("; ",TRUE,{CRng("AO")})', "@", None),
    ("Spending trends and currency", None, None, None),
    ("Median GGHE-D growth 2015-23, current US$", f"=MEDIAN({DR('GGHE-D growth 2015-23, current US$ (per year)')})", "0.0%", "usd_cagr_median"),
    ("Median GGHE-D growth 2015-23, constant local currency", f"=MEDIAN({DR('GGHE-D growth 2015-23, constant local currency (per year)')})", "0.0%", "real_cagr_median"),
    ("Countries where GGHE-D shrank in US$", f"=SUM({CRng('P')})", "0", "n_usd_shrink"),
    ("Countries where GGHE-D shrank in constant local currency", f"=SUM({CRng('Q')})", "0", "n_real_shrink"),
    ("Countries whose currency lost >= scenario value within 3 years", f"=SUM({CRng('R')})", "0", "n_dep20_any_3y"),
    ("Group size after depreciation scenario", f"=SUM({CRng('L')})", "0", "n_dep20_group"),
    ("Countries entering under the scenario", f'=_xlfn.TEXTJOIN("; ",TRUE,{CRng("AN")})', "@", None),
    ("Debt", None, None, None),
    ("Signatories at high risk of or in debt distress", f"=SUM({CRng('S')})", "0", "n_high_or_distress"),
    ("Group A members at high risk of or in debt distress", f"=SUMPRODUCT({CRng('I')},{CRng('S')})", "0", "groupA_debt"),
    ("Exposure >= threshold and debt risk high/distress", f'=_xlfn.TEXTJOIN("; ",TRUE,{CRng("AQ")})', "@", None),
    ("Pandemic Fund and workforce", None, None, None),
    ("Signatories with a Pandemic Fund single-country grant", f'=COUNTIF({DR("Pandemic Fund single-country grants (US$m)")},">0")', "0", "pf_n_single"),
    ("Group A members without a single-country grant", f"=SUMPRODUCT({CRng('I')},{CRng('V')})", "0", "pf_groupA_no_single"),
    ("Names", f'=_xlfn.TEXTJOIN("; ",TRUE,{CRng("AP")})', "@", None),
    ("Pandemic Fund single-country grants to 34 signatories (US$m, rounds 1-3)", f"=SUM({DR('Pandemic Fund single-country grants (US$m)')})", "#,##0.0", "pf_total"),
    ("Annual co-investment pledged by 34 signatories (US$m)", f"=SUM({CRng('C')})", "#,##0.0", "co_annual_total"),
    ("Signatories below workforce threshold", f"=SUM({CRng('U')})", "0", "hwf_below"),
    ("US funding for health-security functions", None, None, None),
    ("2026 total, 16 five-year agreements (US$m)", f"=SUM({CRng('AJ')})", "#,##0.0", "hs5_2026"),
    ("2030 total, 16 five-year agreements (US$m)", f"=SUMIF({DR('Five-year agreement in area budgets (1/0)')},1,{DR('Same, 2030 (US$m)')})", "#,##0.0", "hs5_2030"),
    ("Change 2026 to 2030, 16 five-year agreements", "=@@hs5_2030@@/@@hs5_2026@@-1", "0.0%", "hs5_change"),
    ("2026 total, 17 agreements with area budgets (US$m)", f"=SUM({DR('US funding for surveillance, labs, workforce, data 2026 (US$m)')})", "#,##0.0", "hs2026"),
    ("2030 total (US$m)", f"=SUM({DR('Same, 2030 (US$m)')})", "#,##0.0", "hs2030"),
    ("Change 2026 to 2030", "=@@hs2030@@/@@hs2026@@-1", "0.0%", "hs_change"),
    ("Largest fall as share of GGHE-D", f"=MAX({CRng('Z')})", "0.0%", "hs_max"),
    ("Country", f"=INDEX({CRng('B')},MATCH(@@hs_max@@,{CRng('Z')},0))", "@", None),
]
wsu["A2"], wsu["B2"] = "Result", "Value"
for c in ("A2", "B2"): wsu[c].font = HDR; wsu[c].fill = HFILL
keymap = {}; local = {}
for i, (lab, f, fmt, key) in enumerate(rows, 3):
    if key: keymap[key] = f"Summary!B{i}"; local[key] = f"B{i}"
import re as _re
for i, (lab, f, fmt, key) in enumerate(rows, 3):
    a = wsu.cell(row=i, column=1, value=lab)
    if f is None:
        a.font = BOLD; continue
    a.font = BLACK
    f = _re.sub(r"@@(\w+)@@", lambda mm: local[mm.group(1)], f)
    c = wsu.cell(row=i, column=2, value=f); c.number_format = fmt; c.font = BLACK
wsu.column_dimensions["A"].width = 70; wsu.column_dimensions["B"].width = 60
# sanity on hard-wired row references used inside formulas
# fix: MIN over group A uses an array; replace with AGGREGATE-free robust form


# ---- Sensitivity ----------------------------------------------------------------
wse = wb.create_sheet("Sensitivity")
wse["A1"] = "Countries meeting both criteria, by exposure threshold and preparedness measure"; wse["A1"].font = TITLE
wse["A3"] = "Preparedness measure \\ exposure threshold"; wse["A3"].font = HDR; wse["A3"].fill = HFILL
thr = [0.05, 0.10, 0.15, 0.20]
for j, t in enumerate(thr, 2):
    c = wse.cell(row=3, column=j, value=t); c.font = BLUE; c.fill = YELLOW; c.number_format = "0%"
defs = [
    ("SPAR 2025 below WHO global average (63)", "H"), ("GHS Index 2021 below index median (195 countries)", "AH"),
    ("AHS Index 2026 below index median (54 countries)", "AI"),
]
D_ = CRng("D")
for i, (lab, col) in enumerate(defs, 4):
    wse.cell(row=i, column=1, value=lab).font = BLACK
    for j in range(2, 6):
        L = get_column_letter(j)
        c = wse.cell(row=i, column=j, value=f"=SUMPRODUCT(({D_}>={L}$3)*({CRng(col)}=1))"); c.font = BLACK
i = 7
wse.cell(row=i, column=1, value="Below reference on any of SPAR, GHS, AHS").font = BLACK
for j in range(2, 6):
    L = get_column_letter(j)
    wse.cell(row=i, column=j, value=f"=SUMPRODUCT(({D_}>={L}$3)*((({CRng('H')}=1)+({CRng('AH')}=1)+({CRng('AI')}=1))>0))").font = BLACK
wse.column_dimensions["A"].width = 48
wse["A10"] = "Thresholds in row 3 are editable. R equivalent: results/tables/eTable_threshold_grid.csv."; wse["A10"].font = Font(name=F, size=9, italic=True)

# ---- Chart (Figure 1 natively) -------------------------------------------------------
wch = wb.create_sheet("Chart")
wch["A1"] = "Figure 1 data (linked)"; wch["A1"].font = BOLD
wch["A2"], wch["B2"], wch["C2"] = "Country", "Pledge share (%)", "SPAR 2025"
for r in range(first, last + 1):
    rr = r + 1
    wch.cell(row=rr, column=1, value=f"=Calc!B{r}").font = GREEN
    c = wch.cell(row=rr, column=2, value=f"=Calc!D{r}*100"); c.font = GREEN; c.number_format = "0.00"
    wch.cell(row=rr, column=3, value=f"={D('SPAR 2025', r)}").font = GREEN
ch = ScatterChart(); ch.title = "Pledge share and SPAR 2025 (34 agreements)"
ch.style = 13; ch.x_axis.title = "Average annual partner commitment, % of 2023 domestic government health spending (log)"; ch.y_axis.title = "SPAR 2025"
ch.x_axis.scaling.logBase = 10; ch.x_axis.scaling.min = 0.01; ch.x_axis.scaling.max = 100
ch.y_axis.scaling.min = 20; ch.y_axis.scaling.max = 85
xs = Reference(wch, min_col=2, min_row=3, max_row=last + 1); ys = Reference(wch, min_col=3, min_row=3, max_row=last + 1)
s = Series(ys, xs, title="Signatory"); s.marker = Marker(symbol="circle", size=7); s.graphicalProperties.line.noFill = True
ch.series.append(s)
ch.roundedCorners = False; ch.legend = None
ch.x_axis.delete = False; ch.y_axis.delete = False
ch.title.overlay = False; ch.x_axis.title.overlay = False; ch.y_axis.title.overlay = False
ch.width = 22; ch.height = 13
wch.add_chart(ch, "E2")

# ---- R vs Excel ------------------------------------------------------------------
wr = wb.create_sheet("R_vs_Excel")
wr["A1"] = "Cross-validation: Excel formulas against R results (results/results.json)"; wr["A1"].font = TITLE
hdrs = ["Result", "R value", "Excel value", "Difference", "Check"]
for j, h in enumerate(hdrs, 1):
    c = wr.cell(row=2, column=j, value=h); c.font = HDR; c.fill = HFILL
P, Pl, G, Pr, T, Cu, De, Pf, W, U, Q = (R["portfolio"], R["pledge"], R["group"], R["preparedness"], R["trends"],
                                       R["currency"], R["debt"], R["pandemic_fund"], R["workforce"], R["us_functions"], R["quadrants"])
checks = [
    ("US funding, 34 (US$bn)", P["us_34_usd_bn"], "us_bn"),
    ("Partner commitments, 34 (US$bn)", P["partner_34_usd_bn"], "co_bn"),
    ("Partner share of total", P["partner_share_34_pct"] / 100, "co_share"),
    ("Median pledge share", Pl["median"] / 100, "exp_median"), ("Lower quartile", Pl["q1"] / 100, "exp_q1"),
    ("Upper quartile", Pl["q3"] / 100, "exp_q3"), ("Maximum pledge share", Pl["max"] / 100, "exp_max"),
    ("n pledge share >= 5%", Pl["n_ge5"], "n_ge5"), ("n pledge share >= 10%", Pl["n_ge10"], "n_ge10"), ("n pledge share >= 20%", Pl["n_ge20"], "n_ge20"),
    ("n SPAR < 63", Pr["n_below_63"], "n_below_63"), ("n SPAR < 50", Pr["n_below_50"], "n_below_50"),
    ("Spearman pledge share vs SPAR", R["cor"]["pledge_spar"]["rho"], "rho_exp_spar"),
    ("Spearman pledge share vs GHS 2021", R["cor"]["pledge_ghs"]["rho"], "rho_exp_ghs"),
    ("Spearman pledge share vs external share", R["cor"]["pledge_ext"]["rho"], "rho_exp_ext"),
    ("Group A n", G["n"], "groupA_n"), ("Group A US funding (US$bn)", G["us_usd_bn"], "groupA_us_bn"),
    ("Group A partner commitments (US$bn)", G["partner_usd_bn"], "groupA_co_bn"), ("Group A population (m)", G["pop_m"], "groupA_pop"),
    ("Group A median external share", G["ext_che_median"] / 100, "groupA_ext"), ("Group A median health share of government spending", G["gghed_gge_median"] / 100, "groupA_gge"),
    ("Group A with signed-text amounts", R["scenarios"]["signed_only"]["n_group"], "groupA_signed"),
    ("Type A", Q["A"], "qA"), ("Type B", Q["B"], "qB"), ("Type C", Q["C"], "qC"), ("Type D", Q["D"], "qD"),
    ("Median spending growth, US$", T["usd_cagr_median"] / 100, "usd_cagr_median"), ("Median spending growth, constant local currency", T["real_cagr_median"] / 100, "real_cagr_median"),
    ("n fell in US$", len(T["usd_decline"]), "n_usd_shrink"), ("n fell in constant local currency", len(T["real_decline"]), "n_real_shrink"),
    ("n currency lost >= 20% over 3 years", Cu["n_dep3y_ge20"], "n_dep20_any_3y"), ("Group size after 20% fall", Cu["n_dep20"], "n_dep20_group"),
    ("n high risk or in debt distress", De["n_high_or_distress"], "n_high_or_distress"), ("Group A high risk or in distress", G["n_high_or_distress"], "groupA_debt"),
    ("n with single-country Pandemic Fund award", Pf["n_single"], "pf_n_single"), ("Group A without single-country award", G["n_no_single"], "pf_groupA_no_single"),
    ("Single-country awards to 34 (US$m)", Pf["single_total_usd_m"], "pf_total"),
    ("n below workforce threshold", W["n_below"], "hwf_below"),
    ("Four functions 2026, 16 five-year (US$m)", U["excl_bwa_2026_usd_m"], "hs5_2026"), ("Four functions 2030, 16 five-year (US$m)", U["excl_bwa_2030_usd_m"], "hs5_2030"),
    ("Change, 16 five-year", U["excl_bwa_change_pct"] / 100, "hs5_change"),
    ("Four functions 2026, 17 (US$m)", U["total_2026_usd_m"], "hs2026"), ("Four functions 2030, 17 (US$m)", U["total_2030_usd_m"], "hs2030"),
    ("Change, 17", U["change_pct"] / 100, "hs_change"), ("Largest fall as share of 2023 spending", U["drop_pct_gghed_max"] / 100, "hs_max"),
]
for i, (lab, rv, key) in enumerate(checks, 3):
    wr.cell(row=i, column=1, value=lab).font = BLACK
    c = wr.cell(row=i, column=2, value=float(rv)); c.font = BLUE; c.number_format = "0.0000"
    c = wr.cell(row=i, column=3, value=f"={keymap[key]}"); c.font = GREEN; c.number_format = "0.0000"
    c = wr.cell(row=i, column=4, value=f"=C{i}-B{i}"); c.font = BLACK; c.number_format = "0.000000"
    wr.cell(row=i, column=5, value=f'=IF(ABS(D{i})<=0.000001*MAX(1,ABS(B{i})),"MATCH","CHECK")').font = BLACK
n = len(checks) + 2
wr.cell(row=n + 2, column=1, value="Rows matching").font = BOLD
wr.cell(row=n + 2, column=2, value=f'=COUNTIF(E3:E{n},"MATCH")&" of "&COUNTA(A3:A{n})').font = BOLD
wr.cell(row=n + 3, column=1, value="R values are typed from results/results.json (blue). They match only at the default Inputs; changing an input will show CHECK by design.").font = Font(name=F, size=9, italic=True)
wr.column_dimensions["A"].width = 46
for L in "BCDE": wr.column_dimensions[L].width = 16

from openpyxl.workbook.properties import CalcProperties
wb.calculation = CalcProperties(fullCalcOnLoad=True)
OUTX.parent.mkdir(parents=True, exist_ok=True); wb.save(OUTX)
print("saved; summary keys:", len(keymap))
