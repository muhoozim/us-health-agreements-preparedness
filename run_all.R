# =============================================================================
# run_all.R  -  reproduces every result, table and figure in the article
#
# From a terminal, in this folder:      Rscript run_all.R
# In RStudio: open the .Rproj file, then click "Source" on this file.
#
# By default the analysis starts from the analysis-ready files in data/analysis/
# (no downloads needed; about 30 seconds). To rebuild those files from the
# original third-party downloads first, place the downloads in data/raw/ (see
# README.md) and run:                    Rscript run_all.R --rebuild-data
# =============================================================================

# Find the repository root (the folder that contains this file), whichever way
# the script is started, so that every path below is relative to it.
find_root <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) return(dirname(normalizePath(f)))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- rstudioapi::getSourceEditorContext()$path
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  normalizePath(getwd())
}
ROOT <- find_root()
setwd(ROOT)
if (!file.exists(file.path(ROOT, "code", "setup.R")))
  stop("Run this script from the repository folder (the one that contains run_all.R).")

REBUILD <- "--rebuild-data" %in% commandArgs(trailingOnly = TRUE) ||
  identical(Sys.getenv("REBUILD_DATA"), "true")

source(file.path("code", "setup.R"))
if (REBUILD) {
  log_line("Rebuilding data/analysis/ from the downloads in", RAW)
  source(file.path("code", "1_build_dataset.R"))
} else {
  log_line("Using the analysis-ready files in data/analysis/")
}
source(file.path("code", "2_analysis.R"))
source(file.path("code", "3_figures.R"))
source(file.path("code", "4_check_paper_numbers.R"))
writeLines(capture.output(sessionInfo()), file.path(OUT_L, "sessionInfo.txt"))
log_line("Done. Results are in", OUT)
