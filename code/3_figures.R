# =============================================================================
# 3_figures.R
# Purpose : Figure 1 (article) and eFigures 1-6 (supplement), numbered in the
#           order they are cited. Legends sit beside each plot, outside the
#           plotting area. No encoding relies on colour alone: debt status is
#           shown by fill (solid, open, grey square) and shape.
# Devices : ragg if installed; otherwise Cairo; otherwise the platform's
#           native device (quartz on macOS) and the standard pdf() device.
# =============================================================================
log_line("3 figures: start")
# 2_analysis.R leaves its results in the list `obj`; run_all.R runs both scripts.
if (!exists("obj")) stop("Run 2_analysis.R before 3_figures.R (run_all.R does both).", call. = FALSE)
master <- read_csv(file.path(DER, "master_country_dataset.csv"), show_col_types = FALSE, guess_max = 1000)
s34 <- obj$s34; R <- obj$R; REF <- obj$REF
ghed_panel <- read_csv(file.path(DER, "ghed_panel_2010_2024.csv"), show_col_types = FALSE)
idx <- read_csv(file.path(DER, "index_universes.csv"), show_col_types = FALSE)

INK <- "#1b1b1b"; INK2 <- "#55534e"; GRID <- "#e6e5e1"; ZONE <- "#f1ede6"; ACCENT <- "#c4552b"

# ---- Device selection --------------------------------------------------------
has_ragg <- requireNamespace("ragg", quietly = TRUE)
has_cairo <- isTRUE(capabilities("cairo"))
pick_family <- function() {
  if (Sys.info()[["sysname"]] == "Darwin") return("Arial")
  fc <- tryCatch(system("fc-list : family", intern = TRUE, ignore.stderr = TRUE), error = function(e) character())
  if (any(grepl("Liberation Sans", fc))) return("Liberation Sans")
  if (any(grepl("Arial", fc))) return("Arial")
  "sans"
}
FAM_RASTER <- if (has_ragg || has_cairo || Sys.info()[["sysname"]] == "Darwin") pick_family() else "sans"
FAM_PDF <- if (has_cairo) pick_family() else "sans"       # pdf() only knows its own families
save_fig <- function(builder, name, w, h) {
  png_file <- file.path(OUT_F, paste0(name, ".png")); pdf_file <- file.path(OUT_F, paste0(name, ".pdf"))
  p_r <- builder(FAM_RASTER)
  if (has_ragg) {
    ggsave(png_file, p_r, width = w, height = h, dpi = 600, units = "in", device = ragg::agg_png, bg = "white")
  } else if (has_cairo) {
    ggsave(png_file, p_r, width = w, height = h, dpi = 600, units = "in", type = "cairo", bg = "white")
  } else {
    ggsave(png_file, p_r, width = w, height = h, dpi = 600, units = "in", bg = "white")
  }
  p_p <- builder(FAM_PDF)
  if (has_cairo) {
    ggsave(pdf_file, p_p, width = w, height = h, units = "in", device = cairo_pdf, bg = "white")
  } else {
    ggsave(pdf_file, p_p, width = w, height = h, units = "in", device = grDevices::pdf, useDingbats = FALSE, bg = "white")
  }
  invisible(p_r)
}
theme_paper <- function(fam, base = 9) {
  theme_minimal(base_size = base, base_family = fam) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = GRID, linewidth = 0.3),
          axis.title = element_text(colour = INK, size = base),
          axis.text = element_text(colour = INK2, size = base - 1),
          legend.position = "right", legend.title = element_text(size = base - 0.5, face = "bold"),
          legend.text = element_text(size = base - 1, colour = INK),
          legend.key.height = unit(0.9, "lines"),
          plot.title = element_blank(), plot.margin = margin(6, 6, 6, 6),
          strip.text = element_text(face = "bold", colour = INK, size = base - 0.5, hjust = 0))
}
short <- function(x) recode(x, "United Republic of Tanzania" = "Tanzania",
                            "Democratic Republic of the Congo" = "DR Congo",
                            "Bolivia (Plurinational State of)" = "Bolivia",
                            "Dominican Republic" = "Dominican Rep.", "Papua New Guinea" = "Papua New Guinea")
debt_levels <- c("High risk or in debt distress", "Low or moderate risk", "Not rated under LIC-DSF")

# ---- Figure 1: pledge share x SPAR, sized by US funding, debt overlay ---------
f1 <- s34 %>%
  mutate(debt = factor(debt_group, levels = debt_levels),
         lab = paste0(short(country), if_else(iso3 %in% c("UGA", "COD"), "*", ""),
                      if_else(iso3 %in% c("KEN", "NGA"), "‡", ""),
                      if_else(pf_single_n == 0, "†", "")))
arrows <- f1 %>% filter(screen_group_dep20, !screen_group)
check(setequal(arrows$iso3, c("BDI", "CIV", "NER")), "three countries enter the group after a 20% depreciation")
X_LIM <- c(0.01, 80); Y_LIM <- c(25, 80)
check(all(f1$pledge_share_pct >= X_LIM[1] & f1$pledge_share_pct <= X_LIM[2] &
            f1$spar_2025 >= Y_LIM[1] & f1$spar_2025 <= Y_LIM[2]), "all 34 countries lie inside Figure 1 limits")
fig1 <- function(fam) {
  ggplot(f1, aes(pledge_share_pct, spar_2025)) +
    annotate("rect", xmin = PLEDGE_THRESHOLD, xmax = X_LIM[2], ymin = Y_LIM[1], ymax = SPAR_GLOBAL_MEAN, fill = ZONE) +
    geom_vline(xintercept = PLEDGE_THRESHOLD, colour = INK2, linewidth = 0.3) +
    geom_hline(yintercept = SPAR_GLOBAL_MEAN, colour = INK2, linewidth = 0.3) +
    annotate("text", x = 75, y = 26, hjust = 1, vjust = 0, size = 2.6, family = fam, colour = INK2,
             label = "Pledge share ≥10% and SPAR\nbelow the global average") +
    annotate("text", x = 0.011, y = SPAR_GLOBAL_MEAN + 0.6, hjust = 0, vjust = 0, size = 2.5,
             family = fam, colour = INK2, label = "Global SPAR average (63)") +
    geom_point(data = arrange(f1, desc(us_funding_usd)),
               aes(size = us_funding_usd / 1e6, fill = debt, shape = debt), colour = INK,
               stroke = 0.35, alpha = 0.78) +
    geom_segment(data = arrows, aes(x = pledge_share_pct, xend = pledge_dep20_pct,
                                    y = spar_2025, yend = spar_2025),
                 arrow = arrow(length = unit(0.07, "in"), type = "closed"), linewidth = 0.5, colour = INK) +
    geom_text_repel(aes(label = lab), size = 2.3, family = fam, colour = INK,
                    min.segment.length = 0.15, segment.size = 0.2, segment.colour = INK2,
                    box.padding = 0.22, point.padding = 0.12, max.overlaps = Inf, seed = 11, force = 1.5) +
    scale_x_log10(breaks = c(0.01, 0.1, 1, 5, 10, 20, 50), labels = c("0.01", "0.1", "1", "5", "10", "20", "50"),
                  limits = X_LIM, expand = expansion(mult = 0.01)) +
    scale_y_continuous(limits = Y_LIM, breaks = seq(30, 80, 10), expand = expansion(mult = 0.01)) +
    scale_size_area(max_size = 9.5, breaks = c(100, 500, 1000, 2000), name = "US funding over\nthe term (US$m)") +
    scale_fill_manual(values = setNames(c(ACCENT, "white", "#c9c7c1"), debt_levels), drop = FALSE,
                      name = "Debt distress rating\n(IMF-World Bank)") +
    scale_shape_manual(values = setNames(c(21, 21, 22), debt_levels), drop = FALSE,
                       name = "Debt distress rating\n(IMF-World Bank)") +
    guides(fill = guide_legend(order = 1, override.aes = list(size = 3.5)),
           shape = guide_legend(order = 1), size = guide_legend(order = 2, override.aes = list(fill = "white", shape = 21))) +
    labs(x = "Average annual partner commitment as % of 2023 domestic government health spending (log scale)",
         y = "SPAR 2025 score (self-reported, 0-100)") +
    theme_paper(fam, 8.5)
}
p1 <- save_fig(fig1, "Figure1_pledge_share_preparedness_debt", 7.6, 5.2)
built <- ggplot_build(p1)
pts <- built$data[[which(vapply(p1$layers, function(l) inherits(l$geom, "GeomPoint"), logical(1)))[1]]]
check(nrow(pts) == 34 && all(is.finite(pts$x) & is.finite(pts$y)), "Figure 1 draws all 34 points")
write_csv(f1 %>% transmute(iso3, country, label = lab, pledge_share_pct, pledge_dep20_pct, spar_2025,
                           us_funding_usd, debt_group, pf_single_n, screen_group, screen_group_dep20,
                           pheic_2026 = iso3 %in% c("UGA", "COD")),
          file.path(OUT_T, "Figure1_data.csv"), na = "")

# ---- eFigure 2: the same screen with the two external indices ------------------
ef1 <- bind_rows(
  f1 %>% transmute(iso3, lab = short(country), pledge_share_pct, us_funding_usd, debt, score = ghs_overall_2021,
                   ref = REF$GHS_MEDIAN_2021,
                   panel = sprintf("A  Global Health Security Index 2021 (34 agreements; index median %.1f)", REF$GHS_MEDIAN_2021)),
  f1 %>% filter(!is.na(ahs_overall_2026)) %>%
    transmute(iso3, lab = short(country), pledge_share_pct, us_funding_usd, debt, score = ahs_overall_2026,
              ref = REF$AHS_MEDIAN_2026,
              panel = sprintf("B  Africa Health Security Index 2026 (25 agreements; index median %.2f)", REF$AHS_MEDIAN_2026)))
check(sum(!is.na(ef1$score)) == 59, "eFigure 2 draws 34 + 25 points")
efig1 <- function(fam) {
  refs <- ef1 %>% distinct(panel, ref)
  ggplot(ef1, aes(pledge_share_pct, score)) +
    geom_rect(data = refs, aes(xmin = PLEDGE_THRESHOLD, xmax = 80, ymin = 15, ymax = ref), inherit.aes = FALSE, fill = ZONE) +
    geom_hline(data = refs, aes(yintercept = ref), colour = INK2, linewidth = 0.3, linetype = "22") +
    geom_vline(xintercept = PLEDGE_THRESHOLD, colour = INK2, linewidth = 0.3, linetype = "22") +
    geom_point(data = arrange(ef1, desc(us_funding_usd)), aes(size = us_funding_usd / 1e6, fill = debt, shape = debt),
               colour = INK, stroke = 0.35, alpha = 0.85) +
    geom_text_repel(data = filter(ef1, pledge_share_pct >= 5 | score > 50), aes(label = lab), size = 2.2, family = fam,
                    colour = INK, segment.size = 0.2, segment.colour = INK2, max.overlaps = Inf, seed = 7) +
    facet_wrap(~ panel, ncol = 1) +
    scale_x_log10(breaks = c(0.01, 0.1, 1, 10, 50), labels = c("0.01", "0.1", "1", "10", "50"), limits = c(0.01, 80)) +
    scale_y_continuous(limits = c(15, 65), breaks = seq(20, 60, 10)) +
    scale_size_area(max_size = 9, breaks = c(100, 500, 1500), name = "US funding over\nthe term (US$m)") +
    scale_fill_manual(values = setNames(c(ACCENT, "white", "#c9c7c1"), debt_levels), drop = FALSE, name = "Debt distress rating") +
    scale_shape_manual(values = setNames(c(21, 21, 22), debt_levels), drop = FALSE, name = "Debt distress rating") +
    guides(fill = guide_legend(order = 1, override.aes = list(size = 3.2)), shape = guide_legend(order = 1),
           size = guide_legend(order = 2, override.aes = list(fill = "white", shape = 21))) +
    labs(x = "Average annual partner commitment as % of 2023 domestic government health spending (log scale)",
         y = "Index score (0-100)") +
    theme_paper(fam, 8.5)
}
save_fig(efig1, "eFigure2_external_indices", 7.4, 7.4)

# ---- eFigure 3: preparedness by agreement status --------------------------------
ef2 <- idx %>% mutate(group = factor(if_else(agreement, "Agreement", "No agreement"), levels = c("No agreement", "Agreement")),
                      panel = if_else(index == "GHS 2021", "A  Global Health Security Index 2021 (195 countries)",
                                      "B  Africa Health Security Index 2026 (54 countries)"))
ef2s <- ef2 %>% group_by(panel, group) %>%
  summarise(n = n(), p25 = quantile(score, .25), med = median(score), p75 = quantile(score, .75), .groups = "drop")
ef2r <- tibble(panel = unique(ef2$panel)[order(unique(ef2$panel))], ref = c(REF$GHS_MEDIAN_2021, REF$AHS_MEDIAN_2026))
efig2 <- function(fam) {
  ggplot(ef2, aes(score, group)) +
    geom_vline(data = ef2r, aes(xintercept = ref), linetype = "22", colour = INK2, linewidth = 0.35) +
    geom_point(aes(shape = group), position = position_jitter(width = 0, height = 0.13, seed = 101),
               size = 1.4, colour = INK2, alpha = 0.7) +
    geom_segment(data = ef2s, aes(x = p25, xend = p75, y = as.numeric(group) - 0.3, yend = as.numeric(group) - 0.3),
                 inherit.aes = FALSE, linewidth = 1, colour = INK) +
    geom_point(data = ef2s, aes(x = med, y = as.numeric(group) - 0.3), inherit.aes = FALSE, shape = 23,
               fill = "white", colour = INK, size = 2.4, stroke = 0.8) +
    geom_text(data = ef2s, aes(x = 98, y = group, label = paste0("n = ", n)), inherit.aes = FALSE, hjust = 1,
              size = 2.5, family = fam, colour = INK2) +
    facet_wrap(~ panel, ncol = 1) +
    scale_shape_manual(values = c(`No agreement` = 1, Agreement = 16), name = NULL) +
    scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
    labs(x = "Index score (0-100)", y = NULL) + theme_paper(fam, 8.5) +
    theme(panel.grid.major.y = element_blank(), legend.position = "none")
}
save_fig(efig2, "eFigure3_preparedness_by_agreement_status", 7, 4.6)

# ---- eFigure 1: threshold x measure grid ------------------------------------------
gr <- obj$grid %>% mutate(measure = factor(measure, levels = rev(unique(measure))),
                          lab = paste0(n, " of ", eligible, "\n(", n_in_primary, " in main group)"))
efig3 <- function(fam) {
  ggplot(gr, aes(factor(threshold), measure)) +
    geom_tile(fill = "#f4f2ee", colour = "white", linewidth = 0.8) +
    geom_text(aes(label = lab), size = 2.6, family = fam, colour = INK, lineheight = 0.9) +
    labs(x = "Pledge share threshold (% of 2023 domestic government health spending)", y = NULL) +
    theme_paper(fam, 8.5) + theme(panel.grid = element_blank())
}
save_fig(efig3, "eFigure1_threshold_grid", 7, 2.6)

# ---- eFigure 4: US funding for four outbreak-related functions --------------------
hs <- obj$hs %>% mutate(lab = paste0(short(country), if_else(term_years == 3, " (agreement ends 2028)", "")),
                        p2026 = 100 * hs_2026 / gghed_usd_2023, p2030 = 100 * hs_2030 / gghed_usd_2023) %>%
  arrange(p2026) %>% mutate(lab = factor(lab, levels = lab))
efig4 <- function(fam) {
  ggplot(hs, aes(y = lab)) +
    geom_segment(aes(x = p2030, xend = p2026, yend = lab), colour = INK2, linewidth = 0.5) +
    geom_point(aes(x = p2026, shape = "2026"), size = 2.1, fill = INK, colour = INK) +
    geom_point(aes(x = p2030, shape = "2030"), size = 2.1, fill = "white", colour = INK, stroke = 0.5) +
    scale_shape_manual(values = c(`2026` = 21, `2030` = 21), name = "Planned year",
                       guide = guide_legend(override.aes = list(fill = c(INK, "white")))) +
    labs(x = "Planned US funding for surveillance and outbreak response, laboratories, health workforce and data systems\nas % of 2023 domestic government health spending",
         y = NULL) + theme_paper(fam, 8)
}
save_fig(efig4, "eFigure4_us_outbreak_functions", 7, 4.4)

# ---- eFigure 5: domestic government health spending trends, screening group ------
grp_iso <- s34$iso3[s34$screen_group]
ef5 <- ghed_panel %>% filter(iso3 %in% grp_iso, year >= TREND_START, year <= GHED_BASE_YEAR, !is.na(gghed_usd)) %>%
  group_by(iso3) %>% arrange(year) %>%
  mutate(base_year = first(year), `Current US dollars` = 100 * gghed_usd / first(gghed_usd),
         `Constant local currency` = 100 * gghed_real_ncu / first(gghed_real_ncu)) %>% ungroup() %>%
  mutate(location = paste0(short(location), if_else(base_year > TREND_START, paste0(" (", base_year, " = 100)"), ""))) %>%
  select(iso3, location, year, `Current US dollars`, `Constant local currency`) %>%
  pivot_longer(c(`Current US dollars`, `Constant local currency`), names_to = "measure", values_to = "index")
check(n_distinct(ef5$iso3) == 10, "eFigure 5 shows all 10 group countries")
efig5 <- function(fam) {
  ggplot(ef5, aes(year, index, linetype = measure)) +
    geom_hline(yintercept = 100, colour = INK2, linewidth = 0.3) +
    geom_line(linewidth = 0.55, colour = INK) +
    facet_wrap(~ location, ncol = 4, scales = "free_y") +
    scale_linetype_manual(values = c("solid", "22"), name = NULL) +
    scale_x_continuous(breaks = c(2015, 2019, 2023)) +
    labs(x = NULL, y = "Domestic government health spending (2015 = 100 unless stated)") + theme_paper(fam, 8) +
    theme(legend.position = "bottom")
}
save_fig(efig5, "eFigure5_spending_trends_group", 7.2, 5.4)

# ---- eFigure 6: country profiles (seven criteria) ----------------------------------
prof <- s34 %>% arrange(pledge_share_pct) %>% mutate(lab = factor(short(country), levels = short(country))) %>%
  transmute(lab,
            v1 = if_else(pledge_share_pct < 1, sprintf("%.2f", pledge_share_pct), sprintf("%.1f", pledge_share_pct)), f1 = high_pledge,
            v2 = sprintf("%.0f", spar_2025), f2 = spar_below_global,
            v3 = sprintf("%.1f", ghs_overall_2021), f3 = ghs_below_median,
            v4 = sprintf("%.0f", ext_che_2023), f4 = ext_che_2023 >= 25,
            v5 = recode(as.character(dsf_overall_risk), "In debt distress" = "Distress", .missing = "Not rated"), f5 = dsf_high_or_distress %in% TRUE,
            v6 = sprintf("%.0f", hwf_dnm_per10k), f6 = hwf_below_sdg_threshold %in% TRUE,
            v7 = if_else(pf_single_n > 0, sprintf("$%.0fm", pf_single_grant_usd / 1e6), "None"), f7 = pf_single_n == 0)
crit <- c("Pledge share\n(% of 2023\nspending)", "SPAR\n2025", "GHS\n2021", "External share\nof health\nspending (%)",
          "Debt distress\nrating", "Doctors, nurses\nand midwives\nper 10 000", "Pandemic Fund\nsingle-country\naward")
tiles <- map_dfr(1:7, function(i) tibble(lab = prof$lab, ind = crit[i], val = prof[[paste0("v", i)]],
                                         flag = coalesce(prof[[paste0("f", i)]], FALSE))) %>%
  mutate(ind = factor(ind, levels = crit))
efig6 <- function(fam) {
  ggplot(tiles, aes(ind, lab)) +
    geom_tile(aes(fill = flag), colour = "white", linewidth = 0.6) +
    geom_text(aes(label = val), size = 2.2, family = fam, colour = INK) +
    scale_fill_manual(values = c(`FALSE` = "#f4f3f0", `TRUE` = "#e9b9a2"),
                      labels = c("Criterion not met", "Criterion met"), name = NULL) +
    scale_x_discrete(position = "top") + labs(x = NULL, y = NULL) + theme_paper(fam, 8) +
    theme(panel.grid = element_blank(), axis.text.x.top = element_text(size = 6.6, colour = INK),
          axis.ticks = element_blank(), legend.position = "right")
}
save_fig(efig6, "eFigure6_country_profiles", 7.4, 7.6)

log_line("3 figures: done;", length(list.files(OUT_F, pattern = "\\.png$")), "PNG and",
         length(list.files(OUT_F, pattern = "\\.pdf$")), "PDF files")
