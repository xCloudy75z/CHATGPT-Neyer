# Neyer Gap Test V2 — candidate release audit

Date: 2026-09-14. Platform: MATLAB R2022b on Windows. Status: all required execution and visual gates passed. This versioned candidate is ready for the final independent task review; that review follows the stable release commit. It has not been pushed or published.

## Verified mathematics retained

V2 retains the verified search direction, one-variation transition, repeated 0.8 reduction, two-step physical floor, strict overlap requirement, fitted estimates, confidence calculations and next-gap information calculation. Larger gaps continue to mean less interaction. The published 20-test example still gives middle **5.3922 mm** and overall variation **1.0412 mm**. Requested and measured gaps remain separate; one newly built setup receives one measured reading, which is used in the calculation.

The frozen V1.13 Live Script is unchanged. Its original audit is preserved, including its usability findings and earlier 272-test count. Current historical tests extract the frozen artifact, while V2 tests check the current application and V2 delivery.

## V2 corrections

Direct Run a Test now accepts a genuinely buildable regular step or an explicit confirmed gap list. The inputs explain their meaning, distinguish foil thickness from usable step, and keep the planner optional. Each test has one prominent two-decimal request. Unfinished results show a clear status and completed counts; calculated results retain both useful charts and simpler wording. Help is readable and scrollable.

The final visual review found and corrected a lower-Help formatting bug: 13 separated sentence fragments were replaced by the intended three complete paragraphs. The confidence and qualification warnings are now fully visible. The regression failed before correction and passed afterwards. No wording or numerical rule changed. The final MLX was rebuilt after that correction, then tested and fingerprinted without another rebuild.

## Executed evidence

| Gate | Final result |
|---|---|
| Complete desktop suite, including recorder and historical audit tests | **321 passed; 0 failed; 0 incomplete** |
| Exact regular matrix | **1,800 studies; 1,800 exact replays; 0 invariant failures; 0 replay mismatches** |
| Irregular confirmed-list matrix | **450 studies; 450 exact replays; 0 invariant failures; 0 replay mismatches** |
| Transcript/source check | All **2,250** complete transcripts rechecked against the final source fingerprints |
| Visual review | All **16 PNGs** inspected at original size, including every lower Help section; pass |
| Clean-folder repeat | The MLX opened with no project helpers; **63 embedded source files, 164 function declarations** |
| Direct standalone workflow | 20 recorded results, one reading per setup, two-decimal requests, published result reproduced |
| Saving and collision | Actual CSV and HTML written to intended paths; same-name second save rejected without changing either file |

The regular matrix used every combination of steps 0.05/0.10/0.15/0.50, middle gaps 1.5/5/8.5, true variations 0.15/0.25/0.5/1/1.5, starting guesses 0.25/1/2, budgets 20/62 and five seeds. The list matrix used the three specified sparse irregular lists, the same middle gaps, variations and budgets, starting guess 1, and five seeds. Four independent MATLAB processes ran the shards. Every request was finite, within bounds and a member of its physical model. No accidental immediate duplicate occurred. Boundary pauses had the required confirmation, stages did not reverse, and fitted probability direction was correct.

Reproduction commands and checkpoint rules are in `REPRODUCE.md`. Exact test names are in `full-suite-results.txt`; full transcripts and per-study checks are in `matrices`; real saved files and clean-start evidence are in `clean-start`; screenshot decisions are in `ui/visual-review.md`. `integration-corrections.md` records the initial failures and their resolution. The separately named pre-final matrices are superseded evidence, not the release gate results. No final conclusion depends on an ignored diary or an uncommitted audit file.

## Fingerprints

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Frozen V1.13 MLX | 73,466 | `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E` |
| Generated V2 M | 290,638 | `BD79D40DEC70C35D1E21012D22321AADD11392CF8D553B5F40F5B45DF3E2411C` |
| Final V2 MLX | 79,490 | `DD5C96C42FE18E4937E53FDF528022CAFBD16913895FE9549E5954B13F42B496` |

Git preserves the generated source and sealed evidence bytes without line-ending conversion. `release-fingerprint.txt` records the final gate totals with these hashes.

## Deliberately excluded and remaining limits

No direct-workflow spacer-combination recipe generator, planner redesign, statistical-rule change, internal compatibility-name rewrite, PowerPoint rebuild or general website/report rebuild was added. Saved result records do not resume a live test session.

A confirmed list is only as trustworthy as the user's physical confirmation. Simulated studies verify software behavior, not the buildability of actual spacer setups or a physical qualification claim. Sparse lists can correctly pause when no different useful setting remains. The changing-gap study is distinct from a separately justified fixed-gap qualification. These checks cover the tested MATLAB release and screen sizes, not every future platform.

## Delivery boundary

Only this V2-specific report and `Neyer_Gap_Test_v2.mlx` are delivered into a new versioned folder under `C:/Users/games/OneDrive/CHATGPT-Neyer/V2/2026-09-14-candidate-01`. Older versions are preserved. The separate `onedrive-delivery.txt` records the post-copy size/hash comparison. OneDrive's process was running, but this environment did not provide a verifiable cloud-upload status. The delivery claim is a matching **local OneDrive copy**, not confirmed cloud synchronization.
