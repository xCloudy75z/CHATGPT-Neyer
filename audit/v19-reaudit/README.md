# V1.9 independent re-audit

This folder contains the second audit requested after the standalone V1.9 Live
Script was assembled. The exact `.mlx` candidate was frozen by SHA-256 before
testing. MATLAB's exported function source matched the readable application
source exactly after line-ending normalisation.

## Findings discovered during this re-audit

| Importance | Finding | Scope | Treatment |
|---|---|---|---|
| Important | The earlier combined physical simulation applied new-build variation to the actual/measured gap, but generated the binary outcome from the requested reachable setting. | Simulation evidence only; the operator application was not affected. | A failing regression test reproduced the mismatch. The simulator now generates the outcome from the actual built gap. The corrected rerun completed all 129,600 studies; earlier percentages are superseded. |
| Low | Several inherited internal comments described the old increasing break/survive direction even though the executable gap code used the correct decreasing interaction direction. | Documentation inside the standalone source; calculations and visible UI were correct. | Internal explanations were rewritten using interaction/no-interaction gap language and the correct `z = (middle - gap) / width` direction. |
| Environment | Parallel Computing Toolbox is not installed; `gcp` and `parpool` are unavailable. | Test execution speed only. | Four independent MATLAB R2022b processes ran deterministic scenario shards. A regression test proves merged shards equal an unsharded run. |

## Areas re-tested

- Stage 1 direction and prior-bound reach.
- Stage 2 transition at one guessed sigma.
- Repeated 0.8 Stage-2 shrink.
- One-way Part 2 state and strict-overlap exit.
- Maximum-likelihood direction, finite positive width, and known Demo result.
- D-optimal reference point and useful reachable Stage-2 choice.
- Minimum and maximum boundary confirmation and pause behavior.
- 0.05 mm and 0.10 mm reachable settings.
- Two-increment sigma floor.
- Four/five readings, measured mean, and a new spacer record per test.
- Standalone Live Script packaging and clean-folder operation.

The machine-readable test and corrected simulation evidence are stored here.
The separate self-contained HTML report is built under `delivery/`.
