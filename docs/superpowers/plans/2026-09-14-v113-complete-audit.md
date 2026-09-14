# Neyer V1.13 Complete Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine whether V1.13 is the golden Neyer Gap Test release using independent, reproducible evidence across concept, mathematics, physical workflow, interface, records, and standalone packaging.

**Architecture:** Freeze V1.13 at its release hash and audit it through seven independent gates. New audit tests and evidence live under `tests/`, `tools/`, and `audit/v113-complete/`; production code remains unchanged unless a proven defect is first captured and moved to a separately versioned V1.14 candidate.

**Tech Stack:** MATLAB R2022b, `matlab.unittest`, PowerShell, CSV, Markdown, SHA-256

**Spec:** `docs/superpowers/specs/2026-09-14-v113-complete-audit-design.md`

## Global Constraints

- Keep `delivery/Neyer_Gap_Test_v1_13.mlx` byte-for-byte unchanged during the audit.
- Do not use the Pre-Test Planner to feed the direct Run a Test workflow.
- Use one measured gap reading per newly built setup.
- Display requested gaps with exactly two decimal places.
- Use the decreasing-interaction-with-gap direction.
- Use MATLAB R2022b and no unnecessary external dependency.
- State findings and evidence in jargon-free language.
- A correction, if needed, belongs only in a separately versioned V1.14 candidate after a failing regression test exists.

---

### Task 1: Freeze and inventory V1.13

**Files:**
- Create: `audit/v113-complete/release-fingerprint.txt`
- Create: `audit/v113-complete/component-map.csv`
- Test: `tests/TestV113CompleteAudit.m`

**Interfaces:**
- Consumes: `delivery/Neyer_Gap_Test_v1_13.mlx`, `delivery/Neyer_Gap_Test_v1_13.m`, and `application/source/*.m`.
- Produces: `release-fingerprint.txt` with commit, file size, and SHA-256; `component-map.csv` with `gate,source_file,public_function,purpose` columns.

- [x] **Step 1: Add a release-integrity test**

Add `testFrozenReleaseHash` to `tests/TestV113CompleteAudit.m`. It reads the MLX bytes with `fopen(...,'rb')`, hashes them with Java `MessageDigest.getInstance('SHA-256')`, and verifies the uppercase hexadecimal result equals `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E`.

- [x] **Step 2: Run the integrity test**

Run: `matlab -wait -batch "r=runtests('tests/TestV113CompleteAudit.m'); assert(~isempty(r),'No audit tests were selected.'); assertSuccess(r)"`

Expected: one passing test and no change to the V1.13 file.

- [x] **Step 3: Record the component inventory**

Run: `powershell -ExecutionPolicy Bypass -File tools/run_v113_complete_audit.ps1 -Phase inventory`

Expected: the fingerprint contains the release commit and expected hash; the component map names every file in `application/source` once or marks it as an internal helper.

### Task 2: Audit the Neyer concept and stage logic

**Files:**
- Create: `audit/v113-complete/concept-traceability.csv`
- Modify: `tests/TestV113CompleteAudit.m`
- Create: `tools/run_v113_stage_matrix.m`

**Interfaces:**
- Consumes: `choose_stage`, `has_overlap`, `pick_next_level`, `best_fit`, `neyer_settings`.
- Produces: `concept-traceability.csv` with `rule,source,evidence,status,plain_language_effect` columns and `stage-matrix.csv` with complete state transitions.

- [x] **Step 1: Encode the stage invariants**

Add tests that verify: Stage 1 begins at the midpoint and expands within confirmed bounds; Stage 2 begins only after both outcomes exist; Part 1 changes to Part 2 when the separated bracket is at most one working sigma; Part 2 multiplies working sigma by 0.8 after every still-separated result; Part 2 never returns to Part 1; Stage 3 begins only after strict overlap.

- [x] **Step 2: Run the stage tests**

Run: `matlab -wait -batch "r=runtests('tests/TestV113CompleteAudit.m','Tag','stage'); assert(~isempty(r),'No stage tests were selected.'); assertSuccess(r)"`

Expected: every legal transition passes and every illegal backward transition is rejected.

- [x] **Step 3: Reproduce the published 20-step reference sequence**

Run: `matlab -batch "run_v113_stage_matrix"`

Expected requested levels: `[1.00 1.20 1.40 1.80 2.60 4.20 3.40 3.80 4.00 4.10 4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]`; final estimates: middle `5.3922` mm, variation `1.0412` mm within `1e-4`.

### Task 3: Audit the mathematics independently

**Files:**
- Create: `tools/v113_independent_oracle.m`
- Modify: `tests/TestV113CompleteAudit.m`
- Create: `audit/v113-complete/math-comparisons.csv`

**Interfaces:**
- Consumes: recorded `(gap,outcome)` histories only; it must not call `loglik`, `best_fit`, `pick_next_level`, `lr_confidence`, `reliability_at_height`, or `height_for_reliability` from production.
- Produces: independent probability, maximum-likelihood, information-determinant, confidence-bound, and reliability calculations plus absolute differences from V1.13.

- [x] **Step 1: Implement the independent oracle**

Use `fminsearch` on parameters `[middle_gap, log(variation)]`, compute normal probabilities with `0.5*erfc(-z/sqrt(2))`, clamp only at `realmin`, and calculate the expected-information determinant directly from the normal density and cumulative probability equations.

- [x] **Step 2: Add fixed-data comparisons**

Compare the oracle and V1.13 for the paper replay, balanced synthetic data, narrow-transition data, wide-transition data, duplicate gap values, and data close to 0.00 and 10.00 mm. Require middle-gap and variation differences below `1e-4` where a finite fit exists; require identical D-optimal winning reachable gap on a shared candidate list.

- [x] **Step 3: Add confidence and reliability sanity checks**

Verify that probability decreases as gap increases, the 50/50 gap has approximately 50% best estimate, a 99% interaction gap lies below the middle gap, cautious probability is never above best-estimated probability, and unavailable one-sided bounds are shown as unavailable rather than as a usable number.

- [x] **Step 4: Run and save comparisons**

Run: `matlab -wait -batch "r=runtests('tests/TestV113CompleteAudit.m','Tag','math'); assert(~isempty(r),'No math tests were selected.'); assertSuccess(r)"`

Expected: all finite comparisons meet their tolerances and `math-comparisons.csv` contains no unexplained difference.

### Task 4: Audit physical gap selection and stopping

**Files:**
- Modify: `tests/TestV113CompleteAudit.m`
- Create: `tools/run_v113_physical_matrix.m`
- Create: `audit/v113-complete/physical-gap-matrix.csv`

**Interfaces:**
- Consumes: `reachable_gap_model`, `select_reachable_request`, `round_reachable_gap`, `check_study_checkpoint`, `parse_physical_response`.
- Produces: one row per resolution, boundary, repeated-choice, and explicit-list case.

- [x] **Step 1: Test regular reachable steps**

Exercise 0.05, 0.10, 0.15, and 0.50 mm steps from 0.00 to 10.00 mm. Verify every request is reachable, remains inside bounds, is printed with two decimals, and chooses the nearest different useful setting when the ideal repeats a previous setting.

- [x] **Step 2: Test explicit reachable lists**

Use deliberately irregular reachable gaps, including `[0 0.50 1.10 2.07 2.57 3.17 4.14 10.00]`. Verify selection never invents an intermediate value and clearly pauses when no different useful setting remains.

- [x] **Step 3: Test requested versus measured gaps**

For a requested 2.45 mm gap with a single measured reading of 2.50 mm, verify the stored analysis gap is 2.50 mm while the requested 2.45 mm remains in the audit record. Reject an empty, nonnumeric, negative, or out-of-range measured value with a plain-language message.

- [x] **Step 4: Run the physical matrix**

Run: `matlab -batch "run_v113_physical_matrix"`

Expected: all rows have `pass=true`; stopped rows contain a specific reason and do not report a failed test article.

### Task 5: Audit all user workflows and records

**Files:**
- Modify: `tests/TestV113CompleteAudit.m`
- Create: `tools/run_v113_workflow_audit.m`
- Create: `audit/v113-complete/workflow-matrix.csv`
- Create: `audit/v113-complete/save-record-audit.txt`

**Interfaces:**
- Consumes: menu, direct run, result, reliability, help, cancellation, and save callbacks in the standalone source.
- Produces: `workflow-matrix.csv` with `screen,action,expected,observed,status` columns and a save audit recording exact output paths and collision behavior.

- [x] **Step 1: Exercise menu and input paths**

Open each menu item; test valid direct-run input, empty input, text in numeric fields, reversed bounds, zero/negative variation, unreachable minimum, cancel, and window close. Require a recoverable plain-language response with no MATLAB stack trace presented to the user.

- [x] **Step 2: Exercise incomplete and fitted results**

Verify the early result says that no fit exists yet and disables reliability calculations; verify a fitted result labels middle gap, overall variation, confidence ranges, best-estimated chance, and cautious minimum without calling the middle gap “99% reliable.”

- [x] **Step 3: Verify saving and collision protection**

Save a complete run to a temporary user-selected folder, confirm the displayed destination matches the written files, verify CSV and HTML values agree with the screen, then save again using the same base name and require a new name or explicit confirmation instead of silent overwrite.

- [x] **Step 4: Run the workflow audit**

Run: `matlab -batch "run_v113_workflow_audit"`

Expected: every row passes; all temporary output remains under the test temporary folder.

### Task 6: Run adversarial simulations and performance checks

**Files:**
- Create: `tools/run_v113_audit_simulations.m`
- Create: `audit/v113-complete/simulation-summary.csv`
- Create: `audit/v113-complete/performance-summary.csv`

**Interfaces:**
- Consumes: direct `run_test` workflow with deterministic random seeds and one measured reading equal to the realized reachable setting.
- Produces: grouped recovery, stopping, repeated-setting, and runtime results.

- [x] **Step 1: Define the simulation matrix**

Run middle gaps `[1.5 5.0 8.5]`, true variations `[0.15 0.25 0.5 1.0 1.5]`, reachable steps `[0.05 0.10 0.15 0.50]`, starting variation guesses `[0.25 1.0 2.0]`, and maximum article counts `[20 62]`, with fixed seeds recorded in the output.

- [x] **Step 2: Execute with available local workers**

Use `parfor` only when Parallel Computing Toolbox is available; otherwise execute the same deterministic matrix serially. Never change an expected answer based on worker count.

- [x] **Step 3: Check invariants rather than invent performance claims**

For every run verify finite in-bound requests, no illegal stage reversal, no endless repeated request, honest pause reasons, positive fitted variation, decreasing probability direction, and identical results when rerunning the same seed. Summarize estimation error and overlap frequency without setting an unsupported universal accuracy threshold.

- [x] **Step 4: Save runtime evidence**

Record MATLAB version, toolbox availability, worker count, scenario count, elapsed time, and per-scenario median and maximum runtime in `performance-summary.csv`.

### Task 7: Verify the true standalone release

**Files:**
- Create: `tools/verify_v113_complete_clean_start.m`
- Create: `audit/v113-complete/standalone-clean-start.txt`
- Modify: `tests/TestV113CompleteAudit.m`

**Interfaces:**
- Consumes: only a copied `Neyer_Gap_Test_v1_13.mlx` in a fresh temporary directory.
- Produces: clean-start log containing MATLAB version, opened UI, demo values, direct-workflow result, save behavior, and dependency scan.

- [x] **Step 1: Copy only the MLX to a fresh folder**

Remove project folders from the MATLAB path, create a new temporary directory, and copy only the frozen MLX there. Assert the directory contains exactly one file before launch.

- [x] **Step 2: Run the main workflow from the isolated copy**

Open the tool, run the built-in demo, run a deterministic direct test to a fitted result, query reliability, save results, close all figures, and assert no helper `.m` file was required from the repository.

- [x] **Step 3: Run compatibility and dependency checks**

Attempt `matlab.codetools.requiredFilesAndProducts` on the extracted standalone source and record every required MathWorks product. If MATLAB's own dependency library is unavailable, record that installation limitation and use the clean-folder execution as the decisive outside-file check. Fail if a project-local file outside the MLX is required or loaded.

- [x] **Step 4: Save the clean-start log**

Run: `matlab -batch "verify_v113_complete_clean_start"`

Expected: the demo returns middle `5.3922` mm and variation `1.0412` mm, the direct workflow reaches a fit, saving succeeds without overwrite, and no outside project file is loaded.

### Task 8: Produce the golden-unit decision

**Files:**
- Create: `audit/v113-complete/findings.csv`
- Create: `audit/v113-complete/V113_COMPLETE_AUDIT.md`
- Create: `audit/v113-complete/evidence-manifest.txt`

**Interfaces:**
- Consumes: all evidence from Tasks 1-7.
- Produces: a self-contained plain-language decision and exact evidence hashes.

- [x] **Step 1: Run the complete existing and new test suites**

Run: `matlab -batch "r=run_tests; assertSuccess(r); r2=runtests('tests/TestV113CompleteAudit.m'); assertSuccess(r2)"`

Expected: zero failed and zero incomplete tests.

- [x] **Step 2: Build the findings matrix**

For every gate record `finding_id,gate,severity,what_was_checked,evidence,result,user_effect,recommended_action`. Use `Pass` rows as well as findings so absence of a problem is visibly supported.

- [x] **Step 3: Make the decision**

Declare V1.13 golden only if the spec's golden gate is met. If any Important or Critical finding remains, state that V1.13 is not golden, preserve the failing evidence, and write a separate V1.14 correction plan before any product edit.

- [x] **Step 4: Fingerprint all evidence**

Generate SHA-256 values for the frozen MLX, every audit CSV, every audit log, and the final Markdown report in `evidence-manifest.txt` so later changes are detectable.

## Self-review outcome

- Spec coverage: all seven audit gates and the frozen-change rule are assigned to Tasks 1-8.
- Placeholder scan: the plan contains no deferred implementation language.
- Interface consistency: all evidence is written under `audit/v113-complete/`; the consolidated test class is `tests/TestV113CompleteAudit.m`; both are consumed by the final decision task.
