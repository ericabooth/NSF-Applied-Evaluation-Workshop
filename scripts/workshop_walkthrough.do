*==============================================================================*
* TITLE: workshop_walkthrough.do
* AUTHOR: Eric A. Booth
*==============================================================================*

**this will install packages needed for this work:
foreach j in csdid drdid estout coefplot statplot sparkta usepackage webdoc {
cap which `j'
if _rc ssc install csdid , replace
}
 
*--------------------------------------------------------------------
**# Example 1: Medicaid Expansion Analysis
**! PURPOSE: Student walkthrough for Medicaid Expansion Analysis

**## Load Data
cd `"/Users/ericbooth/Documents/PVAMU_NSF_Workshop_2026/scripts/"' //change to your folder!
use "medicaid_workshop_data.dta", clear

**## Descriptive Stats
lab def gvar 0 "Never" 2014 "Early(2014)" 2016 "Mid(2016)" 2019 "Late(2019)", modify
lab value gvar gvar
lab var gvar "Expansion Status"

tabstat insured_rate, by(gvar)
tabulate year gvar, summarize(insured_rate) 

**simple before and after:
summarize insured_rate pp_depress_rate if year == 2010
summarize insured_rate pp_depress_rate if year == 2020
tw  (lfitci  pp_depress_rate  insured_rate, color(*.66)) (scatter   pp_depress_rate insured_rate, mcolor(blue)),ytit(Postpartum Depression Rate) leg(off)
gr export "fig0.png", replace


**Summary: statplots**
statplot insured_rate pp_depress_rate , over(gvar) 
gr export "fig1.png", replace
preserve
lab var insured "."
statplot insured_rate , over(year)  blabel(bar, format(%2.1f) size(vsmall)) by(gvar, row(2)) xsize(8) plotregion(margin(zero)) graphregion(margin(zero))  name(Summary, replace) xpose
gr export "fig2.png", replace
restore

**Dashboard: sparkta**
decode gvar, g(gvar2)
g combo =  string(year)   + " -- " + gvar2
sparkta insured_rate ,  by(gvar) layout(grid)  over(year) filters(state    gvar  )  type(hbar) gradient download title(Medicaid expansion) sliders(pp_depress_rate) xrange(0 1) xline(0.25) linewidth(15) datalabels offline  //   export(`"`c(pwd)'/medicaidsummary.html"')

**Descriptives.** Pre-expansion (2010–2013), all four groups had virtually identical postpartum insurance rates (~64–67%), strongly consistent with the parallel trends assumption. After expansion, treated groups diverge sharply from never-expanders.

**Pre-treatment placebo periods (parallel trends check).** For G2014 and G2016, all pre-treatment group-time ATTs are near zero and statistically insignificant — excellent evidence that the parallel trends assumption holds for these cohorts. G2019 shows one marginally significant pre-period coefficient (t_2010_2011 = −0.027, p=0.012), though this isolated violation across 8 pre-periods is unlikely to be consequential.


**## Run Modern DiD (Callaway & Sant'Anna)

* ivar: panel id (state)
* time: time variable (year)
* gvar: year of treatment (0 if never)

csdid insured_rate, ivar(state) time(year) gvar(gvar) method(dripw)
  * dripw methodSant'Anna and Zhao (2020) doubly robust DiD estimator based on stabilized inverse probability weighting & ordinary least squares.

*  DID Aggregate Effects
* Simple average
estat simple

* Group-time average
estat group

* Event Study Visual
csdid_plot, title("Postpartum Insurance: Event Study") name(DID, replace)

**Export clean Table
estat simple
estimates store main_res
 


**Treatment effects.** Each cohort shows a large, immediate, and sustained jump in postpartum insurance rates in the year of expansion:

/*
| Cohort | Year of jump | ATT at expansion | Still sustained by 2020 |
|---|---|---|---|
| G2014 | 2013→2014 | +11.5 pp (p<0.001) | ~+12.0 pp |
| G2016 | 2015→2016 | +12.4 pp (p<0.001) | ~+13.3 pp |
| G2019 | 2018→2019 | +9.6 pp (p<0.001) | ~+11.4 pp |
*/

**Aggregate ATT = +11.8 percentage points** (SE=0.004, z=28.16, p<0.001, 95% CI: 11.0–12.7 pp). This is the headline result: across all treated states, Medicaid expansion raised postpartum insurance coverage by roughly 12 percentage points — a large, precise, and durable effect. Group-level averages are tightly clustered (10.5–12.9 pp), indicating consistent effects regardless of when a state expanded.

 

 




 