# V1.13 complete audit — golden-unit decision

## Decision

**V1.13 is mathematically sound and operationally usable, but it is not yet the golden unit.**

No Critical problem was found. The Neyer stages, 1.0-sigma Stage-2 transition, repeated 0.8 shrink, maximum-likelihood estimates, confidence calculations, D-optimal choices, physical-gap recording, bounds, rounding, stopping, saving, and standalone packaging all passed.

The reason for holding back the golden label is the user-facing design. Five Important issues remain: two important inputs are not explained where they are entered; the direct workflow cannot enter a confirmed irregular set of buildable gaps; the unfinished-result screen looks broken; the Help window is dense and technical; and the first menu instruction is cut off.

The released V1.13 file stayed byte-for-byte unchanged throughout this audit.

## At-a-glance scorecard

| Area | Decision | Evidence |
|---|---|---|
| Frozen release identity | Pass | SHA-256 exactly matched `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E` |
| Neyer method | Pass | 9 focused stage and paper-replay checks |
| Independent mathematics | Pass | 6 varied histories matched an independent calculation |
| Physical gap behavior | Pass | 22 combinations and invalid-entry cases |
| User workflow and saving | Pass functionally | 5 end-to-end workflow checks |
| Visual clarity | Hold | 5 Important and 2 Minor findings |
| Stress testing | Pass | 1,800 simulated studies across 360 configurations |
| Full automated suite | Pass | 272 passed, 0 failed, 0 incomplete |
| Standalone `.mlx` | Pass | Clean folder contained only the Live Script |

## What was checked

### 1. Neyer logic

The code was traced against Neyer’s published method. It starts at the midpoint, searches in the correct direction for this decreasing-gap application, uses binary search while the empty bracket is wider than one guessed overall variation, then moves into D-optimal searching. During this separated Stage 2, the working variation is multiplied by 0.8 after every new article. Once interaction and no-interaction results overlap, it fits the curve and uses the information calculation to select the next gap.

The former 1.5-times transition rule is not present. The current transition is one times the starting overall-variation guess, matching the paper’s flow chart.

### 2. Independent calculation

The production fit was compared with a separate calculation that did not call the production fitting, likelihood, confidence, or D-optimal functions. Across paper, balanced, narrow, wide, duplicate-gap, and near-boundary histories:

- largest middle-gap difference: about `0.000000092 mm`;
- largest overall-variation difference: about `0.000000024 mm`;
- largest finite confidence-limit difference: about `0.0000021 mm`;
- next D-optimal gap: the same in all six cases.

These differences are ordinary numerical rounding, not meaningful disagreements.

### 3. Physical gap rules

The audit confirmed all of the following:

- requested gaps are displayed with two decimals;
- the one measured gap is stored separately and drives the statistics;
- `2.45 mm` requested and `2.50 mm` measured stays exactly that way in the record;
- blank, text, negative, multiple, NaN, and infinite measurements are rejected;
- 0.05, 0.10, 0.15, and 0.50 mm regular steps map to reachable settings;
- the Stage-2 planning floor is always two usable steps;
- when no different useful setting remains, the study pauses and preserves completed data;
- an unexpected physical boundary result is repeated once for confirmation, never indefinitely.

One design gap remains: the calculation engine supports an explicit list of confirmed gaps and spacer combinations, but the Direct Run a Test screen exposes only a regular step. Therefore a value such as `0.05 mm` currently means “assume every 0.05 mm setting is buildable.” That has not been physically established for the mixed printed-spacer and 0.015 mm foil kit.

### 4. Stress matrix

The matrix covered:

- true middle gaps of 1.5, 5.0, and 8.5 mm;
- true overall variations of 0.15, 0.25, 0.50, 1.00, and 1.50 mm;
- usable steps of 0.05, 0.10, 0.15, and 0.50 mm;
- starting variation guesses of 0.25, 1.00, and 2.00 mm;
- study limits of 20 and 62 articles;
- five independent repetitions of every combination.

That produced 1,800 studies. Every request remained finite, within the permitted range, on the declared reachable grid, used one measurement, maintained valid stage movement, produced a positive fitted variation when a fit existed, preserved the decreasing probability direction, and repeated exactly when the same seed was used.

| Usable step | Runs | Runs that established overlap | Plain meaning |
|---:|---:|---:|---|
| 0.05 mm | 450 | 86.0% | Fine physical control usually reached a fitted curve |
| 0.10 mm | 450 | 85.3% | Very similar to 0.05 mm in this mixed matrix |
| 0.15 mm | 450 | 81.1% | Still useful, with slightly fewer fitted runs |
| 0.50 mm | 450 | 53.6% | Often too coarse for narrow changes; the tool honestly withheld a fit |

The 0.50 mm result does not mean the code failed. It means coarse physical settings often cannot create the closely mixed outcomes needed to estimate the curve. Increasing from 20 to 62 articles improved the overlap rate from 72.3% to 80.7%, but it cannot create physical detail that the available gap grid does not contain.

### 5. Screens and wording

Seven real MATLAB R2022b screens were captured and inspected. The fitted result is the strongest part: its two graphs show the middle, variation, observed outcomes, and correct decreasing interaction direction. The Pre-Test Planner is also clearly separated and labels its figures as estimates.

The Important visual corrections are recorded in `ui-visual-review.md`. These are not cosmetic preferences: they affect whether a non-programmer can provide the right input and understand an unfinished result.

### 6. Saving and standalone delivery

The CSV and HTML values agreed with the result screen. The user-selected destination was used. A second save with the same name left the existing files unchanged.

The V1.13 `.mlx` was copied by itself to a new temporary folder and run from a clean MATLAB path. It contained 124 embedded local functions, completed a 20-test direct workflow, calculated the chance at a physical gap, saved HTML and CSV, blocked a same-name overwrite, and reproduced the published 5.3922 mm middle and 1.0412 mm overall variation. No project helper `.m` file was used.

MATLAB’s optional dependency scanner could not load its own `libmwdepfun_analysis.dll` on this PC. That installation problem did not stop the stronger practical one-file run.

## Pre-Test Planner boundary

The planner remains optional and separate. Its article number is an estimate based on the entered assumptions and recorded simulations, not a universal promise. The fixed 400-article floor is a conservative project rule chosen from the recorded validation set; it is not a rule from Neyer’s paper and is not the same as the separate zero-failure qualification calculation.

The Direct Run a Test workflow does not need a saved plan and was audited that way.

## Required V1.14 correction

V1.14 should preserve the verified mathematics and change only the user-facing and configuration layer first:

1. Explain every direct-run input beside the field, with a short example.
2. Let the user choose either a genuine regular step or a confirmed list of buildable gaps.
3. Replace the unfinished-result charts and disabled fragments with one clear status-and-next-action view.
4. Rebuild Help into short visual sections and remove unexplained Stage language.
5. Wrap the main-menu instruction so it is fully visible.
6. Remove the repeated per-test instruction.
7. Clarify internal names and source comments without changing any answer.

Every correction must first be represented by a failing regression test. V1.13 must remain frozen, and the completed V1.14 candidate must rerun the 272-test suite, the 1,800-run stress matrix, the seven-screen review, and the clean standalone test.

## Conclusion

V1.13 has passed the hard part: its Neyer logic, numbers, test progression, physical measurement handling, records, and standalone packaging are credible. It misses the golden-unit gate because several screens still require the user to interpret hidden or technical meaning. The correct next move is a tightly controlled V1.14 clarity and reachable-gap update, not a rewrite of the verified algorithm.
