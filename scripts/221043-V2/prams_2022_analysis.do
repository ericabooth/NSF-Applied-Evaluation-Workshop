
**# Part 2 — PRAMS 2022 Ecological Regression (prams_2022_analysis.do)
*--------------------------------------------------------------------
** Example 2: ICPSR PRAMS data
**! PURPOSE: Explore Federal health Survey data for policy decisions
/*====================================================================
  Research Question:
    Do state-level rates of being uninsured before pregnancy predict
    pre-pregnancy depression rates among postpartum women surveyed
    by PRAMS in 2022?

  Hypothesis:
    States where a higher share of women lacked health insurance in
    the month before pregnancy will exhibit higher rates of
    self-reported depression in the 3 months before pregnancy,
    reflecting structural barriers to mental health care access.

  Data:  CDC PRAMS MCH Indicators 2022 (Weighted Estimates Only)
  Unit:  State / jurisdiction (N = 32)
  File:  PRAMS-MCH-Indicators-2022-508.xlsx

  Excel layout per indicator block:
    Row 1  = Topic title
    Row 2  = Indicator label
    Row 3  = Column headers
    Rows 4-36 = Data (row 4 = sites aggregated; rows 5-36 = 32 jurisdictions)
    Next block starts +35 rows later (rows 37-71, 72-106, …)
    Columns: A=State  B=N(denom)  C=n(num)  D=Weighted%  E=Lower95  F=Upper95
====================================================================*/

clear all

* ── 0. Paths & log ───────────────────────────────────────────────────────────

global data  "/Users/ericbooth/Documents/PVAMU_NSF_Workshop_2026/scripts/221043-V2"
global out   "$data/output_2022"
global fname "PRAMS-MCH-Indicators-2022-508.xlsx"

cap mkdir "$out"


/*====================================================================
  SECTION 1 — IMPORT & STACK INTO MASTER DATASET
  Strategy: import each indicator block separately, keep only
  state (col A) and Weighted % (col D), then merge on state name.
  We import cols A:F for dep_before to capture 95% CIs for the
  caterpillar plot; all other variables use cols A:D only.
====================================================================*/

* ── 1a. Pre-pregnancy depression (Depression sheet, rows 4–36) ────────────
import excel using "$data/$fname", ///
    sheet("Depression") cellrange(A4:F36) clear

rename (A B C D E F) (state N_unwt n_unwt dep_before dep_before_lo dep_before_hi)
drop N_unwt n_unwt
drop if state == "Sites aggregated*"
foreach v of varlist dep_before dep_before_lo dep_before_hi {
    destring `v', replace force
}
save "$out/prams22_master.dta", replace

* ── 1b. Depression during pregnancy (Depression sheet, rows 39–71) ─────────
import excel using "$data/$fname", ///
    sheet("Depression") cellrange(A39:D71) clear

rename (A D) (state dep_during)
drop B C
drop if state == "Sites aggregated*"
destring dep_during, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1c. Postpartum depressive symptoms (Depression sheet, rows 74–106) ─────
import excel using "$data/$fname", ///
    sheet("Depression") cellrange(A74:D106) clear

rename (A D) (state dep_postpartum)
drop B C
drop if state == "Sites aggregated*"
destring dep_postpartum, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1d. Cigarette smoking before pregnancy (Substance Use, rows 4–36) ───────
import excel using "$data/$fname", ///
    sheet("Substance Use") cellrange(A4:D36) clear

rename (A D) (state smoke_before)
drop B C
drop if state == "Sites aggregated*"
destring smoke_before, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1e. Prenatal care in 1st trimester (Health Care Services, rows 39–71) ───
import excel using "$data/$fname", ///
    sheet("Health Care Services") cellrange(A39:D71) clear

rename (A D) (state prenatal_1strim)
drop B C
drop if state == "Sites aggregated*"
destring prenatal_1strim, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1f. Private insurance before pregnancy (Health Ins. Before, rows 4–36) ──
import excel using "$data/$fname", ///
    sheet("Health Ins. Status Before Preg.") cellrange(A4:D36) clear

rename (A D) (state ins_private_before)
drop B C
drop if state == "Sites aggregated*"
destring ins_private_before, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1g. Medicaid/CHIP before pregnancy (Health Ins. Before, rows 39–71) ─────
import excel using "$data/$fname", ///
    sheet("Health Ins. Status Before Preg.") cellrange(A39:D71) clear

rename (A D) (state ins_medicaid_before)
drop B C
drop if state == "Sites aggregated*"
destring ins_medicaid_before, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1h. No insurance before pregnancy (Health Ins. Before, rows 74–106) ─────
import excel using "$data/$fname", ///
    sheet("Health Ins. Status Before Preg.") cellrange(A74:D106) clear

rename (A D) (state ins_none_before)
drop B C
drop if state == "Sites aggregated*"
destring ins_none_before, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

* ── 1i. Ever breastfed (Breastfeeding Practices, rows 4–36) ─────────────────
import excel using "$data/$fname", ///
    sheet("Breastfeeding Practices") cellrange(A4:D36) clear

rename (A D) (state bf_ever)
drop B C
drop if state == "Sites aggregated*"
destring bf_ever, replace force
merge 1:1 state using "$out/prams22_master.dta", nogen
save "$out/prams22_master.dta", replace

/*====================================================================
  SECTION 2 — CLEAN, LABEL & ENRICH MASTER DATASET
====================================================================*/

use "$out/prams22_master.dta", clear

* ── 2a. State abbreviation crosswalk ────────────────────────────────────────
gen state_abbr = ""
replace state_abbr = "AL"  if state == "Alabama"
replace state_abbr = "AZ"  if state == "Arizona"
replace state_abbr = "CO"  if state == "Colorado"
replace state_abbr = "CT"  if state == "Connecticut"
replace state_abbr = "DE"  if state == "Delaware"
replace state_abbr = "DC"  if state == "District of Columbia"
replace state_abbr = "HI"  if state == "Hawaii"
replace state_abbr = "KS"  if state == "Kansas"
replace state_abbr = "KY"  if state == "Kentucky"
replace state_abbr = "ME"  if state == "Maine"
replace state_abbr = "MA"  if state == "Massachusetts"
replace state_abbr = "MI"  if state == "Michigan"
replace state_abbr = "MO"  if state == "Missouri"
replace state_abbr = "MT"  if state == "Montana"
replace state_abbr = "NE"  if state == "Nebraska"
replace state_abbr = "NJ"  if state == "New Jersey"
replace state_abbr = "NM"  if state == "New Mexico"
replace state_abbr = "NYC" if state == "New York City"
replace state_abbr = "NY"  if state == "New York State"
replace state_abbr = "ND"  if state == "North Dakota"
replace state_abbr = "NMI" if state == "Northern Mariana Islands"
replace state_abbr = "OK"  if state == "Oklahoma"
replace state_abbr = "PA"  if state == "Pennsylvania"
replace state_abbr = "PR"  if state == "Puerto Rico"
replace state_abbr = "RI"  if state == "Rhode Island"
replace state_abbr = "SD"  if state == "South Dakota"
replace state_abbr = "UT"  if state == "Utah"
replace state_abbr = "VT"  if state == "Vermont"
replace state_abbr = "VA"  if state == "Virginia"
replace state_abbr = "WA"  if state == "Washington"
replace state_abbr = "WI"  if state == "Wisconsin"
replace state_abbr = "WY"  if state == "Wyoming"

* ── 2b. Region grouping (Census Bureau divisions) ───────────────────────────
gen region = .
label define regionlbl 1 "Northeast" 2 "Midwest" 3 "South" 4 "West" 5 "Territory"
label values region regionlbl

replace region = 1 if inlist(state_abbr, "CT","ME","MA","NJ","NY","NYC","PA","RI","VT")
replace region = 2 if inlist(state_abbr, "KS","MI","MO","NE","ND","SD","WI")
replace region = 3 if inlist(state_abbr, "AL","DE","DC","KY","OK","VA","WV")
replace region = 4 if inlist(state_abbr, "AZ","CO","HI","MT","NM","UT","WA","WY")
replace region = 5 if inlist(state_abbr, "NMI","PR")

* ── 2c. Variable labels ──────────────────────────────────────────────────────
label var state              "State/Jurisdiction Name"
label var state_abbr         "State Abbreviation"
label var dep_before         "Pre-pregnancy depression, % (weighted)"
label var dep_before_lo      "Pre-pregnancy depression, lower 95% CI"
label var dep_before_hi      "Pre-pregnancy depression, upper 95% CI"
label var dep_during         "Depression during pregnancy, % (weighted)"
label var dep_postpartum     "Postpartum depressive symptoms, % (weighted)"
label var smoke_before       "Cigarette smoking before pregnancy, % (weighted)"
label var prenatal_1strim    "Prenatal care began in 1st trimester, % (weighted)"
label var ins_private_before "Private insurance before pregnancy, % (weighted)"
label var ins_medicaid_before "Medicaid/CHIP before pregnancy, % (weighted)"
label var ins_none_before    "No insurance before pregnancy, % (weighted)"
label var bf_ever            "Ever breastfed, % (weighted)"

* ── 2d. Quick data check ─────────────────────────────────────────────────────
assert _N == 32
list state state_abbr if missing(state_abbr)   // should return empty

sort state
gen state_id = _n

save "$out/prams22_master.dta", replace

/*====================================================================
  SECTION 3 — DESCRIPTIVE STATISTICS

  Research Question:
    Do state-level rates of being uninsured before pregnancy predict
    pre-pregnancy depression rates among postpartum women surveyed
    by PRAMS in 2022?
====================================================================*/

use "$out/prams22_master.dta", clear

di as text _n "══════════════════════════════════════════════════════"
di as text    " Table 1. Summary Statistics — PRAMS 2022 (N=32)"
di as text    "══════════════════════════════════════════════════════"

tabstat dep_before dep_during dep_postpartum          ///
        ins_none_before ins_medicaid_before            ///
        ins_private_before smoke_before prenatal_1strim ///
        bf_ever,                                       ///
    stats(n mean sd min p25 p50 p75 max) col(stats)   ///
    format(%6.1f) varwidth(28)

di as text _n "── Detailed: Outcome & Main Predictor ──────────────────"
sum dep_before ins_none_before, detail

* ── 3b. Top/bottom five by depression ───────────────────────────────────────
di as text _n "── States with highest pre-pregnancy depression ─────────"
gsort -dep_before
list state_abbr dep_before dep_before_lo dep_before_hi ///
    ins_none_before in 1/5, clean noobs abbrev(12)

di as text _n "── States with lowest pre-pregnancy depression ──────────"
gsort +dep_before
list state_abbr dep_before dep_before_lo dep_before_hi ///
    ins_none_before in 1/5, clean noobs abbrev(12)

* ── 3c. Correlation matrix ───────────────────────────────────────────────────
di as text _n "── Correlations among key variables ─────────────────────"
pwcorr dep_before ins_none_before ins_medicaid_before ///
       smoke_before prenatal_1strim, sig star(0.10)

**Descriptives.** Pre-pregnancy depression rates vary substantially across the 32 PRAMS jurisdictions — from 6.0% (New York City) to 26.4% (Wyoming), with a mean of 17.5%. Uninsurance before pregnancy averages 10.0% (range: 3.1% to 22.7%). The highest-depression states (WY, MO, UT, KY, VT) tend to be rural/Midwest states with high smoking rates; the lowest-depression states (NYC, PR, NJ, HI) are urban or have low smoking rates, which foreshadows the regression findings.

**Correlations.** The strongest predictor of state depression rates is cigarette smoking before pregnancy (r = 0.72, p<0.001). Medicaid coverage is negatively correlated with depression (r = −0.52, p<0.01) — states with higher public coverage have lower depression rates. The raw correlation between uninsurance and depression (r = 0.27) is positive but not statistically significant (p=0.136).

/*====================================================================
  SECTION 4 — VISUALIZATION
====================================================================*/

* shared graph scheme
set scheme s1color

* ── 4a. Sorted horizontal bar chart — dep_before by state ────────────────────
graph hbar (asis) dep_before,                                             ///
    over(state_abbr, sort(dep_before) descending                          ///
        label(labsize(vsmall) angle(0)))                                  ///
    ytitle("Pre-Pregnancy Depression (%, weighted)")                      ///
    title("Pre-Pregnancy Depression by State/Jurisdiction"                ///
          "PRAMS 2022", size(medsmall))                                   ///
    note("Source: CDC PRAMS MCH Indicators 2022. N=32 jurisdictions."     ///
         "Dashed line = sites-aggregated estimate (17.1%).", span)        ///
    bar(1, fcolor(navy%70) lcolor(navy%0))                                ///
    yline(17.1, lpattern(dash) lcolor(cranberry) lwidth(medthin))         ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig1_dep_bar.png", replace width(1400)

* ── 4b. Caterpillar / forest plot — dep_before with 95% CIs ─────────────────
gsort -dep_before
gen rank = _n
gen rank_lbl = state_abbr    // for labeling the y-axis

twoway                                                                    ///
    (rcap dep_before_lo dep_before_hi rank, horizontal                    ///
        lcolor(gs12) lwidth(thin))                                        ///
    (scatter rank dep_before,                                             ///
        msymbol(circle) msize(small) mcolor(navy)                         ///
        mlabel(rank_lbl) mlabsize(vsmall) mlabpos(9)                      ///
        mlabcolor(gs4) mlabgap(1)),                                       ///
    ylabel(none)                                                          ///
    xtitle("Pre-Pregnancy Depression Rate (%), 95% CI")                   ///
    ytitle("")                                                            ///
    title("Pre-Pregnancy Depression with 95% Confidence Intervals"        ///
          "PRAMS 2022, Sorted by Estimate", size(medsmall))               ///
    xline(17.1, lpattern(dash) lcolor(cranberry) lwidth(medthin))         ///
    note("Dashed line = sites-aggregated estimate (17.1%)."               ///
         "Source: CDC PRAMS MCH Indicators 2022. N=32.", span)            ///
    legend(off)                                                           ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig2_dep_forest.png", replace width(1100) height(900)
drop rank rank_lbl

* ── 4c. Scatter: dep_before vs ins_none_before (key relationship) ────────────
twoway                                                                    ///
    (scatter dep_before ins_none_before,                                  ///
        msymbol(circle) msize(medsmall) mcolor(navy%65)                   ///
        mlabel(state_abbr) mlabsize(tiny) mlabpos(12)                     ///
        mlabcolor(gs5) mlabgap(1))                                        ///
    (lfit dep_before ins_none_before,                                     ///
        lcolor(cranberry) lwidth(medthin) lpattern(solid)),               ///
    xtitle("% Uninsured One Month Before Pregnancy (weighted)")           ///
    ytitle("% Pre-Pregnancy Depression (weighted)")                       ///
    title("Pre-Pregnancy Depression vs. Pre-Pregnancy Uninsurance"        ///
          "PRAMS 2022 — State/Jurisdiction Level", size(medsmall))        ///
    legend(order(1 "State estimate" 2 "OLS fit line")                     ///
           position(5) ring(0) size(small) cols(1))                       ///
    note("Source: CDC PRAMS MCH Indicators 2022. N=32.", span)            ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig3_scatter_dep_ins.png", replace width(1200)

* ── 4d. Scatter matrix — overview of main analytic variables ─────────────────
graph matrix dep_before ins_none_before smoke_before ins_medicaid_before, ///
    half                                                                  ///
    msymbol(circle) msize(vsmall) mcolor(navy%50)                        ///
    title("Correlation Matrix: Key PRAMS Indicators"                      ///
          "State/Jurisdiction Level, 2022", size(medsmall))               ///
    note("Source: CDC PRAMS MCH Indicators 2022. N=32.", span)            ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig4_matrix.png", replace width(1200)

/*====================================================================
  SECTION 5 — REGRESSION ANALYSIS

  Outcome:  dep_before — % pre-pregnancy depression (weighted)
  Unit:     State/jurisdiction (N = 32; ecological regression)

  Model progression:
    M1  Bivariate — dep_before ~ ins_none_before
    M2  Adjusted  — + smoke_before (SES/behavioral proxy)
    M3  Full      — + ins_medicaid_before (public insurance share)

  Note: With N=32 we keep the model parsimonious. Each β₁ is
  interpreted as: "A 1 pp increase in the uninsured share before
  pregnancy is associated with a β₁ pp change in depression rates."
====================================================================*/

* ── 5a. Model 1: bivariate ───────────────────────────────────────────────────
regress dep_before ins_none_before
estimates store m1

* ── 5b. Model 2: + smoking ───────────────────────────────────────────────────
regress dep_before ins_none_before smoke_before
estimates store m2

* ── 5c. Model 3: + Medicaid share ────────────────────────────────────────────
regress dep_before ins_none_before smoke_before ins_medicaid_before
estimates store m3

* ── 5d. Side-by-side regression table ────────────────────────────────────────
esttab m1 m2 m3,                                                          ///
    label b(%7.3f) se(%7.3f)                                              ///
    star(* 0.10 ** 0.05 *** 0.01)                                         ///
    stats(N r2 r2_a aic, fmt(%4.0f %6.3f %6.3f %6.1f)                    ///
          labels("N" "R²" "Adj. R²" "AIC"))                               ///
    title("Table 2. OLS Regression: Pre-Pregnancy Depression Rate (2022)") ///
    mtitles("Bivariate" "Adjusted" "Full")                                ///
    nonotes                                                               ///
    addnote("Unit of analysis: state/jurisdiction (N=32). Ecological regression." ///
            "All variables are weighted prevalence estimates (%)."         ///
            "Standard errors in parentheses. * p<.10  ** p<.05  *** p<.01")

* ── 5e. Coefficient plot — all three models ──────────────────────────────────
coefplot m1 m2 m3,                                                        ///
    drop(_cons)                                                           ///
    xline(0, lpattern(dash) lcolor(gs10))                                 ///
    title("Coefficient Estimates: Pre-Pregnancy Depression"               ///
          "PRAMS 2022 — State-Level OLS", size(medsmall))                 ///
    legend(order(2 "Model 1: Bivariate"                                   ///
                 4 "Model 2: Adjusted"                                    ///
                 6 "Model 3: Full")                                       ///
           position(4) ring(0) size(small) cols(1))                       ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig5_coefplot.png", replace width(1200)

* ── 5f. Fitted vs. observed — Model 2 ────────────────────────────────────────
quietly regress dep_before ins_none_before smoke_before
predict dep_hat, xb
predict dep_resid, residuals

twoway                                                                    ///
    (scatter dep_before dep_hat,                                          ///
        msymbol(circle) msize(medsmall) mcolor(navy%65)                   ///
        mlabel(state_abbr) mlabsize(tiny) mlabpos(3) mlabgap(1)           ///
        mlabcolor(gs5))                                                   ///
    (function y=x, range(8 28) lcolor(cranberry) lpattern(dash)),        ///
    xtitle("Fitted Values (Model 2)")                                     ///
    ytitle("Observed Pre-Pregnancy Depression (%)")                       ///
    title("Fitted vs. Observed: Pre-Pregnancy Depression"                 ///
          "PRAMS 2022, OLS Model 2", size(medsmall))                      ///
    legend(off)                                                           ///
    note("Dashed line = 45° perfect-fit reference."                       ///
         "Source: CDC PRAMS MCH Indicators 2022. N=32.", span)            ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig6_fit_vs_obs.png", replace width(1200)

* ── 5g. Residual plot ────────────────────────────────────────────────────────
twoway scatter dep_resid dep_hat,                                         ///
    msymbol(circle) msize(medsmall) mcolor(navy%65)                       ///
    mlabel(state_abbr) mlabsize(tiny) mlabpos(3) mlabgap(1)               ///
    mlabcolor(gs5)                                                        ///
    yline(0, lcolor(cranberry) lpattern(dash) lwidth(medthin))            ///
    xtitle("Fitted Values") ytitle("Residuals")                           ///
    title("Residuals vs. Fitted: OLS Model 2"                             ///
          "PRAMS 2022", size(medsmall))                                   ///
    note("Source: CDC PRAMS MCH Indicators 2022. N=32.", span)            ///
    plotregion(fcolor(white)) graphregion(fcolor(white))

graph export "$out/fig7_residuals.png", replace width(1200)

drop dep_hat dep_resid

/*====================================================================
  SECTION 6 — SAVE FINAL ANALYTIC DATASET
====================================================================*/

order state state_abbr region                                             ///
      dep_before dep_before_lo dep_before_hi dep_during dep_postpartum   ///
      ins_none_before ins_private_before ins_medicaid_before              ///
      smoke_before prenatal_1strim bf_ever

sort state
save "$out/prams22_master.dta", replace
export delimited "$out/prams22_master.csv", replace

di as text _n "══════════════════════════════════════════════════════════"
di as text    " Analysis complete. Outputs saved to: $out"
di as text    "══════════════════════════════════════════════════════════"
di as text    " Datasets:  prams22_master.dta / .csv"
di as text    " Figures:   fig1_dep_bar.png"
di as text    "            fig2_dep_forest.png"
di as text    "            fig3_scatter_dep_ins.png"
di as text    "            fig4_matrix.png"
di as text    "            fig5_coefplot.png"
di as text    "            fig6_fit_vs_obs.png"
di as text    "            fig7_residuals.png"
di as text    " Log:       prams_2022_analysis.log"
di as text    "══════════════════════════════════════════════════════════"


**Regression results — the key story:**

*The hypothesized direct effect of pre-pregnancy uninsurance on depression is **not statistically significant** in any model, and notably shrinks toward zero (then reverses sign) as confounders enter. Two findings stand out instead:

*1. **Smoking is the dominant predictor.** A 1 percentage-point higher state smoking rate is associated with ~0.93 pp higher depression rate (p<0.001). This likely reflects a shared socioeconomic gradient — states with high smoking prevalence among pregnant women also face concentrated poverty, rural isolation, and limited mental health infrastructure.

*2. **Medicaid coverage is protective.** A 1 pp higher Medicaid share before pregnancy is associated with −0.26 pp lower depression (p<0.001), consistent with the idea that public insurance provides access to mental health services that reduce untreated depression.

**Bottom line:** The original hypothesis (uninsurance → higher depression) is not supported at the state level. The more nuanced story is that **smoking behavior** (as a socioeconomic proxy) is the primary driver of cross-state variation in pre-pregnancy depression, and **Medicaid coverage** independently buffers against it — a finding that actually reinforces the Medicaid expansion results from Part 1. Together the two analyses suggest expanding public coverage matters both for insurance enrollment and, through access, for maternal mental health.

