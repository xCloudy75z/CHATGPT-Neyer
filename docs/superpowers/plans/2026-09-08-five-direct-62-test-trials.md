# Five Direct 62-Test Trials Verification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run and audit five planner-free, 62-test Neyer simulations using different usable physical gap steps.

**Architecture:** A verification-only MATLAB runner will call the same `parse_run_inputs`, `run_loop`, and `report` functions used by the direct Run-a-Test path. Each run uses a known synthetic gap response, new-build variation, and five measurement readings; hard checks stop the run if the physical or Neyer logic is violated.

**Tech Stack:** MATLAB R2022b, MATLAB unit-style assertions, CSV and plain-text evidence.

**Spec:** User request in the 2026-09-08 Codex task; no separate product-design specification because production behaviour is not being changed.

## Global Constraints

- Do not call or use the Pre-Test Planner.
- Do not modify the production Neyer mathematics.
- Run exactly 62 destructive-test opportunities per trial unless a documented safety pause occurs.
- Use direct usable gap steps of 0.05, 0.10, 0.15, 0.25, and 0.50 mm.
- Use the user's gap direction: smaller gap means interaction is more likely.
- Keep requested gaps inside 1.00 to 10.00 mm and display/build them to two decimal places.
- Model a true middle gap of 2.50 mm and true overall variation of 0.50 mm, matching the user's statement that 1.00 mm is almost certain to interact.
- Use a new virtual build for every test, five measurement readings per build, 0.02 mm build variation, and 0.01 mm reading variation.

---

### Task 1: Build the five-run verification harness

**Files:**
- Create: `tools/run_five_direct_62_trials.m`
- Create during execution: `audit/direct-62-trials/five-trial-summary.csv`
- Create during execution: `audit/direct-62-trials/five-trial-trajectories.csv`
- Create during execution: `audit/direct-62-trials/five-trial-audit.txt`

**Interfaces:**
- Consumes: `parse_run_inputs(answers)`, `run_loop(parameters, budget, response, cfg)`, and `report(record, cfg)`.
- Produces: one summary row per usable gap step, one trajectory row per completed virtual article, and a plain-language pass/fail audit.

- [x] **Step 1: Create deterministic trial inputs**

Use seeds `202609081` through `202609085`, 62 thresholds per trial from `2.50 + 0.50*randn`, new-build errors from `0.02*randn`, and five reading errors from `0.01*randn`.

- [x] **Step 2: Run the real direct-test core without a plan**

Build each configuration with the nine direct input fields, assert that `study_plan` is absent, and call `run_loop` with a physical-response callback.

- [x] **Step 3: Add hard logic and physical checks**

Check 62 requested opportunities, bounds, reachable increments, no accidental immediate repeats, five finite readings, measured means, actual-gap outcome generation, one-way Stage 2, 0.8 Stage-2 shrink with the two-step floor, and valid Stage-3 D-optimal candidates.

- [x] **Step 4: Audit final mathematics**

Call `report`, independently recompute the log likelihood near the returned estimate, confirm positive finite overall variation, record middle and variation error, and state whether the 95% confidence ranges contain the known synthetic truth.

- [x] **Step 5: Save evidence and stop on any failure**

Write the two CSV files and plain-language audit file. Throw a MATLAB error if any hard check fails so a partially successful run cannot be reported as approved.

### Task 2: Execute and review in MATLAB R2022b

**Files:**
- Read: `audit/direct-62-trials/five-trial-summary.csv`
- Read: `audit/direct-62-trials/five-trial-trajectories.csv`
- Read: `audit/direct-62-trials/five-trial-audit.txt`

**Interfaces:**
- Consumes: Task 1 evidence.
- Produces: a user-facing five-row comparison and an explicit list of any limitations or defects.

- [x] **Step 1: Run the harness in MATLAB R2022b**

Run `tools/run_five_direct_62_trials.m` from the v1.10 worktree and capture MATLAB's exit status.

- [x] **Step 2: Inspect every trial**

Compare requested steps, completed counts, stage paths, fit results, confidence limits, and hard-check status across all five runs.

- [x] **Step 3: Re-run the full existing suite if production code changes**

No production change is expected. If a defect requires a correction, stop, explain it to the user, then use test-driven development and rerun the complete suite plus the five trials.

- [x] **Step 4: Present the audit visually**

Provide a compact table showing each gap step, fitted middle, fitted overall variation, errors, confidence coverage, duplicate count, bounds result, and overall audit decision.
