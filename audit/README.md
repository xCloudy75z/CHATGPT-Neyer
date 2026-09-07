# Audit summary

The original V1.8 file was preserved before any algorithm change. Its SHA-256 fingerprint is:

`C2D709060E1F784535960F27682586F66C8E908C6EF90C8DF035CE099646C424`

## Main findings

| Area | Original V1.8 finding | Final V1.9 treatment |
|---|---|---|
| Stage 1 | The simplified outward search reproduced Table 1 but did not implement the full bound-aware rule. | Uses the full bound-aware rule in the correct decreasing-gap direction. |
| Stage 2 transition | The 1.5 sigma threshold came from reconstructing Table 1. | Part 1 changes at one guessed sigma. |
| Stage 2 shrink | The 0.8 setting existed but the decision loop did not use it. | Multiplies the working sigma by 0.8 after every separated Part-2 result. |
| Stage 2 state | An intermediate correction could return to bisection. | Part 2 is one-way and ends only after strict overlap. |
| Maximum-likelihood estimate | The core probit likelihood and positive sigma method agreed in principle. | Core retained with safeguards and regression tests. Extreme artificial cases remain a disclosed future study. |
| D-optimal selection | The information determinant agreed with Neyer. The grid and search fence were engineering choices. | Core retained and combined with physical reachable-gap selection. |
| Rounding | Two decimal places reproduced Table 1 but did not describe every tool increment. | Requires a confirmed 0.05 mm or 0.10 mm increment and records the measured mean. |
| Bounds and stopping | Repeated boundary clamping could look like a loop. | Confirms once, then pauses for review while preserving the test record. |

## Evidence

The published reference sequence was first locked in as a regression test. It could not reveal the missing repeated 0.8 shrink because its first Part-2 D-optimal test created overlap immediately.

The final combined physical study contains 129,600 synthetic runs. At a 50-test budget, the two-increment sigma floor produced 99.64% actual strict overlap and 0.00% false overlap in the recorded aggregate, while displayed middle-gap and transition-width error stayed unchanged.

The complete evidence, detailed tables, operating instructions, and limitations are in [`delivery/Neyer_Gap_Test_v1_9_Report.html`](../delivery/Neyer_Gap_Test_v1_9_Report.html).
