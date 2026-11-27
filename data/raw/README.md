# data/raw

This folder is empty on purpose. You need it only to rebuild `data/analysis/` from the original third-party downloads; `run_all.R` does not need it.

To rebuild, create these subfolders and put the downloaded files in them, keeping the file names: `kff/`, `who_ghed/`, `who_spar/`, `ghs_ahs/`, `debt/`. Then run `Rscript run_all.R --rebuild-data` from the repository folder.

`raw_files.csv` lists the 15 files with their publisher, version, download page, size and checksums. The main README has the same list with links.
