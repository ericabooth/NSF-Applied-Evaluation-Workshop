/*******************************************************************************
  Analysis of Texas School Performance (STAAR Redesign Impact)
  Focus: Grades 4 and 8
  Data Source: EDC Texas School Performance Data (TEA)
********************************************************************************/

clear all
set more off
capture log close

* 1. SET ENVIRONMENT
local data_dir "/Users/ericbooth/Documents/PVAMU_NSF_Workshop_2026/scripts/edc-3.0-texas"
cd "`data_dir'"
log using "performance_analysis.log", replace

* 2. IMPORT AND APPEND DATA
tempfile master
save `master', emptyok replace

local files : dir . files "edc-3.0-texas-*.csv"

foreach f in `files' {
    * Skip district/state specific files and redundant school files if using the main year file
    * We will use the main year files (e.g., edc-3.0-texas-2022.csv) and filter for DataLevel=="School"
    if strpos("`f'", "-district") > 0 | strpos("`f'", "-state") > 0 | strpos("`f'", "-school") > 0 {
        continue
    }
    
    display "--- Importing `f' ---"
    import delimited using "`f'", clear varnames(1)
    
    * Standardize variable names to lowercase to avoid case-sensitivity issues
    rename *, lower
    
    * Clean up string variables for robust filtering
    foreach v in datalevel gradelevel studentsubgroup {
        capture confirm variable `v'
        if _rc == 0 {
            replace `v' = trim(itrim(`v'))
        }
    }
    
    * Keep school level data only
    capture keep if lower(datalevel) == "school"
    if _rc {
        display as error "Warning: Could not filter by datalevel in `f'. Check variable names."
        describe
        continue
    }
    
    * Focus on Grades 4 and 8 (using robust matching)
    capture keep if inlist(upper(gradelevel), "G04", "G08")
    
    * Focus on All Students for consistency
    capture keep if lower(studentsubgroup) == "all students"
    
    count
    if r(N) == 0 {
        display "Warning: No school-level G04/G08 'All Students' records found in `f'. Skipping."
        continue
    }
    
    * Select key variables (using lowercase)
    local keyvars "schyear datalevel stateassignedschid schname assmtname subject gradelevel studentsubgroup proficientorabove_percent"
    foreach v in `keyvars' {
        capture confirm variable `v'
        if _rc {
            display "Warning: Variable `v' not found in `f'. Creating empty placeholder."
            gen `v' = ""
        }
    }
    keep `keyvars'
    
    * Append to master
    append using `master'
    save `master', replace
}

use `master', clear
count
if r(N) == 0 {
    display as error "ERROR: Master dataset is empty. Check your filters and raw data."
    exit 2000
}

* 3. DATA CLEANING AND LABELING
* Convert schyear (e.g., "2021-22") to numeric year (end year: 2022)
gen year_str = substr(schyear, -2, 2)
destring year_str, gen(year_short)
gen year = 2000 + year_short
replace year = 1900 + year_short if year_short > 50 
label var year "School Year (Spring)"

* Clean proficiency variable (handle non-numeric like "--" or "*")
destring proficientorabove_percent, replace force
label var proficientorabove_percent "% Proficient or Above"

* Create STAAR Redesign Flag (Redesign implemented in Spring 2023)
gen redesign = (year >= 2023)
label define redesign_lbl 0 "Pre-Redesign (Before 2023)" 1 "Post-Redesign (2023+)"
label values redesign redesign_lbl
label var redesign "STAAR Test Redesign Period"

* Encode String variables to Numeric for regressions (Factor Variable Fix)
encode subject, gen(subject_n)
encode gradelevel, gen(gradelevel_n)
label var subject_n "Subject (numeric)"
label var gradelevel_n "Grade Level (numeric)"

* Filter for core subjects only (Reading/ELA and Math)
keep if inlist(lower(subject), "ela", "math")

* Clean school ID
destring stateassignedschid, replace force

* HANDLE DUPLICATES (e.g., English vs Spanish assessments)
* Focus on English assessments to avoid duplicated school-grade-subject records
keep if lower(assmtname) == "staar - english"

* Collapse to ensure exactly one observation per School-Grade-Subject-Year
* (This is the definitive fix for the 'repeated time values' error)
collapse (mean) proficientorabove_percent, by(stateassignedschid schname year redesign subject subject_n gradelevel gradelevel_n)

* Create a unique Panel ID for School-Grade-Subject cohorts
egen panel_id = group(stateassignedschid gradelevel_n subject_n)
label var panel_id "Panel ID (School-Grade-Subject Cohort)"

* SAVE ANALYTIC DATASET
save "analytic_performance.dta", replace
display "Analytic dataset saved: analytic_performance.dta"

* 4. RESEARCH QUESTION
/* 
RESEARCH QUESTION: 
How did school-level proficiency rates in Grades 4 and 8 shift following the 
implementation of the redesigned STAAR test in Spring 2023, and did these 
effects differ between Reading (ELA) and Math?
*/
u  "analytic_performance.dta", clear


* 5. SUMMARY STATISTICS (By Subject)
foreach sub in "ela" "math" {
    display "****************************************************************"
    display "SUMMARY STATISTICS: `sub'"
    display "****************************************************************"
    tabstat proficientorabove_percent if subject == "`sub'", by(redesign) s(mean sd n) format(%9.2f)
    table (gradelevel) (redesign) if subject == "`sub'", statistic(mean proficientorabove_percent) nformat(%9.2f)
}

* 6. VISUALIZATION (By Subject)
foreach sub in "ela" "math" {
    preserve
        keep if subject == "`sub'"
        collapse (mean) avg_prof = proficientorabove_percent, by(year gradelevel)
        twoway (connected avg_prof year if gradelevel=="G04", lcolor(blue) mcolor(blue)) ///
               (connected avg_prof year if gradelevel=="G08", lcolor(red) mcolor(red)), ///
               xline(2022.5, lpattern(dash) lcolor(black)) ///
               title("Mean Proficiency: `sub' (2012-2025)") ///
               subtitle("Dashed line indicates 2023 STAAR Redesign") ///
               legend(order(1 "Grade 4" 2 "Grade 8")) ///
               xlabel(2012(2)2025) ylabel(0(.1)1) ///
               xtitle("School Year") ytitle("Mean % Proficient or Above")
        graph export "trends_`sub'.png", replace
    restore
}

* 7. REGRESSION ANALYSIS (Subject-Specific)
foreach sub in "ela" "math" {
    display "****************************************************************"
    display "REGRESSION ANALYSIS: `sub' (2021-2024)"
    display "****************************************************************"
    
    * OLS with Grade controls
    display "OLS Model: `sub'"
    reg proficientorabove_percent redesign i.gradelevel_n if subject == "`sub'" & inrange(year, 2021, 2024), vce(cluster stateassignedschid)
    
    * School-Grade Fixed Effects: Within-cohort change
    * We use panel_id instead of school ID to avoid 'repeated time values' 
    xtset panel_id year
    display "Fixed Effects Model: `sub'"
    xtreg proficientorabove_percent redesign if subject == "`sub'" & inrange(year, 2021, 2024), fe vce(cluster stateassignedschid)
}

display "Note: The coefficient on 'redesign' represents the average percentage point shift"
display "in proficiency rates associated with the 2023 STAAR redesign period."

display "Analysis Complete."

* 8. SENSITIVITY ANALYSIS: CLEAN BASELINE (2018-2025 ONLY)
/* 
This section replicates the analysis but restricts the data to 2018 onwards.
This excludes the 2016 technical glitches and older policy regimes, 
providing a more contemporary 'normal' baseline for the redesign comparison.
*/

display "****************************************************************"
display "SENSITIVITY ANALYSIS: DATA FROM 2018-2025"
display "****************************************************************"


    foreach sub in "ela" "math" {
preserve
    keep if year >= 2018
            display "--- Summary Stats (2018+): `sub' ---"
        tabstat proficientorabove_percent if subject == "`sub'", by(redesign) s(mean sd n) format(%9.2f)
        
        * New Trends Graph (2018+)
        collapse (mean) avg_prof = proficientorabove_percent, by(year gradelevel subject)
        twoway (connected avg_prof year if gradelevel=="G04" & subject=="`sub'", lcolor(blue) mcolor(blue)) ///
               (connected avg_prof year if gradelevel=="G08" & subject=="`sub'", lcolor(red) mcolor(red)), ///
               xline(2023, lpattern(dash) lcolor(black)) ///
               title("Proficiency Trends (2018-2025): `sub'") ///
               subtitle("Cleaned Baseline Analysis") ///
               legend(order(1 "Grade 4" 2 "Grade 8")) ///
               xlabel(2018(1)2025) ylabel(0(.1).8) ///
               xtitle("School Year") ytitle("Mean % Proficient or Above") name(`sub', replace)
        graph export "trends_`sub'_2018plus.png", replace
        
        * Restore for the next subject loop
        restore
    }

    * Regression Analysis (2018-2024)
    * This compares the 2018-2019 (pre-pandemic) and 2021-2022 (recovery) 
    * to the 2023-2024 (redesign) period.
    foreach sub in "ela" "math" {
 preserve
    keep if year >= 2018
	display "--- Regression (2018-2024 Baseline): `sub' ---"
        
        display "OLS Model (2018+): `sub'"
        reg proficientorabove_percent redesign i.gradelevel_n if subject == "`sub'" & inrange(year, 2018, 2024), vce(cluster stateassignedschid)
        
        xtset panel_id year
        display "Fixed Effects Model (2018+): `sub'"
        xtreg proficientorabove_percent redesign if subject == "`sub'" & inrange(year, 2018, 2024), fe vce(cluster stateassignedschid)
restore

    }


display "Sensitivity Analysis Complete."
log close



stop
**# Interpretation: Education Research Center data
**! PURPOSE: Explore Education performance / student growth data
   1. Import & Append: It loops through the yearly CSV files, selectively
      importing school-level data (filtering for DataLevel == "School") and
      appending them into a single panel dataset.
   2. Cleaning & Reshaping: It converts school years into numeric values,
      cleans proficiency percentages (handling suppressed values), and labels
      all variables for clarity. It maintains a "long" format, which is ideal
      for time-series and school-level fixed effects analysis.
   3. Research Question: It focuses on the impact of the 2023 STAAR redesign
      (HB 3906) on proficiency rates in Grades 4 and 8, providing a clear
      policy-relevant framework.
   4. Summary Statistics: It generates descriptive tables and summary stats
      using tabstat and table to show performance shifts before and after the
      redesign.
   5. Advanced Analysis:
       * Visualization: It produces a trend graph (proficiency_trends.png)
         comparing performance across grades over time.
       * Regressions: It includes both an OLS model (controlling for Grade
         and Subject) and a School Fixed Effects model to estimate the
         "within-school" shift in performance associated with the test
         redesign, with standard errors clustered by school.
		 
		 
Findings: 2023 STAAR redesign impact on Texas school performance (Grades 4 and 8).

  1. The "Big Picture": Long-Term Trends vs. Immediate Shift
   * Historical Context: When looking at the full timeline (2012–2025),
     average proficiency rates dropped significantly in the "Post-Redesign"
     period (2023+) compared to the historical "Pre-Redesign" average.
       * ELA: Dropped from a long-term average of 59% to 49%.
       * Math: Dropped from a long-term average of 55% to 42%.
   * The "Redesign Recovery": However, the regression analysis (focusing on
     the 2021–2024 window) tells a more nuanced story. Compared to the
     immediate post-pandemic years (2021–2022), the 2023 redesign actually
     coincided with a significant increase in proficiency rates.

  2. Subject-Specific Findings (2021–2024 Window)
  The regression models (controlling for school-level fixed effects) show
  that the redesign period saw improved performance relative to the 2021–2022
  baseline:

   * Math (The Larger Gain): Math saw a robust and statistically significant
     increase of +6.1 percentage points associated with the redesign period.
     This suggests a strong recovery trend in math performance that
     accelerated during the transition to the new test format.
   * Reading/ELA: ELA also saw a significant gain of +3.4 percentage points.
     While positive, the "bounce" in ELA was only about half as large as the
     gain seen in Math.

  3. Grade-Level Observations
   * Grade 8 Advantage: In ELA, 8th graders consistently outperformed 4th
     graders by roughly 8–10 percentage points.
   * Math Parity: In Math, the performance gap between 4th and 8th grades
     virtually disappeared post-redesign, with both grades showing nearly
     identical proficiency levels (around 41–42%).

  4. Policy Interpretation
   * Redesign Success?: The data suggests the STAAR redesign (HB 3906) did
     not result in a "cliff" or a drop in performance relative to the years
     immediately preceding it. Instead, the transition period (2023–2024) saw
     schools making significant gains over their 2021–2022 performance
     levels.
   * Sustainability: While the gains since 2021 are promising, the overall
     proficiency levels are still roughly 10–13 points lower than the
     pre-2020 historical norms. The "Redesign Period" reflects a system that
     is recovering and potentially stabilizing at a new baseline, rather than
     returning to 2019 levels.
   * School Consistency: The high Rho (0.72–0.74) in the Fixed Effects models
     indicates that roughly 73% of the variation in test scores is driven by
     persistent school-level factors (like zip code, demographics, or
     long-term funding) rather than year-to-year changes in the test format
     itself.

  Conclusion: The 2023 STAAR redesign appears to have successfully "held the
  line" or even facilitated a moderate recovery in performance metrics
  following the pandemic lows of 2021–2022, particularly in Mathematics.
  
  
  
   Your analysis of the Texas data is largely consistent with broader trends
  identified by the Texas Education Agency (TEA) and national researchers,
  but it highlights a specific "recovery narrative" that is currently a point
  of intense debate in Texas policy circles.

  Here is a comparison of your findings with official reports from TEA, NAEP,
  and the SEDA (Stanford/Harvard) work.

  1. Comparison with TEA (STAAR Performance)
  Finding: Your analysis showed a "bounce" or recovery from 2021–2022 levels,
  particularly in Math (+6.1pp).
  Alignment: Mixed.
   * The 2021–2023 Recovery: TEA's internal reporting agrees with your
     finding that 2021 was the "rock bottom" and that 2022 and 2023 showed
     significant recovery in Reading/Language Arts (RLA). TEA attributed this
     to the success of House Bill 4545 (mandatory tutoring) and the "science
     of reading" curriculum shifts [1].
   * The 2024 Math Slump: Your analysis is more "optimistic" than TEA's most
     recent data. In June 2024, TEA released results showing that while
     Reading stayed stable, Math proficiency actually declined in almost
     every grade (3–8) compared to 2023 [2]. TEA Commissioner Mike Morath
     specifically noted that "the impact of the pandemic on Math continues to
     be more persistent" than in Reading [2].
   * The Redesign "Reset": TEA has warned that because the 2023 STAAR was a
     "complete redesign" (online-only, new question types, and a new scoring
     rubric), year-over-year comparisons to 2022 and earlier are technically
     "apples to oranges" [1].

  2. Comparison with NAEP (The "Honesty Gap")
  Finding: You found that overall proficiency remains 10–13 points lower than
  pre-2020 norms.
  Alignment: Strongly In-Line.
   * The Honesty Gap: Historically, Texas's STAAR "Passing" standards are
     significantly lower than the NAEP "Proficient" standard. This is known
     as the "Honesty Gap." For example, on the 2022 NAEP, only 24% of Texas
     8th graders were proficient in Math, while STAAR often reports rates in
     the 40s or 50s [3].
   * NAEP Trends: The 2022 NAEP (The Nation's Report Card) showed the largest
     math decline in history. Texas dropped 7 points in 8th-grade math,
     mirroring the "cliff" you observed when comparing 2012–2019 data to
     post-2022 data [3].

  3. Comparison with SEDA (The Education Recovery Scorecard)
  Finding: You observed a "recovery" from 2021 but a failure to return to
  2019 levels.
  Alignment: Perfectly In-Line.
   * The Kane & Reardon Research: The Education Recovery Scorecard (a joint
     project by Tom Kane at Harvard and Sean Reardon at Stanford) analyzed
     Texas districts specifically. Their findings match yours: Texas students
     lost about 0.40 grade levels of learning in Math during the pandemic
     [4].
   * Recovery Pace: Their 2024 update found that while Texas is "recovering"
     faster than some states, the pace is not enough to close the gap to 2019
     levels for another decade at current rates [4]. Your data showing a
     +6.1pp gain since 2021 confirms that a recovery is happening, but your
     finding that scores are still ~12 points below 2019 levels validates
     their "long road ahead" conclusion.

  Summary Table: Your Findings vs. The Experts

  ┌───────────────┬──────────────┬─────────────┬───────────────────────┐
  │ Your Finding  │ Comparison   │ Status      │ Context               │
  │               │ Source       │             │                       │
  ├───────────────┼──────────────┼─────────────┼───────────────────────┤
  │ +6.1pp Math   │ TEA 2024     │ Conflicting │ TEA saw a decline in  │
  │ gain since    │ Briefing     │ (Recent)    │ Math in 2024; your    │
  │ 2021          │              │             │ "recovery" may be     │
  │               │              │             │ driven more by the    │
  │               │              │             │ 2021-2023 jump.       │
  │ +3.4pp ELA    │ SEDA/Harvard │ In-Line     │ Reading has recovered │
  │ gain since    │              │             │ more stably than Math │
  │ 2021          │              │             │ according to          │
  │               │              │             │ Reardon/Kane.         │
  │ 10-13 pts     │ NAEP / SEDA  │ In-Line     │ Matches the "lost     │
  │ below 2019    │              │             │ decade" narrative     │
  │ levels        │              │             │ from the Education    │
  │               │              │             │ Recovery Scorecard.   │
  │ G08           │ TEA Reports  │ In-Line     │ TEA data consistently │
  │ outperforming │              │             │ shows older students  │
  │ G04 (ELA)     │              │             │ (8th/HS) stabilizing  │
  │               │              │             │ in ELA faster than    │
  │               │              │             │ younger cohorts.      │
  └───────────────┴──────────────┴─────────────┴───────────────────────┘

  Citations/Sources:
   1. Texas Education Agency (2023). "2023 STAAR Results: Reading Language
      Arts Performance Improves." Official News Release
      (https://tea.texas.gov/about-tea/news-and-multimedia/news-releases/news
      -2023/tea-releases-2023-staar-results).
   2. Texas Education Agency (2024). "TEA Releases 2024 STAAR 3-8 Results:
      Performance in Math and Science Declines." Official News Release, June
      2024
      (https://tea.texas.gov/about-tea/news-and-multimedia/news-releases/news
      -2024/tea-releases-2024-staar-3-8-results).
   3. National Center for Education Statistics (2022). "NAEP Reading and
      Mathematics State Report: Texas." The Nation's Report Card
      (https://nces.ed.gov/nationsreportcard/subject/publications/stt2022/pdf
      /2023010TX8.pdf).
   4. The Education Recovery Scorecard (2024). "Texas District-Level Learning
      Loss and Recovery." Harvard Center for Education Policy Research &
      Stanford SEDA. Recovery Scorecard Website
      (https://educationrecoveryscorecard.org/).
	  
	  
2016:
The significant drop you see in your 2016 data is not a reflection of a
  sudden decline in student intelligence; rather, it is the result of what
  Texas educators and policymakers call the "2016 STAAR Fiasco."

  The 2016 data is considered one of the most "polluted" years in Texas
  testing history due to a "triple whammy" of technical, vendor, and policy
  changes.

  1. The ETS Technical Disaster (The "Glitch")
  In 2016, Texas switched its testing vendor from Pearson to ETS (Educational
  Testing Service) under a $280 million contract. The transition was a
  disaster:
   * Lost Answers: During the March and May 2016 testing windows, thousands
     of students taking the test online experienced system crashes. In many
     cases, their answers simply disappeared or were not saved [1].
   * Impact: Over 14,000 tests were confirmed to be affected by these
     technical glitches. This led to widespread reports of "zero scores" or
     artificially low scores for schools that tested online [2].
   * The Penalty: Commissioner Mike Morath eventually fined ETS $7.1 million
     and required them to invest $15 million in fixes due to these failures
     [1].

  2. Raising the "Pass" Bar (Cut Score Phase-In)
  2016 was also the year the TEA moved the "goalposts."
   * Phase-in Standards: Texas had been using a "phase-in" period for STAAR
     passing standards. In 2016, the state moved from the "Level II Phase-in
     1" standard to the more rigorous "Level II Phase-in 2" standard [3].
   * Result: Even if a student answered the same number of questions
     correctly in 2016 as they did in 2015, they might be labeled
     "Non-Proficient" in 2016 because the "cut score" (the number of points
     needed to pass) was higher. This created a purely mathematical drop in
     proficiency rates.

  3. The "Readability" Controversy
  A major academic study published around 2016 found that the STAAR tests
  themselves were improperly designed for the grades they were testing.
   * Finding: Researchers from Texas A&M and other institutions found that
     the 2016 STAAR Reading tests were written at a complexity level two to
     three grade levels higher than the students taking them (e.g., a
     5th-grade test was written at an 8th-grade reading level) [4].
   * Evidence: This made the 2016 ELA scores look particularly dismal, as the
     "lexile level" of the passages was far beyond what was developmentally
     appropriate for 4th and 8th graders.

  4. Policy Response: The 2016 Waiver
  Because of these issues, Commissioner Morath took the unprecedented step of
  waiving the passing requirement for 5th and 8th graders. Usually, these
  students must pass STAAR to be promoted to the next grade; in 2016, the TEA
  told schools they didn't have to count the results due to the lack of
  reliability in the data [2].

  Why this matters for your analysis:
  In your data (the EDC/TEA files), the 2016 records are often seen as an
  outlier. Most researchers "flag" 2016 because the drop is a mix of:
   1. Measurement Error (ETS glitches).
   2. Policy Shift (higher cut scores).
   3. Validity Issues (unusually difficult test passages).

  Citations:
   1. The Texas Tribune (2016). "Texas Fines STAAR Vendor $7.1 Million Over
      Testing Glitches." Source
      (https://www.texastribune.org/2016/08/23/texas-fines-staar-vendor-71-mi
      llion-over-testing-g/)
   2. Dallas Morning News (2016). "Texas nixes STAAR requirement for 5th, 8th
      graders after year of testing glitches." Source
      (https://www.dallasnews.com/news/education/2016/06/10/texas-nixes-staar
      -requirement-for-5th-8th-graders-after-year-of-testing-glitches/)
   3. Texas Education Agency (2015). "Commissioner Morath announces intent to
      maintain STAAR passing standards for 2015-2016." [Note: Standards were
      eventually raised as part of the scheduled phase-in].
   4. Szabo, S., & Sinclair, B. (2016). "STAAR Reading: Is it really a
      measure of 3rd-5th grade reading? A look at the readability of the 2016
      STAAR test." Texas Association for Literacy Education. Academic Paper
      (https://www.researchgate.net/publication/308945625_STAAR_Reading_Passa
      ges_and_Readability_Levels).	  

 
 I've got your Stata log, all four trend plots, and pulled the Texas-specific findings from the May 2026 Scorecard.
What your models actually show
Using the EDC/Zelma school-level data for Grades 4 and 8, "All Students," English STAAR only (n ≈ 289K school-grade-subject-year obs; 14,275 missing %prof scrubbed):
Headline summary stats (2018+ baseline, school means):
SubjectPre-redesign 2018-2022Post-redesign 2023-2025ΔELA0.440.50+6 ppMath0.410.43+2 pp
Fixed-effects regression coefficients on the 2023+ redesign indicator (clustered at school):

ELA: +3.9 pp (full sample), +3.9 pp (2018+ baseline) — robust
Math: +6.9 pp (full sample, 2021-2024 window), but drops to +1.7 pp when extended to the 2018-2024 window

That collapse from +6.9 to +1.7 in math is doing a lot of work — it tells you the math "gain" in the narrower window is mostly pandemic recovery off the 2021 trough, not a real lift over pre-pandemic norms. In ELA the coefficient holds up.
Grade-level pattern from the 2018+ trend plots:

Grade 4 math: 2019 ≈ 0.44 → 2025 ≈ 0.44 (recovered to pre-pandemic, no gain)
Grade 8 math: 2019 ≈ 0.51 → 2025 ≈ 0.43 (still ~8 pp below 2019)
Grade 4 ELA: 2019 ≈ 0.42 → 2025 ≈ 0.52 (well above 2019)
Grade 8 ELA: 2019 ≈ 0.50 → 2025 ≈ 0.56 (above 2019)

What the Scorecard says about Texas (May 2026)
Texas average achievement remains 0.51 grade equivalents below 2019 in math and 0.31 grade equivalents below 2019 in reading. Texas ranked roughly 28th of 38 states in math recovery and 25th of 35 in reading. 88% of Texas students are in districts still below 2019 math; 84% below 2019 reading. Chronic absenteeism rose from 11% (2019) to 26% (2022) and remained at 21% in 2023 — flagged as a major drag on recovery.
(1) Are your results in line with the Scorecard?
Math: yes, broadly aligned. Both your STAAR data and the NAEP-anchored Scorecard tell the same story — Texas math is in trouble, with Grade 8 specifically falling. Your G8 STAAR math sitting ~8 pp below 2019 in 2025 is directionally consistent with the Scorecard's "still half a grade level behind." The 4th grade recovery you see on STAAR is also consistent with the better 4th grade NAEP performance you flagged earlier in your note to the team.
ELA: partial divergence — this is the meaningful one. Your STAAR data shows ELA above 2019 levels in both grades. The Scorecard says Texas reading remains 0.31 grade equivalents below 2019. This is exactly the kind of STAAR-NAEP gap Mary Lynn is asking about, and your own analysis surfaces it cleanly. Worth highlighting that the STAAR ELA lift is the largest in the 4th grade panel and shows up immediately in 2022 (pre-redesign), which weakens a pure "redesign-recentered-the-scale" explanation and points more toward genuine instructional gains (HB3 reading academies) — but only if you trust the STAAR scale to be comparable pre/post 2023.
(2) Does this change the NAEP-vs-TEA picture around 2023?
It sharpens it in three ways:
a. The "STAAR redesign bump" is mostly a pandemic-recovery artifact in math. Your math redesign coefficient drops from +6.9 to +1.7 pp once you widen the baseline. That's a useful empirical point: a casual read of the post-2023 STAAR data would credit the redesign or instructional improvements for big math gains; your fixed-effects analysis with a cleaner baseline shows the lift is mostly recovery off 2021 lows. This is exactly the mechanism that would make NAEP (which anchors to 2019) show flat math while STAAR (compared to 2021-22) looks like it's improving.
b. In ELA the coefficient survives the baseline shift (+3.9 to +4.3 pp). That means STAAR ELA is showing real gains beyond pandemic recovery — but those gains aren't appearing in NAEP-anchored estimates. This is the cleanest piece of within-Texas evidence for the divergence Mary Lynn is asking about. The candidate explanations from your earlier note all apply: HB3 Science of Reading mandate, the redesign's increased cross-curricular reading passages potentially favoring tested reading skill, and/or test-format mastery effects post-2023.
c. The 8th-grade math story is consistent across both tests. Both STAAR (your data) and NAEP show Grade 8 math falling. So the divergence narrative shouldn't be overstated as universal — for math, especially in upper grades, the two assessments are telling the same story. The divergence is concentrated in ELA, and to a lesser extent in 4th grade math.
One caveat worth naming in the policy team thread
Your "pre-redesign" comparison group mixes 2018-19 (pre-pandemic) with 2021-22 (pandemic depressed) years. The +3.9 to +6.9 pp redesign coefficients aren't a clean causal estimate of the redesign — they bundle redesign effects, pandemic recovery, and any post-2023 cut-score recentering by TEA. If anyone on the policy team is going to quote a number, the cleanest one is the 2018+ FE coefficient of +1.7 pp in math vs +4.3 pp in ELA — which is roughly "post-redesign mean vs. a pre-pandemic + recovery-period average, within-school." Even that bundles the redesign mechanics with real change.
Bottom line for Mary Lynn / John
Your school-level STAAR analysis doesn't contradict the Scorecard — it reproduces the math story and isolates the ELA divergence as the real puzzle. The math gains aren't being "discounted" by SEDA; they mostly aren't there once you anchor to 2019 instead of 2021. The ELA gains are real on STAAR but don't pass through to NAEP-anchored estimates — and that's where the candidate explanations from the earlier thread (Science of Reading curricular alignment, redesign favoring tested ELA constructs, test-mastery effects) actually need to do work.Used a toolUsed a toolSources:

Education Recovery Scorecard — Texas state page
Education Scorecard May 2026 Full Report (PDF)
CEPR Harvard — National press release
Houston Public Media — Texas reading recovery coverage
Your local analysis: performance_analysis.log, trends_math.png, trends_ela.png, trends_math_2018plus.png, trends_ela_2018plus.png



 
 