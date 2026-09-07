# CHATGPT-Neyer

This project contains the audited Neyer D-optimal gap-test application for MATLAB R2022b.

The finished application models a destructive gap test in which smaller gaps make interaction more likely and larger gaps make interaction less likely. It estimates the middle gap, where interaction is about 50%, and the transition width around that middle.

## Start here

1. Download [Neyer_Gap_Test_v1_9.mlx](application/Neyer_Gap_Test_v1_9.mlx).
2. Open it in MATLAB R2022b.
3. Press **Run** once.
4. Select **Run a Demo (verify)**. The expected display is a middle gap of 5.39 mm and a transition width of 1.04 mm.
5. Select **Run a Test** when ready for the physical study.

The `.mlx` is standalone. It contains the complete application and does not need the source folder, an executable, `addpath`, an internet connection, or an add-on package.

## Physical test rule

For every destructive test, build a new spacer at the reachable gap shown by the app. Measure that unchanged spacer four or five times before testing. Enter all readings, then record **Interaction** or **No interaction**. The app uses the measured mean as the actual statistical gap.

The physical build instruction always uses two decimal places. Individual
measurements retain the precision entered and their mean is used in the
calculation.

The current aluminium foil is approximately 0.015 mm thick. This is stored as
construction information and does not control test-gap rounding or the Stage-2
safety floor. The usable gap step is a separate study input. Based on the
current 0.49--0.52 mm printed-spacer observations, 0.05 mm is the provisional
choice to verify experimentally. With the retained two-step protection, that
gives a 0.10 mm minimum Stage-2 planning width.

## Saving results

The operator chooses the output folder and base name. The app shows the complete paths for a CSV data file and a self-contained HTML result report before saving. If either path already exists, it writes neither file and asks for another name.

## Repository map

| Folder | Contents |
|---|---|
| [`application/`](application/) | Standalone Live Script and readable MATLAB source |
| [`delivery/`](delivery/) | Final `.mlx`, PowerPoint, and comprehensive HTML report |
| [`tests/`](tests/) | Regression, algorithm, physical-workflow, and presentation checks |
| [`simulation/`](simulation/) | Simulation programs and recorded CSV evidence |
| [`audit/`](audit/) | Plain-language audit summary |
| [`assets/screenshots/`](assets/screenshots/) | Genuine MATLAB screens embedded in the reports |
| [`baseline/`](baseline/) | Mechanically extracted V1.8 reference implementation used by baseline tests |
| [`proposed/`](proposed/) and [`variants/`](variants/) | Intermediate comparison implementations retained as audit evidence |
| [`tools/`](tools/) | Repeatable build and verification scripts |

## Verification record

- 95 MATLAB tests passed; 0 failed and 0 remained incomplete.
- The final `.mlx` ran alone in a newly created empty folder.
- Its real Demo button displayed 5.39 mm and 1.04 mm.
- Existing CSV and HTML result files remained unchanged in overwrite-protection tests.
- MATLAB R2022b parsed the complete standalone source.
- The final PowerPoint contains 12 inspected slides, five editable tables, and two editable charts.
- The HTML report is self-contained and contains five embedded screenshots.

Run the complete MATLAB test suite with:

```matlab
run('tools/run_full_test_suite.m')
```

## Important limits

- The provisional 0.05 mm usable resolution still needs repeated physical confirmation.
- Repeated readings describe one spacer build; they cannot remove variation between separately built spacers.
- Extremely separated artificial data deserve a deeper numerical study before using this tool for safety-critical qualification.
- The supplied V1.8 `.mlx` remains preserved locally and is identified by its recorded SHA-256 fingerprint, but it is not redistributed in this public repository.

See the [full HTML report](delivery/Neyer_Gap_Test_v1_9_Report.html) for the complete audit, evidence, fixes, operating instructions, and limitations.
