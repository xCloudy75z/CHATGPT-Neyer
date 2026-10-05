# Neyer Gap Test V1.15 result-window update

## User-facing changes

- Removed the 95% confidence ranges and explanation from the calculated result window.
- Removed the result-window direction sentence.
- Removed the cautious-minimum probability and its confidence wording from the one-gap calculator.
- Kept the central fitted probability and now display it as `best estimated chance`.
- Allowed the central estimate to display even when the removed confidence bound is unavailable.

## Unchanged calculations

The middle-gap estimate, overall-variation estimate, probability curve, test-stage logic, D-optimal selection, physical-gap mapping, and stopping rules were not changed.

## Verification

MATLAB R2022b completed the V1.15 release verification:

| Check | Result |
|---|---:|
| Standalone Live Script build | Pass |
| Embedded-function round trip | Pass |
| Full relevant MATLAB suite | 229 passed |
| Failed checks | 0 |
| Incomplete checks | 0 |
| Clean start with only the V1.15 `.mlx` | Pass |
| Public-site package validation | Pass |

V1.14 remains available as the previous preserved release.
