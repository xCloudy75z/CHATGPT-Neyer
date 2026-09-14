# CHATGPT-Neyer

This project contains the audited Neyer D-optimal gap-test application for MATLAB R2022b.

The application models a destructive gap test in which smaller gaps make interaction more likely and larger gaps make interaction less likely. It estimates the middle gap, where interaction is about 50%, and the overall variation around that middle.

## Public review site

The verified public review site is available at
[https://xcloudy75z.github.io/CHATGPT-Neyer/](https://xcloudy75z.github.io/CHATGPT-Neyer/).

It includes plain-language guides to the [method](https://xcloudy75z.github.io/CHATGPT-Neyer/method.html),
[direct test workflow](https://xcloudy75z.github.io/CHATGPT-Neyer/test-workflow.html),
[optional separate planning questions](https://xcloudy75z.github.io/CHATGPT-Neyer/planner.html),
[results](https://xcloudy75z.github.io/CHATGPT-Neyer/results.html),
[physical setup](https://xcloudy75z.github.io/CHATGPT-Neyer/physical-setup.html),
[audit](https://xcloudy75z.github.io/CHATGPT-Neyer/audit.html), and
[evidence](https://xcloudy75z.github.io/CHATGPT-Neyer/evidence.html).

## Start here

1. Download [Neyer_Gap_Test_v1_13.mlx](delivery/Neyer_Gap_Test_v1_13.mlx).
2. Open it in MATLAB R2022b.
3. Press **Run** once.
4. Select **Run the published example**. The expected display is a middle gap of 5.39 mm and an overall variation of 1.04 mm.
5. Select **Run a Test** when ready for the physical study.

**Run a Test works independently.** It does not load or use anything from the
Pre-Test Planner. The number entered on the test-settings screen is the maximum
number of destructive tests allowed, not a confidence-based stopping promise.

The `.mlx` is standalone. It contains the complete application and does not need the source folder, an executable, `addpath`, an internet connection, or an add-on package.

## Physical test rule

For every destructive test, prepare a new setup at the reachable gap shown by the app. Measure that setup once before testing. Enter that one measured gap, then record **Interaction** or **No interaction**. The app uses the measured gap as the actual statistical gap.

The physical build instruction always uses two decimal places. The one physical
measurement retains the precision entered and is used in the calculation.

Ten spacers from each labelled size were sampled with three readings per
spacer. Their typical batch thicknesses were 0.486 mm, 1.118 mm, and 2.070 mm
for the 0.5, 1, and 2 mm groups. These are batch planning values; the remaining
200–300 spacers per size do not need individual IDs. One typical spacer from
each group gives an unrounded sum of 3.674667 mm, displayed directly as
3.67 mm and matching the earlier 3.67 mm complete-build
measurement when shown to two decimal places.

The current aluminium foil is approximately 0.015 mm thick. This is stored as
construction information and does not control test-gap rounding or the Stage-2
safety floor. The usable gap step is a separate study input. Based on the
current physical information, 0.05 mm remains a provisional choice to verify
experimentally. The observed printed-spacer ranges do not by themselves prove
that 0.05 mm is repeatedly buildable. With the retained two-step protection,
0.05 mm gives a 0.10 mm minimum Stage-2 planning width.

The separate, optional pre-test planner separates two jobs. The smaller main study can estimate the
middle gap and overall variation. A safety-supported reliability instruction is
only issued after at least 400 independent destructive tests and only for
confidence above 50% and no higher than 95%. Reserved articles are never used
automatically; the operator decides whether to use them at each checkpoint.

## Saving results

The operator chooses the output folder and base name. The app shows the complete paths for a CSV data file and a self-contained HTML result report before saving. If either path already exists, it writes neither file and asks for another name.

## Repository map

| Folder | Contents |
|---|---|
| [`application/`](application/) | Standalone Live Script and readable MATLAB source |
| [`delivery/`](delivery/) | Final standalone `.mlx` and verification reports |
| [`tests/`](tests/) | Regression, algorithm, physical-workflow, and presentation checks |
| [`simulation/`](simulation/) | Simulation programs and recorded CSV evidence |
| [`audit/`](audit/) | Plain-language audit summary |
| [`assets/screenshots/`](assets/screenshots/) | Genuine MATLAB screens embedded in the reports |
| [`baseline/`](baseline/) | Mechanically extracted V1.8 reference implementation used by baseline tests |
| [`proposed/`](proposed/) and [`variants/`](variants/) | Intermediate comparison implementations retained as audit evidence |
| [`tools/`](tools/) | Repeatable build and verification scripts |

## Verification record

- 245 MATLAB checks passed; 0 failed and 0 remained incomplete.
- Five fresh 62-article trials covered usable steps of 0.05, 0.10, 0.15, 0.25, and 0.50 mm; every hard logic and mathematics check passed.
- A separate 1,600-run study covered four true variation sizes and five physical step sizes. It exposed the expected limitation when a coarse physical step is larger than a narrow transition.
- The real one-reading MATLAB screen asked for one measured gap and completed the minimum valid three-article route.
- Seven complete mock-laboratory routes ran 191 tests; 191 passed.
- The final 12-scenario planner simulation recorded 8 supported scenarios accepted, 0 rejected, and 4 deliberately withheld outside the supported confidence range.
- The final `.mlx` ran alone in a newly created empty folder.
- Its real Demo button displayed 5.39 mm and 1.04 mm.
- Existing CSV and HTML result files remained unchanged in overwrite-protection tests.
- MATLAB R2022b parsed the complete standalone source.
- Seven genuine MATLAB operator screens were captured and visually checked.

Run the complete MATLAB test suite with:

```matlab
run('tools/run_v113_full_suite.m')
```

## Important limits

- The provisional 0.05 mm usable resolution still needs repeated physical confirmation.
- A 0.50 mm usable step can be too coarse when the true overall variation is about 0.25 mm. In that simulated case, only 27% of runs obtained the strict overlap needed to leave Stage 2 within 62 tests.
- Foil-based build recipes remain disabled until foil-stack measurements and the practical maximum layer count are supplied.
- Extremely separated artificial data deserve a deeper numerical study before using this tool for safety-critical qualification.
- The supplied V1.8 `.mlx` remains preserved locally and is identified by its recorded SHA-256 fingerprint, but it is not redistributed in this public repository.

Use the [direct test walkthrough](https://xcloudy75z.github.io/CHATGPT-Neyer/test-workflow.html)
for current operating instructions and the [evidence page](https://xcloudy75z.github.io/CHATGPT-Neyer/evidence.html)
for the recorded checks. The older overnight report is retained only as historical
audit material; its planner-first operating steps do not describe the current direct workflow.
