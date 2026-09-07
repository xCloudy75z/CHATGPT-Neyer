# Neyer Pre-Test Planner and Reliability Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the fixed-gap confidence calculation, replace the ambiguous pre-test planner with the approved two-mode planner, integrate physical buildability and checkpoint rules, rebuild the standalone Live Script, and verify the complete laboratory workflow.

**Architecture:** Keep the existing tested Neyer engine intact except where a failing regression test proves a correction is required. Add small pure MATLAB functions for planning, reachable gaps, checkpoint decisions, and JSON storage; let the user-interface functions only collect inputs and present those tested results. Generate the standalone `.mlx` from the reviewed source files, then verify that it contains all runtime functions and needs no outside code.

**Tech Stack:** MATLAB R2022b, `matlab.unittest`, MATLAB UI figures, JSON (`jsonencode`/`jsondecode`), HTML/CSS for the verification report, PowerShell build scripts.

**Spec:** `docs/superpowers/specs/2026-09-07-pretest-planner-and-reliability-design.md`

## Global Constraints

- Use clear, jargon-free words in every user-visible screen, error, saved plan, and report.
- Preserve the recorded V1.8 reference-table behavior unless a separate failing test and approved correction justify a change.
- The normal application direction is: a larger gap makes Interaction less likely.
- Reliability and confidence accept 10% through 99.9%; confidence below 50% is clearly exploratory.
- Requested build instructions display exactly two decimal places.
- Four or five measurements belong to one new setup and produce one test article at their average measured gap.
- The `.mlx` must run alone in MATLAB R2022b without an outside function folder.
- Do not silently replace a saved plan or result file.
- Physical spacer measurements remain labelled unconfirmed until the user supplies the planned measurements.
- Use up to four independent MATLAB processes only for deterministic simulation shards; validate every shard before merging.
- The overnight package contains the standalone `.mlx` and a self-contained HTML report; it does not add a PowerPoint.

## File Structure

| Area | Responsibility |
|---|---|
| `application/source/reliability_at_height.m` | Best probability and the cautious lower confidence value at one physical gap |
| `application/source/validate_plan_inputs.m` | Validate and normalize both planner modes in one place |
| `application/source/reachable_gap_model.m` | Convert increments, spacer/foil combinations, or a confirmed list into reachable gaps |
| `application/source/round_reachable_gap.m` | Apply direction-safe rounding and avoid repeated settings |
| `application/source/estimate_study_plan.m` | Produce main, reserve, total, assumptions, and feasibility from requirements |
| `application/source/estimate_supported_targets.m` | Show what a fixed available quantity may support without calling it a guarantee |
| `application/source/check_study_checkpoint.m` | Decide whether main/reserve checkpoints have enough evidence or explain what is missing |
| `application/source/save_study_plan.m`, `load_study_plan.m` | Human-readable versioned JSON with overwrite protection |
| `application/source/pretest_planner_ui.m` | Guided planner window; no statistical calculations inside callbacks |
| `application/source/neyer_app.m`, `run_test_ui.m`, `show_result.m` | Integrate plan, test, checkpoint, and result screens |
| `simulation/run_planner_validation_shard.m` | Recorded deterministic virtual studies for one shard |
| `simulation/merge_planner_validation.m` | Reject missing/duplicate/mismatched shards and summarize accepted evidence |
| `tools/build_standalone_v110.ps1`, `tools/build_v110_mlx.m` | Build the one-file source and `.mlx` candidate |
| `tools/run_overnight_mock_lab.m` | Clean, repeatable end-to-end verification runner |
| `tools/build_overnight_report.ps1` | Produce the self-contained evidence report |
| `tests/TestFixedGapConfidence.m` | Regression coverage for the confirmed probability-at-gap defect |
| `tests/TestPreTestPlanner.m` | Planner modes, input meaning, quantities, reserves, and explanations |
| `tests/TestReachableGapModel.m` | Regular, spacer/foil, irregular list, rounding, and repetition behavior |
| `tests/TestStudyCheckpoint.m` | Main/reserve stopping decisions and unmet-condition explanations |
| `tests/TestStudyPlanStorage.m` | Save, reopen, version check, and no-overwrite behavior |
| `tests/TestV110Standalone.m` | Self-contained file and clean-start checks |

---

### Task 1: Freeze the Starting Evidence

**Files:**
- Modify: `.gitignore`
- Create: `audit/overnight/baseline-test-summary.txt`
- Create: `audit/overnight/confirmed-fixed-gap-defect.csv`
- Test: existing `tests/*.m`

**Interfaces:**
- Consumes: current V1.9 source, 104-test baseline, and `audit/run_reliability_bound_grid.m`.
- Produces: immutable before-change evidence used by the report.

- [ ] **Step 1: Protect local-only material**

Add `.superpowers/`, `FROM CLAUDE/`, MATLAB UI scratch images, transient shard files, and local launch sentinels to `.gitignore`; do not remove the user-supplied folders.

- [ ] **Step 2: Run the complete current suite**

Run a MATLAB R2022b desktop-command runner that calls:

```matlab
suite = testsuite(fullfile(projectRoot,'tests'),'IncludeSubfolders',true);
result = run(suite);
assertSuccess(result);
```

Expected: the recorded baseline count passes before production edits. Save the exact counts, MATLAB release, start/end times, and command route.

- [ ] **Step 3: Reproduce the defect**

Run the fixed grid for Interaction and No interaction. Save point and claimed-bound probabilities at 2, 3, 4, 4.61, 5, 6, 7, and 8 mm.

Expected: at least one current claimed minimum exceeds its best estimate and the extreme cases reproduce the artificial floor.

- [ ] **Step 4: Commit only the evidence and ignore rules**

```powershell
git add .gitignore audit/overnight/baseline-test-summary.txt audit/overnight/confirmed-fixed-gap-defect.csv docs/superpowers/specs/2026-09-07-pretest-planner-and-reliability-design.md docs/superpowers/plans/2026-09-07-pretest-planner-and-reliability.md
git commit -m "docs: freeze approved planner design and baseline evidence"
```

### Task 2: Correct the Fixed-Gap Confidence Boundary

**Files:**
- Create: `tests/TestFixedGapConfidence.m`
- Modify: `application/source/reliability_at_height.m`

**Interfaces:**
- Consumes: `reliability_at_height(levels, successes, tail, gap, confidence)` where legacy `break` means No interaction at a larger gap and `survive` means Interaction at a smaller gap.
- Produces: unchanged result structure with `bound <= reliability` and a one-sided cautious lower probability.

- [ ] **Step 1: Write failing direction tests**

Add tests using the recorded reference data:

```matlab
interaction = reliability_query(referenceResult,'interaction','probability_at',3.00,0.95);
noInteraction = reliability_query(referenceResult,'no_interaction','probability_at',6.00,0.95);
testCase.verifyLessThanOrEqual(interaction.bound_probability,interaction.probability);
testCase.verifyLessThanOrEqual(noInteraction.bound_probability,noInteraction.probability);
```

Also assert finite non-floor values at representative low, middle, and high gaps and monotone point probabilities.

- [ ] **Step 2: Run only the new class and confirm failure**

```matlab
result = run(testsuite('tests/TestFixedGapConfidence.m'));
assert(any([result.Failed]));
```

Expected: the inequality tests fail against the existing code.

- [ ] **Step 3: Make the smallest mathematical correction**

Keep the best probability unchanged. Search the profile in the direction that lowers the selected physical outcome: larger standardized distance for Interaction and smaller standardized distance for No interaction. Rename local variables/comments so their physical meaning is unambiguous.

- [ ] **Step 4: Run focused and existing reliability tests**

Expected: `TestFixedGapConfidence` and `TestGapReliability` pass, and the centre probabilities/target-gap values remain at their existing regression values.

- [ ] **Step 5: Commit**

```powershell
git add application/source/reliability_at_height.m tests/TestFixedGapConfidence.m
git commit -m "fix: use cautious side of fixed-gap confidence profile"
```

### Task 3: Define Plain Planner Inputs

**Files:**
- Create: `application/source/validate_plan_inputs.m`
- Create: `tests/TestPreTestPlanner.m`

**Interfaces:**
- Consumes: a struct with `mode`, `outcome`, `reliability`, `confidence`, `accuracy_mm`, `interaction_gap_mm`, `no_interaction_gap_mm`, `minimum_gap_mm`, `maximum_gap_mm`, `previous_information`, `available_articles`, and `physical_setup`.
- Produces: `[clean, messages] = validate_plan_inputs(input)`; throws named, plain-language errors for invalid values.

- [ ] **Step 1: Write validation tests**

Cover 0.10, 0.499, 0.50, 0.95, and 0.999 confidence; 0.10 and 0.999 reliability; missing outcome; reversed almost-always gaps; minimum equal to maximum; unavailable article count; and accuracy outside the permitted range.

- [ ] **Step 2: Verify the tests fail because the function is absent**

Run `TestPreTestPlanner` only. Expected: undefined-function failure.

- [ ] **Step 3: Implement normalization and explanations**

Normalize percentages entered as either `95` or `0.95` to `0.95`. Return a warning message below 50%, a no-margin message at 50%, and a conservative message above 50%. Require an explicit outcome.

- [ ] **Step 4: Run focused tests and commit**

```powershell
git add application/source/validate_plan_inputs.m tests/TestPreTestPlanner.m
git commit -m "feat: define plain pre-test planner inputs"
```

### Task 4: Model Reachable Physical Gaps

**Files:**
- Create: `application/source/reachable_gap_model.m`
- Create: `application/source/round_reachable_gap.m`
- Create: `tests/TestReachableGapModel.m`

**Interfaces:**
- Consumes: `physical_setup` with mode `regular`, `combinations`, or `list`, plus permitted bounds.
- Produces: `model.gaps_mm`, `model.description`, `model.resolution_summary`; `[gap, status] = round_reachable_gap(rawGap, outcome, model, previousGap)`.

- [ ] **Step 1: Write failing model tests**

Test regular increments 0.05, 0.10, 0.15, and 0.50 mm; an irregular list; two-decimal display; empty capability; out-of-range capability; and duplicate removal.

- [ ] **Step 2: Write failing safe-rounding tests**

For the normal gap direction, assert Interaction rounds at or below the mathematical boundary, No interaction rounds at or above it, and a repeated suggestion selects the nearest different useful setting or returns an explicit no-setting status.

- [ ] **Step 3: Implement bounded reachable sets**

For combination mode, use supplied measured component values and maximum counts; do not treat nominal unconfirmed spacer values as certified measurements. Deduplicate with a documented tolerance and preserve the exact reachable list used.

- [ ] **Step 4: Run focused tests and commit**

```powershell
git add application/source/reachable_gap_model.m application/source/round_reachable_gap.m tests/TestReachableGapModel.m
git commit -m "feat: model and safely round reachable physical gaps"
```

### Task 5: Build the Requirements-First Quantity Estimate

**Files:**
- Create: `application/source/estimate_study_plan.m`
- Modify: `application/source/plan_samples.m`
- Modify: `application/source/plan_prep_numbers.m`
- Modify: `application/source/plan_prep_message.m`
- Test: `tests/TestPreTestPlanner.m`

**Interfaces:**
- Consumes: validated planner input and a reachable-gap model.
- Produces: a plan struct containing `main_articles`, `reserve_1_articles`, `reserve_2_articles`, `total_articles`, `starting_gap_mm`, `assumptions`, `feasible`, `suggestions`, `validation_basis`, and requested targets.

- [ ] **Step 1: Add failing quantity-behavior tests**

Assert that tighter accuracy cannot reduce quantity, higher confidence above 50% cannot reduce quantity, more extreme reliability cannot reduce quantity, and poorer physical capability cannot be reported as equally feasible. Assert the hidden `0.5*sigma` rule is absent from user explanations.

- [ ] **Step 2: Add first-study assumption tests**

Assert that almost-always endpoints are interpreted as at least 95%, assumptions are displayed, and a too-wide unknown range produces a labelled discovery-study suggestion instead of a false guarantee.

- [ ] **Step 3: Implement the published starting estimate**

Use the Neyer/Banerjee variance relationships and the `N-15` spread correction as a starting estimate. Keep covariance treatment and uncertainty additions explicit in returned fields. Accuracy is the user-entered millimetre target, not a hidden fraction of sigma.

- [ ] **Step 4: Allocate declared reserve groups**

Compute main, reserve 1, and reserve 2 from named expected/moderate/difficult assumptions. Store the rule version so later simulation can calibrate it without changing old saved plans silently.

- [ ] **Step 5: Run planner tests and commit**

```powershell
git add application/source/estimate_study_plan.m application/source/plan_samples.m application/source/plan_prep_numbers.m application/source/plan_prep_message.m tests/TestPreTestPlanner.m
git commit -m "feat: estimate main and reserve Neyer study quantities"
```

### Task 6: Build the Available-Articles-First Estimate

**Files:**
- Create: `application/source/estimate_supported_targets.m`
- Test: `tests/TestPreTestPlanner.m`

**Interfaces:**
- Consumes: validated physical/accuracy input, article count, and either fixed reliability or fixed confidence.
- Produces: a table-like struct of candidate pairs plus `statement = 'pre-test expectation, not a final claim'`.

- [ ] **Step 1: Write failing inverse-planner tests**

Assert that adding articles cannot reduce the displayed achievable confidence for fixed reliability, cannot reduce reliability for fixed confidence, and never uniquely invents both values.

- [ ] **Step 2: Implement a bounded inverse search**

Evaluate only 10%–99.9%, retain the fixed user choice, and return the highest candidate supported by the same rule version as Task 5. Include a warning when the physical accuracy prevents a meaningful estimate.

- [ ] **Step 3: Run tests and commit**

```powershell
git add application/source/estimate_supported_targets.m tests/TestPreTestPlanner.m
git commit -m "feat: estimate targets from available articles"
```

### Task 7: Add Main and Reserve Checkpoints

**Files:**
- Create: `application/source/check_study_checkpoint.m`
- Create: `tests/TestStudyCheckpoint.m`

**Interfaces:**
- Consumes: current result/history, saved plan, and checkpoint name `main`, `reserve_1`, or `reserve_2`.
- Produces: `decision.status` (`complete`, `ask_for_reserve`, or `unsupported`), `missing_conditions`, `plain_explanation`, and `next_checkpoint`.

- [ ] **Step 1: Write failing checkpoint tests**

Cover one outcome only, no overlap, unbounded fit, accuracy not met, reliability boundary outside bounds, no safe reachable setting, complete main group, explicit reserve request, and exhausted reserves.

- [ ] **Step 2: Implement all six evidence checks**

Do not call an incomplete statistical study a failed physical test. Do not consume reserves automatically. Check only at pre-declared checkpoint counts.

- [ ] **Step 3: Run tests and commit**

```powershell
git add application/source/check_study_checkpoint.m tests/TestStudyCheckpoint.m
git commit -m "feat: add declared study checkpoints and reserve decisions"
```

### Task 8: Save and Reopen a Study Plan Safely

**Files:**
- Create: `application/source/save_study_plan.m`
- Create: `application/source/load_study_plan.m`
- Create: `tests/TestStudyPlanStorage.m`

**Interfaces:**
- Consumes: plan struct and exact user-selected `.json` path.
- Produces: saved path or a named error; loaded normalized plan with supported-version check.

- [ ] **Step 1: Write failing storage tests**

Test readable JSON fields, exact selected location, full-path return, round trip, unsupported version, missing file, invalid JSON, and refusal to replace an existing file.

- [ ] **Step 2: Implement stable plan schema**

Include version/date, mode, targets, bounds, reachable definition, quantities, assumptions, validation basis, and checkpoint status. Save UTF-8 indented JSON when R2022b supports it; otherwise write valid readable JSON without an outside library.

- [ ] **Step 3: Run tests and commit**

```powershell
git add application/source/save_study_plan.m application/source/load_study_plan.m tests/TestStudyPlanStorage.m
git commit -m "feat: save and reopen versioned study plans safely"
```

### Task 9: Build the Guided Planner and Link It to Testing

**Files:**
- Create: `application/source/pretest_planner_ui.m`
- Modify: `application/source/neyer_app.m`
- Modify: `application/source/run_test_ui.m`
- Modify: `application/source/run_physical_test.m`
- Modify: `application/source/show_manual.m`
- Test: `tests/TestPhysicalUiInputs.m`
- Test: `tests/TestPhysicalRunEntryPoint.m`

**Interfaces:**
- Consumes: Tasks 3–8 pure functions.
- Produces: guided Plan → Prepare → Test → Check → Finish workflow and optional loaded-plan context for `run_test_ui`.

- [ ] **Step 1: Add UI-source behavior tests**

Assert the planner contains both modes, plain explanations below each question, no normal “transition width” input, explicit outcome choice, first-study default, full save destination preview, and no-overwrite wording.

- [ ] **Step 2: Implement the guided planner window**

Use the approved colors and hierarchy. Put calculations in pure functions, not callbacks. Show main/reserve totals, assumptions, feasibility, and alternatives before offering Save Plan.

- [ ] **Step 3: Link saved plans to Run a Test**

Allow loading a plan at the start of a run. Display planned quantity/checkpoint and preserve the requested gap, all four/five readings, average measured gap, result, and reachable capability.

- [ ] **Step 4: Enforce two-decimal build instructions**

Only the requested construction instruction is rounded for display. Preserve full measurement precision and use the actual average for fitting.

- [ ] **Step 5: Run UI parsing/entry tests and commit**

```powershell
git add application/source/pretest_planner_ui.m application/source/neyer_app.m application/source/run_test_ui.m application/source/run_physical_test.m application/source/show_manual.m tests/TestPhysicalUiInputs.m tests/TestPhysicalRunEntryPoint.m
git commit -m "feat: add guided planner and plan-linked test workflow"
```

### Task 10: Make Results Physically Actionable

**Files:**
- Modify: `application/source/reliability_query.m`
- Modify: `application/source/show_result.m`
- Modify: `application/source/draw_interaction_curve.m`
- Modify: `application/source/results_to_html.m`
- Modify: `application/source/format_result_text.m`
- Test: `tests/TestGapPresentation.m`
- Test: `tests/TestGapReliability.m`

**Interfaces:**
- Consumes: fitted result, selected outcome/R/C, permitted bounds, and reachable model.
- Produces: supported/not-supported decision, safe reachable instruction, middle/confidence range, overall variation, evidence label, and two complementary graphs.

- [ ] **Step 1: Add failing result-priority tests**

Assert that middle gap is never labelled 99% reliable, “overall variation” is explained, confidence-protected probability cannot exceed best probability, Interaction says “this gap or smaller,” No interaction says “this gap or larger,” and out-of-range boundaries are “not established.”

- [ ] **Step 2: Add physical operating-gap tests**

Assert safe rounding by outcome, exact two-decimal instruction, and explicit failure when no safely rounded reachable gap exists.

- [ ] **Step 3: Implement the result hierarchy**

Place decision and operating instruction first, estimates second, assumptions/evidence third, and graphs/details last. Keep the existing distribution view and add the response-probability curve beside it.

- [ ] **Step 4: Run focused result tests and commit**

```powershell
git add application/source/reliability_query.m application/source/show_result.m application/source/draw_interaction_curve.m application/source/results_to_html.m application/source/format_result_text.m tests/TestGapPresentation.m tests/TestGapReliability.m
git commit -m "feat: present cautious reachable operating results"
```

### Task 11: Calibrate the Planner with Recorded Virtual Studies

**Files:**
- Create: `simulation/run_planner_validation_shard.m`
- Create: `simulation/merge_planner_validation.m`
- Create: `simulation/planner-validation-config.json`
- Create: `tests/TestPlannerSimulation.m`
- Create: `audit/overnight/planner-validation-summary.csv`

**Interfaces:**
- Consumes: fixed seed range, quantity rule version, true middle/spread, outcome targets, confidence, reliability, accuracy, gap capability, and checkpoint policy.
- Produces: one row per unique scenario/seed plus a validated merged summary.

- [ ] **Step 1: Test deterministic sharding and merge rejection**

Use tiny scenarios to prove repeatability, unique scenario keys, expected row counts, and rejection of missing, duplicate, or configuration-mismatched shards.

- [ ] **Step 2: Define the recorded scenario grid**

Include sudden/expected/gradual curves, confidence 10%, 49.9%, 50%, 95%, 99.9%, reliability across the approved range, 0.05/0.10/0.15/0.50 mm increments, irregular lists, measurement variation, new-build variation, and main/reserve checkpoints.

- [ ] **Step 3: Run a pilot shard**

Confirm runtime, output schema, and that known impossible combinations are withheld. Do not start full shards until pilot checks pass.

- [ ] **Step 4: Run up to four independent MATLAB shards**

Each process writes a different file and records its seed interval/configuration hash. Keep the user informed at meaningful milestones.

- [ ] **Step 5: Merge and apply the pass rules**

Require usable-fit rate at least `max(95%, requested confidence)`, correct middle coverage, cautious reliability boundary, physically reachable safe setting, and correct checkpoint behavior. If a candidate quantity fails, increase quantities or label the request unsupported; never weaken targets silently.

- [ ] **Step 6: Re-run affected planner unit tests and commit**

```powershell
git add simulation/run_planner_validation_shard.m simulation/merge_planner_validation.m simulation/planner-validation-config.json tests/TestPlannerSimulation.m audit/overnight/planner-validation-summary.csv application/source/estimate_study_plan.m
git commit -m "test: calibrate planner with recorded virtual studies"
```

### Task 12: Rebuild the Standalone MATLAB Live Script

**Files:**
- Create: `tools/build_standalone_v110.ps1`
- Create: `tools/build_v110_mlx.m`
- Create: `delivery/Neyer_Gap_Test_v1_10.mlx`
- Create during build, do not deliver: `delivery/Neyer_Gap_Test_v1_10.m`
- Create: `tests/TestV110Standalone.m`
- Modify: `application/README.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: reviewed `application/source/*.m` functions.
- Produces: one `.mlx` containing every runtime function as local code; generated plan/result JSON/CSV/HTML files are data, not dependencies.

- [ ] **Step 1: Add failing standalone checks**

Assert the candidate exists, embeds every required local function, contains no `addpath`, companion-function reference, machine-specific path, `.exe` dependency, or silent-overwrite behavior, and explains R2022b operation/data saving.

- [ ] **Step 2: Generate the one-file source deterministically**

Use a declared ordered function list and fail if a required source is absent or duplicated. Keep the filename at `v1_10` because this is a controlled improvement after V1.9 rather than overwriting V1.9 evidence.

- [ ] **Step 3: Convert to `.mlx` in MATLAB R2022b**

Use `matlab.internal.liveeditor.openAndConvert` or the already proven R2022b conversion route. Record the MATLAB release and output fingerprint.

- [ ] **Step 4: Run static standalone tests and commit**

```powershell
git add tools/build_standalone_v110.ps1 tools/build_v110_mlx.m delivery/Neyer_Gap_Test_v1_10.mlx tests/TestV110Standalone.m application/README.md README.md
git commit -m "build: create standalone Neyer Gap Test v1.10"
```

### Task 13: Perform the Complete Mock Laboratory Verification

**Files:**
- Create: `tools/run_overnight_mock_lab.m`
- Create: `audit/overnight/mock-lab-results.csv`
- Create: `audit/overnight/full-test-summary.txt`
- Create: `audit/overnight/standalone-clean-start.txt`
- Create: `assets/screenshots/v110-*.png`

**Interfaces:**
- Consumes: the final source and standalone `.mlx` candidate.
- Produces: machine-readable route results, screenshots, and exact pass/fail evidence.

- [ ] **Step 1: Run preserved algorithm regressions**

Execute reference table, Stage 1, Stage 2 transition and 0.8 shrink, overlap, MLE, D-optimal selection, bounds, rounding, and stopping tests.

- [ ] **Step 2: Run planner routes**

Exercise both modes, first-study case, all confidence boundary classes, representative reliability values, all four regular increments, an irregular list, main/reserve decisions, and impossible requests.

- [ ] **Step 3: Run physical-entry routes**

Exercise four and five readings, requested-versus-measured mismatch, repeated setting avoidance, out-of-range reading, high reading range, and one destructive article per newly built setup.

- [ ] **Step 4: Run save/reopen/continue routes**

Use a temporary user-selected directory. Confirm exact save paths, JSON reopen, continued checkpoint state, and refusal to replace both plans and results.

- [ ] **Step 5: Launch the `.mlx` from a clean MATLAB desktop command**

Use no added source path. Exercise the main workflow programmatically where possible and verify that no external function resolution occurs.

- [ ] **Step 6: Capture and inspect every important screen**

Capture main menu, both planner modes, review plan, test inputs, requested gap, checkpoint, supported result, unsupported result, graphs, save preview, and help. Inspect legibility, clipping, labels, direction wording, units, and error visibility; fix and re-run any failed screen.

- [ ] **Step 7: Run the full suite**

Expected: zero failed and zero incomplete tests. Record total count, duration, MATLAB version, and exact candidate hash.

- [ ] **Step 8: Commit verification evidence**

```powershell
git add tools/run_overnight_mock_lab.m audit/overnight/mock-lab-results.csv audit/overnight/full-test-summary.txt audit/overnight/standalone-clean-start.txt assets/screenshots tests application delivery/Neyer_Gap_Test_v1_10.mlx
git commit -m "test: verify complete Neyer v1.10 laboratory workflow"
```

### Task 14: Build the Overnight HTML Evidence Report

**Files:**
- Create: `tools/build_overnight_report.ps1`
- Create: `delivery/Neyer_Overnight_Verification_Report.html`
- Create: `tools/validate_overnight_report.py`

**Interfaces:**
- Consumes: committed audit CSV/text evidence and inspected screenshots.
- Produces: one self-contained offline HTML report with embedded CSS and images.

- [ ] **Step 1: Generate the report from evidence**

Include objective, approved design, original V1.9 problem, corrected before/after table, planner explanation, calculation/assumption labels, simulation results, complete mock-lab route table, screen images, standalone proof, exact files/paths, unconfirmed physical assumptions, and remaining limitations.

- [ ] **Step 2: Validate content consistency**

Check that every claimed test count/value exists in evidence; filenames, version, direction, save behavior, quantities, and limitations match the `.mlx`. Reject external URLs/resources required for local rendering.

- [ ] **Step 3: Render and inspect the full report**

Open locally, capture the complete page in sections, and inspect navigation, tables, colors, wrapping, images, and spelling. Correct all layout defects and validate again.

- [ ] **Step 4: Commit**

```powershell
git add tools/build_overnight_report.ps1 tools/validate_overnight_report.py delivery/Neyer_Overnight_Verification_Report.html
git commit -m "docs: add overnight Neyer verification report"
```

### Task 15: Final Independent Review, OneDrive Copy, and Repository Check

**Files:**
- Final: `delivery/Neyer_Gap_Test_v1_10.mlx`
- Final: `delivery/Neyer_Overnight_Verification_Report.html`
- Copy to: `C:\Users\games\OneDrive\CHATGPT-Neyer\Neyer_Gap_Test_v1_10.mlx`
- Copy to: `C:\Users\games\OneDrive\CHATGPT-Neyer\Neyer_Overnight_Verification_Report.html`

**Interfaces:**
- Consumes: all completed tasks.
- Produces: reviewed final artifacts locally, in OneDrive, and on the intended Git branch after verification.

- [ ] **Step 1: Use the verification-before-completion checklist**

Re-run the full relevant suite, standalone clean-start, mock workflow, report validator, generated-file hashes, and `git diff --check`. Do not rely on an earlier successful run.

- [ ] **Step 2: Perform final code review**

Review mathematical direction, unsafe optimism, boundary handling, UI meaning, storage safety, self-containment, test gaps, and unsupported claims. Resolve every blocking finding and repeat affected tests.

- [ ] **Step 3: Copy final artifacts to OneDrive without overwriting silently**

Resolve the exact OneDrive folder, create it if absent, compare existing files, and replace only the named project artifacts after recording hashes. Confirm source/destination hashes match and report OneDrive sync state separately from file-copy success.

- [ ] **Step 4: Check repository contents and push**

Confirm `.superpowers/`, `FROM CLAUDE/`, credentials, logs, scratch files, and machine-specific paths are not staged. Push the verified branch only after tests pass.

- [ ] **Step 5: Report completion plainly**

List the exact filenames and paths, repository/branch/commit, test and simulation outcomes, confirmed data-save behavior, OneDrive copy/sync evidence, unconfirmed spacer assumptions, and remaining limitations. If any required check failed, report the failure instead of declaring completion.

## Self-Review Record

- Spec coverage: all 20 design sections map to Tasks 1–15, including both planner modes, physical capability, reserves, storage, UI, simulation, standalone build, mock laboratory, report, and OneDrive.
- Placeholder scan: no deferred implementation markers are used; optional fixed-gap zero-failure qualification is deliberately excluded by the approved spec.
- Interface consistency: planner input, reachable model, plan schema, checkpoint decision, and standalone build outputs retain the same names across dependent tasks.
- Safety boundary: no task relaxes reliability, confidence, physical bounds, accuracy, or reserve use without explicit user action.
