# V1.13 Complete Audit Design

## Purpose

Decide, with reproducible evidence, whether `delivery/Neyer_Gap_Test_v1_13.mlx` is the golden release. The audit covers the Neyer method, numerical calculations, adaptive test choices, physical gap handling, user interface, saved records, failure handling, compatibility, and standalone packaging.

## Non-negotiable rules

- Keep the released V1.13 file byte-for-byte unchanged during the audit.
- Run the tool directly, without requiring a Pre-Test Planner plan.
- Use one physical gap measurement for each newly built test setup.
- Show requested gaps to two decimal places.
- Treat a larger gap as making interaction less likely.
- Use 0.00 mm as the physical lower limit and 10.00 mm as the known no-interaction upper working limit in the representative workflow.
- Support regular reachable steps and an explicit list of reachable gaps.
- Never silently replace the measured gap with the requested gap.
- Never silently overwrite saved work.
- Use jargon-free user-facing language.
- Support MATLAB R2022b without unnecessary external dependencies.
- Separate Neyer curve estimation from the optional zero-failure qualification calculation.

## Frozen reference

- File: `delivery/Neyer_Gap_Test_v1_13.mlx`
- Release commit: `767a1b4464d946ad00c3f4532caeae0644927dc2`
- Expected SHA-256: `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E`
- Paper replay final estimate: middle gap 5.3922 mm and overall variation 1.0412 mm.

## Decision scale

| Result | Meaning |
|---|---|
| Pass | Evidence agrees with the stated rule. |
| Minor | Confusing or inconvenient, but does not change the calculation or stored test history. |
| Important | Can mislead the operator, corrupt a workflow, or materially change a result. |
| Critical | Can produce an unsafe or fundamentally false conclusion in normal use. |

V1.13 is golden only when there are no Critical or Important findings, all required automated tests pass, the standalone clean-start check passes, and the complete main workflow is understandable and internally consistent.

## Required evidence

1. A source-to-rule map for Stage 1, Stage 2, overlap, maximum-likelihood fitting, D-optimal choice, bounds, rounding, and stopping.
2. Independent numerical comparisons that do not call the production calculation being checked.
3. State-transition coverage, including repeated requested gaps and unreachable ideal choices.
4. Physical-gap checks for 0.05, 0.10, 0.15, and 0.50 mm resolutions plus explicit reachable lists.
5. Simulations covering narrow, normal, and wide response curves and both easy and difficult starting guesses.
6. Main-menu, input, test-entry, result, reliability, help, cancel, invalid-input, and save-path checks.
7. Clean MATLAB start with only the V1.13 `.mlx` present.
8. A plain-language findings matrix and a final go/no-go decision.

## Change rule

Audit evidence may add tests, audit scripts, and reports. It must not edit the V1.13 `.mlx` or its V1.13 generated source. If a proven defect requires a product change, first preserve a failing regression test and then make the correction only in a new V1.14 candidate.
