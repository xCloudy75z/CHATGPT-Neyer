# Neyer project checkpoint — 13 September 2026

## Completed before the one-reading change

| Area | Recorded result |
|---|---|
| Original V1.8 | Preserved and identified by its recorded file fingerprint |
| V1.10 Live Script | Built as one standalone `.mlx` file for MATLAB R2022b |
| Direct Run a Test route | Works without loading a Pre-Test Planner file |
| Requested gaps | Restricted to permitted, physically reachable settings and shown with two decimals |
| Actual gaps | Stored separately from requested gaps and used in the calculation |
| Stage 2 | Uses the reviewed 1.0-times entry rule, 0.8 shrink, and two-step planning floor |
| Saving | CSV and local HTML outputs are user-selected and existing files are not silently replaced |
| V1.10 MATLAB suite | 223 passed, 0 failed, 0 incomplete |
| Earlier five-run audit | Five runs of 62 simulated articles completed their hard logic checks |

## New physical observations

Only the smallest and largest values are available, so an average and standard deviation cannot be calculated from this summary.

| Spacer label | Separate samples measured | Smallest reported | Largest reported | Observed range |
|---|---:|---:|---:|---:|
| 0.50 mm | 10 | 0.50 mm | 0.57 mm | 0.07 mm |
| 1.00 mm | 10 | 1.00 mm | 1.09 mm | 0.09 mm |
| 2.00 mm | 10 | 2.00 mm | 2.07 mm | 0.07 mm |

These ranges describe differences among the printed parts that were measured. They do not measure the accuracy or repeatability of the measuring instrument.

## Approved V1.11 change

For each newly built setup, the operator enters exactly one measured gap. That value becomes the actual gap used by the calculation. The requested build gap remains stored for comparison.

Because one reading cannot show measurement repeatability, saved results state **measurement uncertainty: not assessed**. The software does not turn a one-reading range of zero into a claim of zero uncertainty.

## Fresh V1.11 verification completed

| Check | Result |
|---|---|
| Focused one-reading checks | 73 passed, 0 failed |
| Complete V1.11 and recorder suite | 229 passed, 0 failed, 0 incomplete |
| Five direct 62-article simulations | All hard checks passed at 0.05, 0.10, 0.15, 0.25, and 0.50 mm usable steps |
| Standalone V1.11 `.mlx` in an empty folder | Passed |
| Real MATLAB R2022b pop-up route | Passed with one measurement per new setup |
| Separate general measurement recorder in an empty folder | Passed, including overwrite refusal |
| Defined verification matrix | 35 of 35 checks passed |
| V1.10 preservation | File matched its committed copy exactly |

## Remaining physical work

The software checks are complete. The physical setup still needs your own confirmation of which combined spacer-and-foil builds are repeatedly achievable. The 0.05 mm usable step remains provisional until that physical check is done.
