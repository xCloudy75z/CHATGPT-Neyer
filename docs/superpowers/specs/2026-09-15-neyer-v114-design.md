# Neyer Gap Test V1.14 Design

## Purpose

Create a safe, focused successor to V1.13 for a first Neyer gap study. V1.14 must help the operator collect interaction/no-interaction results at useful buildable gaps, estimate the 50/50 middle gap and overall variation, and show the decreasing interaction-probability curve without mixing this study with a separate fixed-gap reliability demonstration.

## Preserved release

- `delivery/Neyer_Gap_Test_v1_13.mlx` and its matching `.m` source remain unchanged.
- V1.14 is built as new files named `Neyer_Gap_Test_v1_14.m` and `Neyer_Gap_Test_v1_14.mlx`.
- The unfinished V2 candidate is not the base release.

## Operator workflow

The main menu contains only:

1. **Start or continue a gap study**
2. **Run the published example**
3. **Help and definitions**

The Pre-Test Planner and fixed-gap reliability calculator remain in source history but are not available from the V1.14 menu and cannot feed settings into a V1.14 run.

The default input route is **First study — variation unknown**. It asks for:

- lowest reasonable guess for the 50/50 middle gap;
- highest reasonable guess for the 50/50 middle gap;
- maximum number of destructive tests;
- minimum and maximum permitted gaps;
- a regular buildable gap step or a confirmed list of buildable gaps;
- approximate foil thickness as construction information only.

It does not ask for desired accuracy, reliability, confidence, or expected variation. The program derives an internal starting search scale from the entered middle-gap range and physical step. This internal value is only a way to begin the search and is never presented as a measured or known sigma.

An **Advanced — variation estimate known** route remains available for published-example reproduction and experienced users. It accepts a positive starting variation estimate. This value affects early test choices but is not the final fitted variation.

Every new physical setup is measured once. The measured gap, rather than the requested gap, is used in the calculation. Requested gaps are displayed to two decimal places and must come from the selected reachable-gap model.

## Automatic starting search scale

For the first-study route:

```text
middle_range = high_middle_guess - low_middle_guess
automatic_search_scale = max(middle_range / 6, smallest_positive_reachable_spacing)
```

For a regular grid, the spacing is the usable gap step. For a confirmed list, it is the smallest positive difference between adjacent confirmed gaps. The value must be finite, positive, and no greater than the permitted gap width. Simulation tests will compare this rule across narrow, moderate, and wide real transition spreads. If it causes repeated requests or prevents overlap in the agreed test matrix, the release is blocked until the rule is revised and retested.

## Mathematical direction

- Smaller gap means Interaction is more likely.
- Larger gap means No interaction is more likely.
- With `k = (gap - middle) / sigma`, estimated Interaction probability is `Phi(-k)`.
- Estimated No-interaction probability is `Phi(k)`.
- The one-sided profile-likelihood cautious bound must use the same direction.
- Executed source tests confirmed that V1.13 already produces these physical directions. Its local helper is misleadingly named: `phi_cdf(k)` calls the decreasing-gap shape model and therefore evaluates `Phi(-k)`. V1.14 must preserve the verified numerical behavior and correct the explanation; it must not reverse the working equations.
- Main adaptive selection, maximum-likelihood estimation, middle-gap calculation, and sigma calculation remain unchanged unless a failing regression proves a separate defect.

## Results

The primary results screen shows:

- estimated middle gap, described as about 50% Interaction;
- estimated overall variation;
- number of completed tests and counts of both outcomes;
- distribution chart;
- interaction-probability chart with Interaction falling as gap increases;
- a plain warning when the data do not yet support a fitted curve;
- Save Results with visible paths and no silent overwrite.

Confidence ranges may remain in a secondary **How certain is this estimate?** area, but the screen must not imply that 95% came from the operator or that the middle gap is a 95%-reliable operating gap. The fixed-gap R/C qualification calculator is excluded from V1.14.

## Verification requirements

- Preserve the V1.13 SHA-256 fingerprint.
- Reproduce the published 20-test reference sequence when the advanced route uses its published starting value.
- Prove probability-at-gap direction and cautious-bound direction with low-, middle-, and high-gap tests, including direct tests of the embedded Live Script.
- Test first-study parsing, automatic search scale, invalid entries, regular steps, confirmed gap lists, two-decimal requests, one measured reading, and overwrite prevention.
- Run at least five deterministic 62-test studies without the planner.
- Run an unknown-variation simulation matrix spanning different true middles, variations, physical steps, and outcome seeds.
- Build the `.mlx` in MATLAB R2022b and round-trip it back to text.
- Copy only the `.mlx` to an empty folder, launch it from a clean MATLAB path, run the published example, and test the main workflow.
- Reject release if the embedded `.mlx` functions differ from the reviewed application source.
- Record all evidence under `audit/v114/`.

## Delivery

After every release gate passes, place the final standalone Live Script at the top level of `C:\Users\games\OneDrive\CHATGPT-Neyer\`, retain a versioned/date-stamped copy, update the public repository, and verify local OneDrive sync status without claiming remote availability unless it can actually be confirmed.
