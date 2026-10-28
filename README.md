# Does Perceived Risk Precede Protective Action?

Within-household evidence from a national panel, 2021 to 2024. Paper 2, the companion to *Paying for Protection* (repository `paying-for-protection`).

Data: Federal Reserve Board Survey of Household Economics and Decisionmaking (SHED), 2021 to 2024, pooled (47,236 respondent-waves; 32,585 adults, a subset recontacted in adjacent waves).

Status: not yet drafted. Private while Paper 1 is under double-anonymized review, because Paper 1 cites this work.

## Question

Paper 1 shows, across households, that expected increases in disaster likelihood and recent disaster impact are associated with mitigation. Risk communication assumes something stronger: that moving a household's perception moves its behavior. This paper asks whether changes in perceived risk precede changes in mitigation within the same household.

## Layout

```
data/      Prepared analysis dataset (Stata), pooled and by wave; DATA_SOURCES.txt
stata/     SHED_PANEL_REPLICATION.do (step-by-step comments) and expected_estimates.csv
python/    riclpm_canonical.py, the latent RI-CLPM (Stata's sem cannot fit it)
source/    Combined manuscript from before the split; its within-person sections are the starting draft
output/    Created by the runs; not tracked
```

## Reproducing the current results

1. Open Stata (release 14 or later) and `cd` to `stata/`.
2. Run `do SHED_PANEL_REPLICATION.do`.
3. Compare `output/verification_estimates.csv` with `stata/expected_estimates.csv`.

Latent RI-CLPM: from `python/`, run `python riclpm_canonical.py` (requires pandas, numpy, semopy).

## Disaster-impact measure

The do-file has a switch in STEP 1.10. `"five"` (default) reproduces the results verified in Stata 14.2 for the combined study. `"four"` uses only ND1_a to ND1_d, matching Paper 1. ND1_e changed meaning between 2022 and 2023, and in 2023 and 2024 the impact items followed a financial-impact screen (ND0), so the 2022 to 2023 transition mixes real change with a change in question routing.

## To do

- [ ] Re-estimate the panel models with the four-item impact measure and decide how to treat the 2022 to 2023 transition.
- [ ] RI-CLPM for binary outcomes (WLSMV or a logit-link specification).
- [ ] Decide on panel weights (cross-sectional weight versus panel_weight).
- [ ] Table of change rates between waves for each behavior and for expected change.
- [ ] New introduction and literature review aimed at the within-household question.
- [ ] Target journal.
