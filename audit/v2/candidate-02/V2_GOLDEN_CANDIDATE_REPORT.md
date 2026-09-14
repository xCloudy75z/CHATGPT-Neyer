# Neyer Gap Test V2 — candidate-02 audit

Date: 2026-09-14. MATLAB R2022b on Windows. All execution and visual gates passed after the independent-review corrections below. The stable correction commit remains subject to the controller's independent review. No push, publication or OneDrive copy was performed in this wave.

## Verified mathematics retained

The search direction, one-variation transition, repeated 0.8 reduction, two-step physical floor, strict overlap requirement, fitted estimates, confidence calculations and next-gap calculation are unchanged. Larger gaps still mean less interaction. The published example remains **5.3922 mm middle / 1.0412 mm overall variation**. Each new setup receives one measured reading; that measured value, separate from the requested setting, enters the calculation.

Frozen V1.13 remains byte-identical. Its original audit and historical findings are preserved; historical tests execute its frozen artifact, not evolving V2 source.

## Review corrections

The prior candidate allowed confirmed settings with more precision than the two-decimal build instruction could display. Confirmed-list entries now must be expressible to two decimals (apart from floating-point representation tolerance); invalid finer entries are rejected rather than silently changing the requested physical setting. Direct testing now accepts millimetres only, preventing an entered unit such as inches from disagreeing with the mm labels and bounds. Both restrictions are explained beside the inputs and in Help. These are input-validation and wording corrections, not changes to the statistical method.

The controller supplied regression tests and verified the failing/passing correction cycle. The complete fresh suite below includes those tests. A new evidence-folder regression also failed before the version selector existed and passed after implementation. All release tools now support explicit candidate folders, so rerunning a corrected candidate does not overwrite earlier evidence.

## Fresh executed evidence

| Gate | Candidate-02 result |
|---|---|
| Complete desktop suite, including recorder and historical tests | **323 passed; 0 failed; 0 incomplete** (192.002 seconds) |
| Exact regular matrix | **1,800 studies; 1,800 full replays; 0 invariant failures; 0 replay mismatches** |
| Confirmed-list matrix | **450 studies; 450 full replays; 0 invariant failures; 0 replay mismatches** |
| Final source/transcript check | **2,250** complete transcripts rechecked against final source fingerprints |
| Visual review | All **16 PNGs** inspected at original resolution; pass, including mm-only wording, two-decimal list guidance and lower Help |
| Clean-folder repeat | MLX initially the only file; menu opened; **63 embedded source files / 164 function declarations**; no outside application helper used |
| Standalone physical workflow | 20 results; one reading per setup; two-decimal requests; published result reproduced |
| Actual save and collision | CSV/HTML paths matched displayed destinations; same-name second save rejected without replacing either file |

Four independent MATLAB processes ran fresh regular shards of 450 studies each and list shards of 113, 113, 112 and 112 studies. The regular matrix uses all steps 0.05/0.10/0.15/0.50, middles 1.5/5/8.5, true variations 0.15/0.25/0.5/1/1.5, starting guesses 0.25/1/2, budgets 20/62 and five repetitions. The list matrix uses the three specified irregular lists with those middles, variations and budgets, starting guess 1 and five repetitions. Each study has a deterministic seed and full replay: 2,250 studies mean 4,500 executions.

All requests were finite, within bounds and members of the selected physical model. There were no accidental immediate duplicates. Boundary pauses followed the required confirmation; stages did not reverse; budgets and one-reading rules held; fitted probability direction was correct.

The final build preceded these gates. Fingerprinting performed no build, and no rebuild followed fingerprinting. Reproduction instructions, per-test results, complete MAT transcripts, CSV checks, real saved results, screenshots and review notes are retained in this candidate folder. The manifest verifies their sizes and SHA-256 values. Final claims do not depend on ignored desktop logs or the ignored task-working report.

## Final artifact fingerprints

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| Frozen V1.13 MLX | 73,466 | `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E` |
| V2 M | 291,305 | `DD37A1CCB92745FE85489620F2AACC1658064D9E44077F757779646E10ED278E` |
| V2 MLX | 79,649 | `9CF600D241F1430EEA489C2A13A2AF9BD10CC579C5134193DAD26ECFA3A01038` |

## Preserved history and delivery boundary

Candidate-01 evidence remains unchanged under the parent `audit/v2` folder. Its exact M and MLX are retained under `audit/v2/candidate-01-artifacts`; all 65 original manifest entries still match when its two former delivery paths are resolved to those retained copies. The previous 321-test count and previous hashes describe candidate-01, not this corrected candidate.

The existing OneDrive folder `C:/Users/games/OneDrive/CHATGPT-Neyer/V2/2026-09-14-candidate-01` still contains the older candidate. It has not been updated by this wave. Its earlier local hash verification does not prove cloud upload and does not certify delivery of candidate-02. A new authorized delivery must copy this candidate's MLX and this report into a new versioned folder after review.

## Excluded ideas and limits

No spacer-recipe generator, planner redesign, statistical-rule change, PowerPoint rebuild or general website/report rebuild was added. Saved records do not resume a live test session. Direct testing is mm-only; confirmed build settings must use at most two decimal places, while the single actual measured reading may retain finer precision.

A confirmed list is only as trustworthy as the user's physical confirmation. Simulations check software behavior, not physical buildability or qualification. Sparse lists can correctly pause when no different useful setting remains. Fixed-gap qualification remains a separate, justified study. Visual checks cover the captured window sizes on MATLAB R2022b, not every display/platform; saving was exercised through the actual embedded save routine, not a manual file-picker walkthrough.
