*==============================================================================*
* DOES PERCEIVED RISK PRECEDE PROTECTIVE ACTION?
* WITHIN-HOUSEHOLD EVIDENCE FROM A NATIONAL PANEL, 2021 TO 2024
*
* PANEL REPLICATION DO-FILE (Paper 2, companion to "Paying for Protection")
* Donta Council | Federal Reserve Bank of Atlanta
*
*------------------------------------------------------------------------------
* WHAT THIS FILE DOES
*   Runs the within-household (panel) analyses: conditional-logit fixed
*   effects, first differences, the Stata approximation to the random-
*   intercept cross-lagged panel model (RI-CLPM), and attrition checks, from
*   the pooled SHED dataset. The latent RI-CLPM itself is estimated in
*   python/riclpm_canonical.py, because Stata's sem cannot fit it.
*
* STATUS
*   Paper 2 is not yet drafted. The expected values printed in the section
*   headers are the results verified in Stata 14.2 for the combined study
*   (482 of 482 rows matched) and use the FIVE-ITEM disaster-impact measure.
*   Paper 1 now uses a FOUR-ITEM measure (see DATA NOTES). Set the switch in
*   STEP 1.10 to "four" when Paper 2 adopts it; expected values will then
*   need to be re-estimated.
*
* HOW TO RUN
*   1. Open Stata (release 14 or later).
*   2. Set the working directory to this stata/ folder:
*          cd "C:/path/to/perceived-risk-panel/stata"
*   3. Run:  do SHED_PANEL_REPLICATION.do   (this is the only file to run)
*   A full text log is written automatically to ../output/replication_log.txt
*
* HOW TO READ THIS FILE
*   Every block of code is preceded by a comment labeled STEP n.m that says,
*   in plain language, what the next lines do and what you should see. Lines
*   that begin with * are comments; Stata skips them. Read the STEP note, then
*   let the code run. You do not need to edit anything except, if necessary,
*   the cd path above and the impact-measure switch in STEP 1.10.
*
* BEFORE YOU START (checklist)
*   [ ] Stata 14 or later is open.
*   [ ] The working directory is this stata/ folder (type  pwd  to check).
*   [ ] The data/ folder next to stata/ contains
*       SHED_disaster_mitigation_2021_2024.dta.
*   [ ] No other do-file is running and no log is open (if unsure, type
*       log close _all).
*   Then type:  do SHED_PANEL_REPLICATION.do
*   Expected run time: under 10 minutes.
*
* MAP OF SECTIONS  (section numbers follow the combined study file, so each
* result can be traced back to the verified run)
*   Section 1             Load data, choose the impact measure, survey design
*   Section 4             Weighted prevalence by wave
*   Section 8             Within-person fixed effects (conditional logit)
*   Section 9             First-difference linear probability models
*   Section 11            RI-CLPM person-mean approximation, 2022-2024
*   Section 11b           RI-CLPM four-wave check, 2021-2024
*   Section 13            Attrition and balance
*   Section 16            Writes ../output/verification_estimates.csv
*
* WHAT TO SEND BACK FOR VERIFICATION
*   ../output/replication_log.txt and ../output/verification_estimates.csv
*
* DATA NOTES
*   N = 47,236 respondent-waves, SHED public-use files 2021-2024, pooled;
*   32,585 respondents, of whom a subset was recontacted in adjacent waves.
*     experience   recent disaster impact. The prepared dataset holds the
*                  five-item version (ND1_a-ND1_e). ND1_e changed meaning
*                  between 2022 and 2023 (injury or death of family or a
*                  close friend, then "other"), and in 2023-2024 the ND1 items
*                  followed a financial-impact screen (ND0). Because the panel
*                  models use change between waves, the 2022-2023 transition
*                  mixes real change with the change in question routing.
*     risk_perc    6 - ND2, so higher = greater expected increase in disaster
*                  likelihood over five years.
*     SEW          z(mean of z(B2), z(B3)).
*     income_z     z(inc_4cat_50k), harmonized across waves.
*     assets_z     z(EF1 + BK1 + liq + has_card): financial resources and
*                  credit access.
*     debt_z       z(cc_bal + SL1 + EF3_b), cc_bal = 1 if C4A > 0.
*     owner        1 if pprent indicates ownership.  age_z = z(ppage).
*
* REPRODUCIBILITY
*   Estimates are deterministic; no seed is required. Record the Stata version
*   with -about- and keep the log alongside the manuscript.
*==============================================================================*

* STEP 0.1  Tell Stata to follow release 14 rules, clear anything left in
*           memory, and stop the Results window from pausing for --more--.
*           Nothing to change here.
version 14
clear all
set more off
set linesize 100

*------------------------------------------------------------------------------
* OUTPUT FOLDER
* Everything this file writes (the log, and any exported tables) goes to
* ../output/. The folder is created if it does not exist, so nothing needs to
* be set up by hand. If Stata cannot write there, edit OUTDIR below to any
* writable path.
*------------------------------------------------------------------------------
* STEP 0.2  Set the folder where results are written (../output) and test
*           that Stata can write there. If the test fails, results go to a
*           folder named output inside stata/ instead.
global OUTDIR "../output"
capture mkdir "$OUTDIR"
* Confirm the folder is writable; fall back to stata/output only if it is not.
tempname wt
capture file open `wt' using "$OUTDIR/_write_test.tmp", write replace
if _rc != 0 {
    global OUTDIR "output"
    capture mkdir "$OUTDIR"
}
else {
    file close `wt'
    erase "$OUTDIR/_write_test.tmp"
}
* STEP 0.3  Close any log left open from an earlier run, then start a text
*           log of everything below. This log is one of the two files to send
*           back for checking.
capture log close _all
capture log using "$OUTDIR/replication_log.txt", replace text
if _rc != 0 {
    di as error "Could not open a log in $OUTDIR. Edit the global OUTDIR near"
    di as error "the top of this file to a writable folder, then rerun."
}
* STEP 0.4  Print the output folder and working directory. If a warning
*           says the working directory is not the stata/ folder, type the cd
*           command it shows and run the file again.
di as text "Output folder: $OUTDIR"
di as text "Working directory: `c(pwd)'"
capture confirm file "../data/SHED_disaster_mitigation_2021_2024.dta"
if _rc != 0 {
    di as error _n "Note: the working directory is not the stata/ folder of this package."
    di as error "Results may be written somewhere other than the package output/ folder."
    di as error `"Recommended: type  cd "<path to the package>/stata"  and rerun."'
}

*------------------------------------------------------------------------------
* 1. LOAD, DECLARE THE SURVEY DESIGN, DEFINE MACROS
*------------------------------------------------------------------------------
* ---------------------------------------------------------------------------
* DATA SOURCE: resolved automatically. No need to choose a file to run.
*
*   Path A (build from raw). If the four public-use SHED CSVs are sitting in
*          this folder, the script imports them, constructs every analysis
*          variable from scratch, and saves the prepared dataset.
*   Path B (use prepared data). Otherwise it loads the .dta shipped in the
*          package. Both paths produce identical estimates.
*
* To force Path A, download public2021.csv through public2024.csv from
* federalreserve.gov/consumerscommunities/shed_data.htm into this folder.
* Path A documents the variable construction but has not been test-run
* against the raw CSVs; the verification run should use Path B (the
* prepared .dta), which is what the manuscript estimates were produced from.
* ---------------------------------------------------------------------------
* STEP 1.1  Name the prepared dataset this file will look for.
local DTA "SHED_disaster_mitigation_2021_2024.dta"

* --- Where is the data? -----------------------------------------------------
* Stata does NOT set the working directory to the do-file's folder, so this
* block searches the usual places instead of assuming. It looks in the current
* directory, one level up, every subfolder of the current directory, and the
* common download locations. If it still comes up empty it prints the exact
* cd command to use.
* ---------------------------------------------------------------------------
* STEP 1.2  Build the list of folders to search for the data (current
*           folder, its data/ subfolder, one level up, and common download
*           locations).
local FOUND ""
local RAWDIR ""

* Candidate folders to test, in order.
local cands `""`c(pwd)'" "`c(pwd)'/data" "`c(pwd)'/.." "`c(pwd)'/../data""'
foreach base in "~/Downloads" "~/Documents" "~/Desktop" {
    local cands `"`cands' "`base'" "`base'/data""'
    foreach pk in perceived-risk-panel Paper1_Supplementary_S1_Replication SocSci_Supplementary_S1_Replication ///
            SHED_Stata_Replication SHED_Journal_Submission_Prep {
        local cands `"`cands' "`base'/`pk'/data""'
    }
}

* Also scan one level of subfolders below the current directory.
capture local subs : dir "`c(pwd)'" dirs "*"
if _rc == 0 {
    foreach d of local subs {
        local cands `"`cands' "`c(pwd)'/`d'" "`c(pwd)'/`d'/data" "`c(pwd)'/`d'/stata""'
    }
}

* First pass: look for the prepared dataset. A copy only counts if it is the
* current version, which contains has_card (the four-item assets index).
* Older copies left elsewhere on the computer are reported and skipped.
* STEP 1.3  Search those folders for the prepared dataset. A copy only
*           counts if it contains has_card (the current index construction);
*           older copies are listed on screen and skipped.
local STALE ""
foreach p of local cands {
    if "`FOUND'" == "" {
        capture confirm file "`p'/`DTA'"
        if _rc == 0 {
            capture describe has_card assets_z using "`p'/`DTA'"
            if _rc == 0 local FOUND "`p'/`DTA'"
            else local STALE `"`STALE' "`p'/`DTA'""'
        }
    }
}
if `"`STALE'"' != "" {
    di as error _n "Skipped an older copy of the dataset that lacks has_card:"
    foreach s of local STALE {
        di as error "    `s'"
    }
    di as error "Delete or rename that copy to avoid confusion."
}

* Second pass: look for the four raw CSVs (only if no .dta turned up).
* STEP 1.4  If no prepared dataset was found, look for the four raw
*           public-use CSV files (public2021.csv to public2024.csv) instead.
if "`FOUND'" == "" {
    foreach p of local cands {
        if "`RAWDIR'" == "" {
            local ok = 1
            foreach y in 2021 2022 2023 2024 {
                capture confirm file "`p'/public`y'.csv"
                if _rc != 0 local ok = 0
            }
            if `ok' == 1 local RAWDIR "`p'"
        }
    }
}

* STEP 1.5  If neither was found, stop and print the cd command to use.
*           Nothing has been changed yet, so fix the folder and rerun.
if "`FOUND'" == "" & "`RAWDIR'" == "" {
    di as error _n "Could not locate a current copy of `DTA' or the raw public20XX.csv files."
    di as error "Current working directory is:"
    di as error "    `c(pwd)'"
    di as error _n "Fix: set the working directory to the folder holding the data, e.g."
    di as error `"    cd "~/Downloads/SHED_Journal_Submission_Prep/stata" "'
    di as error "then run this file again. In Stata you can also use"
    di as error "    File > Change Working Directory..."
    exit 601
}

* STEP 1.6  PATH B, the normal case: load the prepared dataset. If it sits
*           in a package data/ folder, switch to the matching stata/ folder so
*           results land in that package's output/ folder.
if "`FOUND'" != "" {
    di as text _n "PATH B: loading the prepared dataset."
    di as text "  `FOUND'"
    * If the dataset sits in a package's data/ folder and Stata was started
    * somewhere else, move to that package's stata/ folder so the log and
    * results land in the package's output/ folder.
    local ddir = subinstr("`FOUND'", "/`DTA'", "", 1)
    if regexm("`ddir'", "/data$") {
        local root = regexr("`ddir'", "/data$", "")
        capture confirm file "`root'/stata/SHED_PANEL_REPLICATION.do"
        if _rc == 0 & "`c(pwd)'" != "`root'/stata" {
            quietly cd "`root'/stata"
            capture log close
            global OUTDIR "../output"
            capture mkdir "$OUTDIR"
            capture log using "$OUTDIR/replication_log.txt", replace text
            di as text "Working directory set to the package stata/ folder:"
            di as text "  `c(pwd)'"
            di as text "Output folder: $OUTDIR"
        }
    }
    use "`FOUND'", clear
}
else {
    * STEP 1.7  PATH A, only if the raw CSVs were found: import each year,
    *           keep the analysis items, stack the four waves, and construct every
    *           analysis variable from scratch, then save the prepared dataset.
    di as text _n "PATH A: raw SHED CSVs found in `RAWDIR'. Building from source."
    local keep shedid weight weight_pop panel_weight ///
        ND4_a ND4_b ND4_c ND2 ND1_a ND1_b ND1_c ND1_d ND1_e ///
        B2 B3 EF1 BK1 EF3_h EF3_b C4A C2A SL1 inc_4cat_50k ///
        race_5cat ppgender ppeducat ppage pprent pphouse4 ppemploy ///
        ppstaten ppreg9 ppreg4 ppmsacat
    tempfile master
    local first = 1
    foreach y in 2021 2022 2023 2024 {
        import delimited using "`RAWDIR'/public`y'.csv", clear varnames(1) case(preserve)
        keep `keep'
        gen int year = `y'
        destring, replace
        if `first' == 1 {
            save `master', replace
            local first = 0
        }
        else {
            append using `master'
            save `master', replace
        }
    }
    use `master', clear

    * Disaster experience: 1 if ANY ND1 impact == 1, else 0. Respondents
    * screened out of the battery in 2023-2024 return 0, the intended coding.
    egen experience = anymatch(ND1_a ND1_b ND1_c ND1_d ND1_e), values(1)
    gen risk_perc = 6 - ND2
    gen liq    = 1 - EF3_h
    gen has_card = (C2A == 1) if !missing(C2A)
    gen cc_bal = (C4A > 0) if !missing(C4A)
    replace cc_bal = 0 if missing(C4A)

    egen zB2 = std(B2)
    egen zB3 = std(B3)
    gen  sew_raw = (zB2 + zB3)/2
    egen SEW = std(sew_raw)
    egen income_z = std(inc_4cat_50k)
    gen  assets_sum = EF1 + BK1 + liq + has_card
    egen assets_z   = std(assets_sum)
    gen  debt_sum = cc_bal + SL1 + EF3_b
    egen debt_z   = std(debt_sum)
    egen age_z = std(ppage)
    gen  owner = (pprent == 1)

    capture save "`RAWDIR'/`DTA'", replace
    if _rc == 0 di as text "Prepared dataset saved to `RAWDIR'."
}

* Sanity checks: the run should begin from 47,236 rows and 4 waves, and the
* dataset must contain every constructed variable the models use.
* STEP 1.8  Confirm the dataset has 47,236 respondent-waves across four
*           waves and every constructed variable. If an assert fails, Stata
*           stops here; the usual cause is an older copy of the dataset.
count
assert r(N) == 47236
tab year
capture confirm variable has_card assets_z debt_z SEW income_z liq cc_bal ///
    risk_perc experience owner age_z
if _rc != 0 {
    di as error _n "The dataset loaded is missing a required variable (an older copy)."
    di as error "Set the working directory to the stata/ folder of this package and rerun:"
    di as error `"    cd "<path to the package>/stata""'
    exit 111
}

* STEP 1.9  Create a numeric respondent identifier (pid) from shedid.
*           clogit and xtset need a numeric identifier to link the same
*           person across waves; shedid itself is still used by bysort and
*           reshape.
capture confirm string variable shedid
if _rc == 0 {
    egen long pid = group(shedid)
}
else {
    gen long pid = shedid
}
label var pid "Numeric respondent identifier (from shedid)"

* STEP 1.10 Choose the disaster-impact measure. Leave IMPACT as "five" to
*           reproduce the verified results printed in the section headers.
*           Change it to "four" to match Paper 1 (items ND1_a to ND1_d only);
*           the expected values in the headers will then no longer apply.
*           The summarize line shows weighted means near .12 (exp4) and .14
*           (exp5); experience equals whichever one you chose.
* Disaster-impact measure. "five" reproduces the verified combined-study
* results; "four" matches Paper 1 (ND1_a-ND1_d only).
local IMPACT "five"
capture drop exp5 exp4
gen byte exp5 = experience
gen byte exp4 = (ND1_a == 1 | ND1_b == 1 | ND1_c == 1 | ND1_d == 1)
if "`IMPACT'" == "four" {
    replace experience = exp4
}
else {
    replace experience = exp5
}
di as text "Disaster-impact measure in use: `IMPACT'-item"
summarize exp4 exp5 experience [aweight = weight_pop]

* STEP 1.11 Declare the survey design: population weight and clustering
*           on the respondent. The panel models below do not use it, but the
*           weighted descriptives in Section 4 do.
* svyset: population weight, clustered on the respondent identifier.
svyset pid [pweight = weight_pop]

* STEP 1.12 Store the six focal predictors and the covariate block in
*           globals, so every model uses identical lists.
* Focal predictors: threat appraisal (2) + economic position (4).
global econ  risk_perc experience SEW income_z assets_z debt_z

* Covariate block: demographics, housing, employment, and wave fixed effects.
global covar i.race_5cat i.ppgender i.ppeducat age_z owner ///
             i.pphouse4 i.ppemploy i.year

* STEP 1.13 Save a clean copy of the analysis file. Every section below
*           reloads it before keeping only the waves it needs.
* Keep a clean copy so later sections can reload after subsetting.
tempfile full
save `full', replace



*------------------------------------------------------------------------------
* VERIFICATION FILE
* Every headline number is also written, one row per estimate, to
*     ../output/verification_estimates.csv
* Send that file and ../output/replication_log.txt back for checking against
* the manuscript. Column meanings depend on the row type:
*   est   odds ratio (logits), percentage points (first differences),
*         probability in percent (margins), mean (descriptives), alpha,
*         correlation, VIF, SMD, or p-value, as named in -spec- and -predictor-
*   se    standard error of the coefficient on its estimation scale; for
*         descriptives the SD; for attrition the not-retained mean
*   lo/hi 95% interval on the same scale as est; for descriptives min/max
*   p     p-value where one applies
*   n     observations used in the model
*------------------------------------------------------------------------------
* STEP 1.14 Print the Stata version and open the verification file. Every
*           headline estimate is posted to it as one row, and it is exported as
*           a CSV in Section 16.
di as text "Stata version in use: " c(stata_version)
capture postclose VER
postfile VER str12 section str8 outcome str28 spec str32 predictor ///
    double(est se lo hi p n) using "$OUTDIR/verification_estimates", replace

* STEP 1.15 Define vfocal, a helper that, after each model, writes the
*           listed coefficients (estimate, SE, 95% interval, p, N) to the
*           verification file. The pp option reports first-difference
*           coefficients in percentage points. You do not run it yourself.
* vfocal: after an estimation command, post the listed coefficients.
*   eform  report exp(b) and exp(interval), for logit-family models
*   pp     report 100*b, for first-difference linear probability models
capture program drop vfocal
program define vfocal
    syntax , SECtion(string) OUTcome(string) SPec(string) Vars(string) [EFORM PP]
    local df = e(df_r)
    local n = e(N)
    if !missing(e(N_sub)) local n = e(N_sub)
    foreach v of local vars {
        capture local b = _b[`v']
        if _rc continue
        local s = _se[`v']
        if `s' == 0 | missing(`s') continue
        if missing(`df') {
            local crit = invnormal(0.975)
            local p = 2*normal(-abs(`b'/`s'))
        }
        else {
            local crit = invttail(`df', 0.025)
            local p = 2*ttail(`df', abs(`b'/`s'))
        }
        local lo = `b' - `crit'*`s'
        local hi = `b' + `crit'*`s'
        if "`eform'" != "" {
            local est = exp(`b')
            local lo  = exp(`lo')
            local hi  = exp(`hi')
        }
        else if "`pp'" != "" {
            local est = 100*`b'
            local lo  = 100*`lo'
            local hi  = 100*`hi'
        }
        else {
            local est = `b'
        }
        post VER ("`section'") ("`outcome'") ("`spec'") ("`v'") ///
            (`est') (`s') (`lo') (`hi') (`p') (`n')
    }
end


*------------------------------------------------------------------------------
* 4. WEIGHTED PREVALENCE BY WAVE (descriptive context for the panel)
*    Expected pooled prevalence: 12.8% relocation, 16.1% property,
*    5.1% insurance. Property rises 14.3% (2021) -> 18.5% (2023).
*    Experience 16.0 / 13.3 / 13.1 / 15.2 percent; perceived risk
*    3.41 / 3.36 / 3.37 / 3.36. Fragility: ~12% cannot cover $400,
*    ~45% no emergency fund, ~39% carry a card balance, ~73% homeowners.
*------------------------------------------------------------------------------
* STEP 4.1  Weighted share reporting each behavior and a recent impact,
*           and the mean expected-change score, by wave and pooled. These give
*           the panel results their descriptive context.
di _n(2) "=== TABLE 4: PREVALENCE BY WAVE ==="
foreach v in ND4_a ND4_b ND4_c experience risk_perc {
    di _n "--- `v' by wave ---"
    svy: mean `v', over(year)
    matrix M = e(b)
    local j = 0
    foreach y in 2021 2022 2023 2024 {
        local ++j
        post VER ("T4") ("`y'") ("wave_mean") ("`v'") ///
            (el(M,1,`j')) (.) (.) (.) (.) (.)
    }
    qui svy: mean `v'
    matrix M = e(b)
    post VER ("T4") ("pooled") ("mean") ("`v'") ///
        (el(M,1,1)) (.) (.) (.) (.) (e(N))
}

* STEP 4.2  Pooled fragility shares.
* Pooled fragility shares reported in the text.
capture drop nocover400 noEF
gen nocover400 = 1 - liq
gen noEF       = 1 - EF1
svy: mean nocover400 noEF cc_bal owner
matrix M = e(b)
local j = 0
foreach v in nocover400 noEF cc_bal owner {
    local ++j
    post VER ("T4") ("pooled") ("fragility") ("`v'") ///
        (el(M,1,`j')) (.) (.) (.) (.) (e(N))
}

* STEP 4.3  Wave means of the four indices and their component items.
* Series underlying Figure 2 (index means and component shares by wave).
foreach v in SEW income_z assets_z debt_z EF1 BK1 liq has_card cc_bal SL1 EF3_b {
    qui svy: mean `v', over(year)
    matrix M = e(b)
    local j = 0
    foreach y in 2021 2022 2023 2024 {
        local ++j
        post VER ("FIG2") ("`y'") ("wave_mean") ("`v'") ///
            (el(M,1,`j')) (.) (.) (.) (.) (.)
    }
}


*------------------------------------------------------------------------------
* 8. WITHIN-PERSON FIXED EFFECTS (CONDITIONAL LOGIT; combined-file Table 6)
*    Conditions on the respondent, so every time-invariant trait is
*    differenced out. Identification comes from respondents whose behavior
*    changed between the two waves; time-invariant covariates drop by design.
*    Three consecutive-wave transitions (Table 6, Panels A to C). Expected
*    discordant respondents (n in the verification file is observations,
*    which is twice this): relocation 474 / 517 / 556; property
*    493 / 591 / 690; insurance 226 / 251 / 232. Expected perceived-risk
*    odds ratios: 1.73 / 1.52 / 1.92 (2021 to 2022), 1.35 / 1.31 / 1.48
*    (2022 to 2023), 1.32 / 1.57 / 1.33 (2023 to 2024).
*------------------------------------------------------------------------------
* STEP 8.1  Loop over the three pairs of adjacent waves. For each pair,
*           reload the clean file, keep the two waves, and keep only people
*           observed in both (n_wave == 2). period marks the later wave.
di _n(2) "=== TABLE 6: WITHIN-PERSON FIXED EFFECTS ==="
foreach pair in "2021 2022" "2022 2023" "2023 2024" {
    tokenize `pair'
    local y1 `1'
    local y2 `2'
    use `full', clear
    keep if year == `y1' | year == `y2'
    bysort shedid (year): gen n_wave = _N
    keep if n_wave == 2                    // respondents present in both waves
    gen byte period = (year == `y2')       // wave indicator
    * STEP 8.2  For each behavior, fit a conditional (fixed-effects) logit
    *           grouped on the person. Only people whose behavior changed between
    *           the two waves contribute; traits that do not change drop out.
    *           Odds ratios are posted; compare the perceived-risk odds ratios with
    *           the expected values in the section header.
    foreach o in ND4_a ND4_b ND4_c {
        di _n "--- `o': `y1' to `y2' ---"
        clogit `o' risk_perc experience SEW income_z assets_z debt_z period, ///
            group(pid) or
        vfocal, sec(T6) out(`o') sp(clogit_`y1'_`y2') ///
            v(risk_perc experience SEW income_z assets_z debt_z) eform
    }
}


*------------------------------------------------------------------------------
* 9. FIRST-DIFFERENCE LINEAR PROBABILITY MODELS (combined-file Table 7)
*    Restates the within-person result in percentage points.
*    Expected: change in perceived risk on property improvement, 2023 to 2024,
*    3.8 percentage points. Expected N of differenced observations: 3,752
*    (2021 to 2022), 3,870 (2022 to 2023), 4,018 (2023 to 2024).
*------------------------------------------------------------------------------
* STEP 9.1  Same three pairs of waves and the same two-wave samples.
di _n(2) "=== TABLE 7: FIRST DIFFERENCES ==="
foreach pair in "2021 2022" "2022 2023" "2023 2024" {
    tokenize `pair'
    local y1 `1'
    local y2 `2'
    use `full', clear
    keep if year == `y1' | year == `y2'
    bysort shedid (year): gen n_wave = _N
    keep if n_wave == 2
    * STEP 9.2  Declare the panel (person and year) so D. means the change
    *           from the earlier to the later wave.
    xtset pid year                      // enables the D. operator
    * STEP 9.3  For each behavior, regress the change in the behavior on the
    *           changes in the six focal predictors, with robust standard errors.
    *           Coefficients are posted in percentage points.
    foreach o in ND4_a ND4_b ND4_c {
        di _n "--- `o': `y1' to `y2' ---"
        regress D.`o' D.risk_perc D.experience D.SEW ///
            D.income_z D.assets_z D.debt_z, vce(robust)
        vfocal, sec(T7) out(`o') sp(fd_`y1'_`y2') ///
            v(D.risk_perc D.experience D.SEW D.income_z D.assets_z D.debt_z) pp
    }
}


*------------------------------------------------------------------------------
* 11. RANDOM-INTERCEPT CROSS-LAGGED PANEL MODEL (RI-CLPM; combined-file Table 9)
*     Hamaker, Kuiper & Grasman (2015). Uses the 1,885 respondents observed
*     in all of 2022, 2023, and 2024. The perception item is asked in all four
*     waves; the three-wave window is used because it maximizes the balanced
*     panel (1,885 respondents, against 989 observed in all four waves).
*
*     The manuscript's Table 9 comes from the latent RI-CLPM estimated in
*     Python (../python/riclpm_canonical.py), because Stata's -sem- refuses a
*     model with more latent than observed variables. Manuscript values:
*     between-person r = .30 / .24 / .33; no cross-lagged path significant.
*
*     This section runs the Stata-feasible person-mean approximation. Expected:
*     between-person correlation of person means about .22 / .14 / .17, and
*     small cross-lagged paths on person-centered scores. The lagged paths are
*     estimated by regression on stacked transitions rather than -sem-,
*     because person-centered scores sum to zero within a person and make the
*     -sem- covariance matrix singular. Person-centering also biases the
*     autoregressive paths downward, so read this block for its pattern, not
*     its magnitudes; the latent model in Python is the reported estimate.
*------------------------------------------------------------------------------
* STEP 11.1 For each behavior, reload the clean file and keep people
*           observed in all of 2022, 2023, and 2024 (n_wave == 3).
di _n(2) "=== TABLE 9: RI-CLPM (PERSON-MEAN APPROXIMATION) ==="
foreach o in ND4_a ND4_b ND4_c {
    use `full', clear
    keep if inlist(year, 2022, 2023, 2024)
    bysort shedid (year): gen n_wave = _N
    keep if n_wave == 3
    * STEP 11.2 Reshape to one row per person, with expected change (x1-x3)
    *           and the behavior (y1-y3) for the three waves.
    keep shedid year risk_perc `o'
    reshape wide risk_perc `o', i(shedid) j(year)
    rename risk_perc2022 x1
    rename risk_perc2023 x2
    rename risk_perc2024 x3
    rename `o'2022 y1
    rename `o'2023 y2
    rename `o'2024 y3
    * STEP 11.3 Between-person part: correlate each person's average expected
    *           change with their average behavior. Expected r about .22 / .14 /
    *           .17 in this approximation.
    di _n "--- RI-CLPM approximation: perceived risk <-> `o' ---"
    count
    local nn = r(N)
    egen xbar = rowmean(x1 x2 x3)
    egen ybar = rowmean(y1 y2 y3)
    correlate xbar ybar
    post VER ("T9") ("`o'") ("pm_3wave") ("between_r") ///
        (r(rho)) (.) (.) (.) (.) (`nn')
    * STEP 11.4 Within-person part: subtract each person's average to get
    *           person-centered scores.
    forvalues k = 1/3 {
        gen xc`k' = x`k' - xbar
        gen yc`k' = y`k' - ybar
    }
    * Cross-lagged paths on the person-centered scores, held equal over
    * time by stacking the wave-to-wave transitions; SEs clustered by person.
    * STEP 11.5 Stack the wave-to-wave transitions (one row per person and
    *           wave) and declare them as a panel so L. means the previous wave.
    gen long rid = _n
    keep rid xc* yc*
    reshape long xc yc, i(rid) j(t)
    xtset rid t
    * STEP 11.6 Cross-lagged paths: does earlier expected change predict
    *           later behavior, and does earlier behavior predict later expected
    *           change? Standard errors are clustered on the person. Read these
    *           for direction and sign; the reported estimates come from the
    *           latent model in ../python/riclpm_canonical.py.
    di _n "--- prior perception -> later behavior (`o') ---"
    regress yc L.xc L.yc, vce(cluster rid)
    vfocal, sec(T9) out(`o') sp(pm_3wave_beh) v(L.xc L.yc)
    di _n "--- prior behavior -> later perception (`o') ---"
    regress xc L.xc L.yc, vce(cluster rid)
    vfocal, sec(T9) out(`o') sp(pm_3wave_perc) v(L.xc L.yc)
}

*------------------------------------------------------------------------------
* 11b. RI-CLPM FOUR-WAVE CHECK (2021 to 2024, balanced panel, N = 989)
*      Manuscript values (latent model, Python): between-person r = .30,
*      .16, .34; one reverse path (relocation -> later perception) b = .14,
*      p = .009. Person-mean approximation here: r about .24 / .14 / .21.
*------------------------------------------------------------------------------
* STEP 11b.1 Repeat Section 11 for people observed in all four waves,
*            2021 to 2024 (n_wave == 4).
di _n(2) "=== TABLE 9 CHECK: FOUR-WAVE APPROXIMATION ==="
foreach o in ND4_a ND4_b ND4_c {
    use `full', clear
    bysort shedid (year): gen n_wave = _N
    keep if n_wave == 4
    keep shedid year risk_perc `o'
    reshape wide risk_perc `o', i(shedid) j(year)
    forvalues k = 1/4 {
        local yr = 2020 + `k'
        rename risk_perc`yr' x`k'
        rename `o'`yr' y`k'
    }
    * STEP 11b.2 Between-person correlation of person averages (expected
    *            about .24 / .14 / .21), then person-centered scores.
    di _n "--- Four-wave check: perceived risk <-> `o' ---"
    count
    local nn = r(N)
    egen xbar = rowmean(x1 x2 x3 x4)
    egen ybar = rowmean(y1 y2 y3 y4)
    correlate xbar ybar
    post VER ("T9") ("`o'") ("pm_4wave") ("between_r") ///
        (r(rho)) (.) (.) (.) (.) (`nn')
    forvalues k = 1/4 {
        gen xc`k' = x`k' - xbar
        gen yc`k' = y`k' - ybar
    }
    * Cross-lagged paths on the person-centered scores, held equal over
    * time by stacking the wave-to-wave transitions; SEs clustered by person.
    * STEP 11b.3 Stack the transitions and estimate the two cross-lagged
    *            regressions, as in STEP 11.6.
    gen long rid = _n
    keep rid xc* yc*
    reshape long xc yc, i(rid) j(t)
    xtset rid t
    di _n "--- prior perception -> later behavior (`o') ---"
    regress yc L.xc L.yc, vce(cluster rid)
    vfocal, sec(T9) out(`o') sp(pm_4wave_beh) v(L.xc L.yc)
    di _n "--- prior behavior -> later perception (`o') ---"
    regress xc L.xc L.yc, vce(cluster rid)
    vfocal, sec(T9) out(`o') sp(pm_4wave_perc) v(L.xc L.yc)
}


*------------------------------------------------------------------------------
* 13. ATTRITION AND BALANCE (robustness)
*     For each wave, compares respondents recontacted in the next wave with
*     those not recontacted. Expected retention 31.6% (2021), 33.2% (2022),
*     35.2% (2023). Standardized mean differences for risk perception,
*     experience, and the three behaviors all below 0.06 in absolute value.
*     Verification rows: est = retained mean, se = not-retained mean,
*     lo = standardized mean difference, p = t-test, n = retention percent.
*------------------------------------------------------------------------------
* STEP 13.1 Reload the clean file and flag, for each wave, whether the
*           person was recontacted in the next wave.
di _n(2) "=== ATTRITION AND BALANCE ==="
use `full', clear
bysort shedid (year): gen byte recontacted = (year[_n+1] == year + 1)
* STEP 13.2 For 2021, 2022, and 2023: print the share recontacted, then
*           compare recontacted and not-recontacted respondents on each
*           variable (means, standardized mean difference, t-test p-value).
*           Differences below 0.06 in absolute value are small.
foreach y in 2021 2022 2023 {
    qui summarize recontacted if year == `y'
    local ret = 100*r(mean)
    di _n "--- Wave `y': retention into `=`y'+1' = " %5.1f `ret' "% ---"
    di as text %-12s "variable" %12s "retained" %12s "not" %10s "SMD" %10s "p"
    foreach v in ppage risk_perc SEW income_z assets_z debt_z experience ///
            owner ND4_a ND4_b ND4_c {
        qui summarize `v' if year == `y' & recontacted == 1
        local m1 = r(mean)
        local v1 = r(Var)
        qui summarize `v' if year == `y' & recontacted == 0
        local m0 = r(mean)
        local v0 = r(Var)
        local smd = (`m1' - `m0')/sqrt((`v1' + `v0')/2)
        qui ttest `v' if year == `y', by(recontacted)
        local pv = r(p)
        di as text %-12s "`v'" as result %12.3f `m1' %12.3f `m0' %10.3f `smd' %10.4f `pv'
        post VER ("13") ("`y'") ("attrition") ("`v'") ///
            (`m1') (`m0') (`smd') (.) (`pv') (`ret')
    }
}


*------------------------------------------------------------------------------
* 16. WRITE THE VERIFICATION FILE
*------------------------------------------------------------------------------
* STEP 16.1 Close the verification file, export it as a CSV, and print
*           where it was written.
postclose VER
use "$OUTDIR/verification_estimates", clear
export delimited using "$OUTDIR/verification_estimates.csv", replace
di _n(2) "Verification file written: $OUTDIR/verification_estimates.csv (" _N " rows)"

* STEP 16.2 Print the closing message: send back the two files it lists.
di _n(2) "PANEL REPLICATION COMPLETE: Sections 4, 8, 9, 11, 11b, and 13."
di "Send back: $OUTDIR/replication_log.txt and $OUTDIR/verification_estimates.csv"

* STEP 16.3 Close the log.
capture log close
