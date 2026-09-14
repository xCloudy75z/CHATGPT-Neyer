# Neyer Gap Test V2 — Golden Candidate Design

## Purpose

Create a polished standalone MATLAB Live Script named `Neyer_Gap_Test_v2.mlx`. V2 must keep the verified V1.13 Neyer calculations unchanged while correcting the proven user-interface and physical-gap configuration problems found in the complete V1.13 audit.

V1.13 remains frozen as the comparison reference.

## Success rule

V2 may be called the golden unit only when:

- it has no unresolved Critical or Important audit findings;
- all existing and new automated tests pass;
- the full 1,800-run stress matrix passes;
- every main MATLAB screen has been visually inspected;
- a direct test can use either a genuine regular step or a confirmed list of buildable gaps;
- the `.mlx` runs alone from a clean folder;
- saving produces matching HTML and CSV records and never silently overwrites an earlier record.

## What will not change

The following verified behavior is locked:

- Stage 1 direction and expanding search;
- the one-overall-variation Stage-2 transition;
- repeated `0.8` Stage-2 reduction;
- the two-usable-step Stage-2 floor;
- strict overlap before fitting;
- maximum-likelihood estimation;
- confidence calculations;
- D-optimal next-gap selection;
- larger gaps mean interaction is less likely;
- one measured gap for every new physical setup;
- measured gaps drive the statistics while requested gaps remain recorded;
- requested build gaps are shown with two decimal places;
- one deliberate repeat after an unexpected boundary result;
- honest pause behavior when no different useful reachable gap remains;
- the Pre-Test Planner remains optional and separate from Run a Test.

## Direct Run a Test redesign

### Physical gap method

The input screen will ask one clear question: **“How can you build the test gaps?”**

It will offer two choices:

1. **Regular gap step** — use only when every multiple of the entered step can genuinely be built inside the permitted range.
2. **Confirmed gap list** — enter measured, buildable gaps separated by commas. The application may request only a value from this list.

Printed-spacer combination recipes will not be added to the direct workflow in V2. That route requires confirmed component measurements and practical count limits. It remains available in the separate planner and calculation layer for future use.

### Input explanations

Every field will have a one-line explanation directly below it:

| Field | Plain explanation |
|---|---|
| Low middle-gap guess | Smallest reasonable location of the 50/50 change point. This is a starting estimate, not a test limit. |
| High middle-gap guess | Largest reasonable location of the 50/50 change point. |
| Rough overall-variation guess | Rough width of the change from mostly Interaction to mostly No interaction. Use `1 mm` if only a broad first estimate is available. |
| Maximum tests | The most new articles this direct run may consume. It is not a confidence promise. |
| Minimum permitted gap | The smallest gap the study is allowed to request. |
| Maximum permitted gap | The largest useful gap the study is allowed to request. |
| Regular gap step | Distance between every genuinely buildable setting, such as `0.05 mm` or `0.10 mm`. |
| Confirmed gap list | Only the physical gaps already confirmed as buildable. |
| Foil thickness | Construction information only; it does not define the usable gap step or statistical floor. |

The selected physical method will show only the relevant entry field. Input errors will name the visible question and explain how to correct it.

## Per-test screen

The repeated “Build a gap” and “Set the gap” instructions will become one strong instruction:

> Build the requested gap: **5.00 mm**

The screen will continue to show:

- the test number;
- one measured-gap entry;
- a reminder that the measured gap is used in the calculation;
- large Interaction and No interaction buttons.

For a confirmed list, the instruction will say that the value came from the confirmed buildable gaps.

## Result screens

### Before a fitted curve exists

V2 will not display blank charts or partly visible calculator controls. It will show one clear status card:

- **No fitted answer yet**;
- why both outcomes must occur close enough to establish the change;
- how many tests have been recorded;
- that completed data can still be saved;
- the next safe action: continue if tests remain, or save and review.

### After a fitted curve exists

The two useful charts remain. Technical wording will be simplified:

- “fitted result” becomes “calculated result”;
- “confidence-backed minimum” becomes “cautious minimum supported by the data”;
- the middle gap remains clearly labelled as about 50% Interaction;
- probability and confidence remain explicitly separated;
- smaller-gap and larger-gap direction remains visible.

## Main menu and Help

The main-menu explanation will wrap over two complete lines so no meaning is hidden by an ellipsis.

Help will be rebuilt as a scrollable set of short titled sections using readable proportional text. It will cover:

- what the tool answers;
- what each direct-run input means;
- regular step versus confirmed gap list;
- requested gap versus measured gap;
- what Interaction and No interaction mean in the calculation;
- middle gap and overall variation;
- probability versus confidence;
- boundary confirmation and pause behavior;
- saving and overwrite protection;
- the separate status of the Pre-Test Planner.

“Stage 1,” “Stage 2,” “fitted,” and similar internal terms will not appear unless immediately translated into plain language.

## Internal clarity

The inaccurate source label on the first two-variation reach will be corrected to reflect that the rule is stated by Neyer’s paper. Legacy internal names such as `break` and `survive` will be documented as compatibility names rather than renamed, because renaming them would add risk without improving the operator experience.

No calculation constant will be changed as part of this interface work.

## Files and release identity

V2 will use separate files so the audited V1.13 release remains untouched:

- `delivery/Neyer_Gap_Test_v2.m`
- `delivery/Neyer_Gap_Test_v2.mlx`
- V2-specific tests and audit evidence

The application title will show **Neyer Gap Test V2**. The finished `.mlx` will contain every required function internally and will not depend on the tracked `.m` file at runtime.

## Error handling

- Invalid inputs remain on the same screen for correction.
- A confirmed list must contain at least two finite nonnegative gaps inside the permitted range.
- Duplicate confirmed gaps will be safely reduced to one value.
- If the list cannot provide a different useful next setting, the study pauses and preserves its data.
- An unfinished study never displays fake numbers or `NaN` as a result.
- Existing saved files are never silently replaced.

## Verification

Implementation will follow test-first development:

1. Add failing tests for every V1.13 Important and Minor finding selected for V2.
2. Create V2 from the verified V1.13 source without editing V1.13.
3. Implement only the approved interface and direct physical-method changes.
4. Run the complete MATLAB suite with zero failed and zero incomplete tests.
5. Run the 1,800-study matrix for 0.05, 0.10, 0.15, and 0.50 mm regular steps.
6. Add confirmed-list stress cases, including sparse and irregular lists.
7. Capture and visually inspect every V2 screen in MATLAB R2022b.
8. Copy only `Neyer_Gap_Test_v2.mlx` to a clean folder and exercise direct testing, fixed-gap calculation, saving, overwrite protection, and the published example.
9. Confirm the published example still returns middle `5.3922 mm` and overall variation `1.0412 mm`.
10. Fingerprint the finished `.mlx` and audit evidence.

## Delivery boundary

After every V2 gate passes, the final Live Script and its V2 audit summary will be prepared for the project repository and the approved `CHATGPT-Neyer` OneDrive delivery location. No PowerPoint or general project HTML report will be rebuilt unless requested separately.
