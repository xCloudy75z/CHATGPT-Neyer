# Neyer Gap Test V2 Golden Candidate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task with review checkpoints.

**Goal:** Build Neyer Gap Test V2 as a polished, standalone MATLAB Live Script while keeping the verified V1.13 mathematics unchanged and fixing the five important usability findings from the V1.13 audit.

**Architecture:** Continue to keep the readable functions in `application/source/` as the working source. Assemble those functions into one self-contained V2 `.m` file, then use MATLAB R2022b to create the final `.mlx`. The direct test gains a choice between a genuinely regular physical gap step and a user-confirmed list of buildable gaps. All statistical selection continues through the existing `reachable_model`, so both choices use the same tested Neyer engine.

**Tech Stack:** MATLAB R2022b, MATLAB Unit Test Framework, PowerShell assembly scripts, MATLAB Live Editor conversion, Git.

**Spec:** `docs/superpowers/specs/2026-09-14-neyer-v2-golden-design.md`

## Global Constraints

- Do not edit `delivery/Neyer_Gap_Test_v1_13.m` or `delivery/Neyer_Gap_Test_v1_13.mlx`.
- Before and after implementation, verify the V1.13 MLX SHA-256 remains `2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E`.
- Preserve Stage 1, the one-sigma Stage-2 transition, repeated `0.8` shrink, the two-usable-step Stage-2 floor, overlap detection, MLE, D-optimal choice, confidence calculations, response direction, boundary confirmation, stopping rules, and one physical measurement per new setup.
- Direct **Run a Test** must remain independent of the Pre-Test Planner.
- Display requested gaps with two decimal places, but retain the full measured value in calculations and saved data.
- Use plain language in every user-facing message. Do not introduce spacer-combination recipes in the V2 direct-test window.
- Every implementation task begins with a failing test, then the smallest code change, then focused verification, then a small commit.
- Do not copy final files to OneDrive or publish them until every release gate in Task 9 passes.

---

## Task 1: Freeze V1.13 and Create the V2 Release Scaffold

**Files:**

- Create: `tests/TestV2Release.m`
- Create: `tools/build_standalone_v2.ps1`
- Create: `tools/build_v2_mlx.m`
- Create after the tests demand it: `delivery/Neyer_Gap_Test_v2.m`
- Create after the tests demand it: `delivery/Neyer_Gap_Test_v2.mlx`

**Step 1: Write the failing release tests**

Add tests that:

```matlab
function v113RemainsFrozen(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    actual = localSha256(fullfile(root,'delivery','Neyer_Gap_Test_v1_13.mlx'));
    testCase.verifyEqual(actual, ...
        '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E');
end

function v2StandaloneFilesExist(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.verifyTrue(isfile(fullfile(root,'delivery','Neyer_Gap_Test_v2.m')));
    testCase.verifyTrue(isfile(fullfile(root,'delivery','Neyer_Gap_Test_v2.mlx')));
end
```

Also convert the V2 MLX back to temporary `.m` text and verify that its local-function section matches `Neyer_Gap_Test_v2.m`, following `TestV113Standalone`.

**Step 2: Run the test and confirm the intended failure**

Run:

```powershell
matlab -wait -batch "r=runtests('tests/TestV2Release.m'); assert(~isempty(r)); assertSuccess(r)"
```

Expected: V1.13 fingerprint passes; V2 file-existence test fails because V2 has not been assembled.

**Step 3: Add V2-only assembly and MLX build scripts**

- Base `build_standalone_v2.ps1` on the verified V1.13 file inventory, but hard-code the output name `Neyer_Gap_Test_v2.m` and the heading `Neyer Gap Test V2`.
- Make the script fail if the application source inventory and its explicit required-file list disagree.
- Base `build_v2_mlx.m` on `build_v113_mlx.m`, but write only `delivery/Neyer_Gap_Test_v2.mlx` and V2 evidence. Do not overwrite V1.13 or publish to the site yet.

**Step 4: Assemble and build**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_standalone_v2.ps1
matlab -wait -batch "run('tools/build_v2_mlx.m')"
matlab -wait -batch "r=runtests('tests/TestV2Release.m'); assertSuccess(r)"
```

Expected: scaffold tests pass, even though later V2 behavior tests have not yet been added.

**Step 5: Commit**

```powershell
git add tests/TestV2Release.m tools/build_standalone_v2.ps1 tools/build_v2_mlx.m delivery/Neyer_Gap_Test_v2.m delivery/Neyer_Gap_Test_v2.mlx
git commit -m "build: establish frozen V2 release path"
```

---

## Task 2: Add a Confirmed Buildable-Gap List to Direct Run

**Files:**

- Create: `application/source/parse_confirmed_gap_list.m`
- Modify: `application/source/parse_run_inputs.m`
- Modify: `tools/build_standalone_v2.ps1`
- Create: `tests/TestV2PhysicalInputs.m`
- Modify: `tests/TestPhysicalUiInputs.m` only if a compatibility assertion is needed

**Step 1: Write failing parser and integration tests**

Cover these cases:

```matlab
function listIsSortedDeduplicatedAndKeptInsideBounds(testCase)
    actual = parse_confirmed_gap_list('2.50, 1.00, 2.50, 4.10', 1, 5);
    testCase.verifyEqual(actual, [1; 2.5; 4.1], 'AbsTol', 1e-12);
end

function listNeedsTwoUsableGaps(testCase)
    testCase.verifyError(@() parse_confirmed_gap_list('2.5, 20', 1, 10), ...
        'parse_confirmed_gap_list:notEnoughGaps');
end

function directListModeBuildsReachableModel(testCase)
    answers = struct('low_guess','1','high_guess','10', ...
        'variation_guess','1','maximum_tests','62', ...
        'minimum_gap','1','maximum_gap','10','unit','mm', ...
        'physical_mode','Confirmed gap list', ...
        'regular_step','','confirmed_gaps','1, 1.1, 2.5, 4.1, 5.5', ...
        'foil_thickness','0.015');
    parsed = parse_run_inputs(answers);
    testCase.verifyEqual(parsed.cfg.reachable_model.mode, 'list');
    testCase.verifyEqual(parsed.cfg.reachable_model.gaps_mm, ...
        [1;1.1;2.5;4.1;5.5], 'AbsTol', 1e-12);
end
```

Also test blank entries, nonnumbers, `NaN`, `Inf`, negative values, all values outside bounds, semicolon/space ambiguity, and a list with only one valid gap. Error messages must name the visible question and explain how to correct it.

Retain tests proving the old 7/8/9-cell parser layouts still work for regression tools.

**Step 2: Run focused tests and confirm failure**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2PhysicalInputs.m'); assertSuccess(r)"
```

Expected: failures because the list parser and struct input path do not exist.

**Step 3: Implement the smallest pure parsing change**

- Parse comma-separated values into finite nonnegative numbers.
- Filter against minimum and maximum permitted gaps.
- Sort and collapse duplicates through the existing `reachable_gap_model(..., 'list')` behavior.
- Require at least two usable gaps after filtering.
- For regular mode, retain the whole-hundredth rule and existing `usable_resolution` behavior.
- For list mode, set `cfg.reachable_model` from the list and set the Stage-2 planning floor from the smallest positive difference between adjacent confirmed gaps. Keep `cfg.level_increment` for legacy engine compatibility and document exactly why.

**Step 4: Run focused and regression tests**

```powershell
matlab -wait -batch "r=runtests({'tests/TestV2PhysicalInputs.m','tests/TestPhysicalUiInputs.m','tests/TestReachableGapModel.m'}); assertSuccess(r)"
```

Expected: all selected tests pass.

**Step 5: Commit**

```powershell
git add application/source/parse_confirmed_gap_list.m application/source/parse_run_inputs.m tools/build_standalone_v2.ps1 tests/TestV2PhysicalInputs.m tests/TestPhysicalUiInputs.m
git commit -m "feat: accept confirmed buildable gaps in direct run"
```

---

## Task 3: Redesign the Direct-Test Input Window Around Physical Capability

**Files:**

- Modify: `application/source/run_test_ui.m`
- Create: `tests/TestV2DirectInputUi.m`
- Create: `tools/capture_v2_inputs.m`

**Step 1: Write failing UI/source tests**

Tests must verify that the direct input window contains:

- `How can you build the test gaps?`
- choices `Regular gap step` and `Confirmed gap list`
- one plain-language explanation under every input
- a warning that regular mode is valid only when every multiple can genuinely be built
- an explanation that overall variation is a rough starting guess, not the final answer
- visible minimum and maximum permitted-gap explanations
- no requirement for a Pre-Test Planner result

For desktop UI tests, programmatically change the physical method and verify that only the relevant regular-step or list field is enabled and visible.

**Step 2: Confirm the tests fail**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2DirectInputUi.m'); assertSuccess(r)"
```

Expected: failures because V1.13 still shows the fixed nine-row form.

**Step 3: Implement the new window**

- Replace the loop-generated labels with explicit, named controls.
- Use a scrollable figure or sufficiently tall layout for MATLAB R2022b.
- Add a dropdown for the two approved physical modes.
- Toggle the relevant field without deleting its value.
- Keep all existing defaults unless the approved design changes the label only.
- Pass a named struct to `parse_run_inputs` so field order no longer controls the new UI.

**Step 4: Run the focused tests and capture the window**

```powershell
matlab -wait -batch "r=runtests({'tests/TestV2DirectInputUi.m','tests/TestV2PhysicalInputs.m'}); assertSuccess(r); run('tools/capture_v2_inputs.m')"
```

Expected: tests pass and `audit/v2/ui/02-direct-inputs.png` shows all explanations without clipping.

**Step 5: Visually inspect the PNG before committing**

Check text wrapping, field alignment, enabled/disabled state, button visibility, and two-decimal examples.

**Step 6: Commit**

```powershell
git add application/source/run_test_ui.m tests/TestV2DirectInputUi.m tools/capture_v2_inputs.m audit/v2/ui/02-direct-inputs.png
git commit -m "feat: explain direct test inputs and physical gap modes"
```

---

## Task 4: Simplify the Main Menu and Per-Test Instruction

**Files:**

- Modify: `application/source/neyer_app.m`
- Modify: `application/source/run_test_ui.m`
- Modify: `application/source/reachable_gap_model.m`
- Modify: `application/source/format_requested_gap.m`
- Create: `tests/TestV2OperatorWording.m`
- Create: `tools/capture_v2_menu_and_test.m`

**Step 1: Write failing wording and UI tests**

Verify:

- application and menu title is `Neyer Gap Test V2`
- the menu explanation wraps and is fully visible
- the per-test window has exactly one build instruction beginning `Build the requested gap:`
- a regular 5 mm request reads `Build the requested gap: 5.00 mm`
- list-mode text does not add a second `Set the gap` instruction
- the separate one-reading explanation remains visible

**Step 2: Confirm the tests fail**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2OperatorWording.m'); assertSuccess(r)"
```

**Step 3: Apply wording/layout changes only**

Do not change the requested numeric level or response collection. Make recipe text supplemental only when a future combination model supplies it; regular/list modes must show one build instruction.

**Step 4: Verify and visually inspect**

```powershell
matlab -wait -batch "r=runtests({'tests/TestV2OperatorWording.m','tests/TestGapPresentation.m'}); assertSuccess(r); run('tools/capture_v2_menu_and_test.m')"
```

Expected PNGs: `audit/v2/ui/01-main-menu.png` and `audit/v2/ui/03-test-request.png`, both readable without clipped text.

**Step 5: Commit**

```powershell
git add application/source/neyer_app.m application/source/run_test_ui.m application/source/reachable_gap_model.m application/source/format_requested_gap.m tests/TestV2OperatorWording.m tools/capture_v2_menu_and_test.m audit/v2/ui
git commit -m "fix: make V2 operator instructions clear and singular"
```

---

## Task 5: Make Unfinished and Calculated Results Honest and Clear

**Files:**

- Modify: `application/source/show_result.m`
- Create: `tests/TestV2ResultUi.m`
- Create: `tools/capture_v2_results.m`

**Step 1: Write failing result-screen tests**

Unfinished-result test:

- shows one clear status card explaining that a middle gap and overall variation cannot yet be calculated
- shows completed test count and whether Interaction/No interaction has been observed
- keeps `Save results...` available when completed data exist
- has no axes, blank charts, probability calculator, `NaN`, or disabled Calculate control

Calculated-result test:

- retains exactly two axes
- uses `calculated result`, not `fitted result`
- explains the middle gap as about 50% interaction
- uses `cautious minimum supported by the data`
- states that smaller gaps make Interaction more likely

**Step 2: Confirm tests fail against the current presentation**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2ResultUi.m'); assertSuccess(r)"
```

**Step 3: Split the visual layout by result state**

Keep all calculations in existing math functions. `show_result` may choose between an unfinished layout and a calculated layout, but must not calculate substitute answers.

**Step 4: Verify and capture both states**

```powershell
matlab -wait -batch "r=runtests({'tests/TestV2ResultUi.m','tests/TestResultDecision.m','tests/TestV113CompleteAudit.m'}); assertSuccess(r); run('tools/capture_v2_results.m')"
```

Expected: focused tests pass; screenshots `04-unfinished-result.png` and `05-calculated-result.png` are readable and contain no empty placeholder areas.

**Step 5: Commit**

```powershell
git add application/source/show_result.m tests/TestV2ResultUi.m tools/capture_v2_results.m audit/v2/ui
git commit -m "fix: present unfinished and calculated results clearly"
```

---

## Task 6: Replace the Dense Help Wall with Readable Sections

**Files:**

- Modify: `application/source/show_manual.m`
- Create: `tests/TestV2HelpUi.m`
- Create: `tools/capture_v2_help.m`

**Step 1: Write failing help tests**

Require titled, plain-language sections for:

1. What the tool answers
2. What each direct input means
3. Regular step versus confirmed list
4. What to do for each new setup
5. How to read unfinished and calculated results
6. Probability versus confidence
7. Saving and reopening
8. Limits and the separate fixed-gap qualification concept

The visible UI must not use a monospaced `Consolas` text wall or unexplained `Stage 1`, `Stage 2`, `MLE`, or `D-optimal` wording.

**Step 2: Confirm the test fails**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2HelpUi.m'); assertSuccess(r)"
```

**Step 3: Implement a scrollable help layout**

Use normal proportional fonts, section headings, short paragraphs, and small examples. Technical method names may appear only in a final `Method and traceability` section with an immediate plain-language definition.

**Step 4: Verify and inspect**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2HelpUi.m'); assertSuccess(r); run('tools/capture_v2_help.m')"
```

Expected: `audit/v2/ui/06-help.png` shows readable sections and a working scroll area.

**Step 5: Commit**

```powershell
git add application/source/show_manual.m tests/TestV2HelpUi.m tools/capture_v2_help.m audit/v2/ui/06-help.png
git commit -m "fix: replace help text wall with plain-language sections"
```

---

## Task 7: Correct Traceability Comments Without Changing Mathematics

**Files:**

- Modify: the source file containing the first two-sigma Stage-2 request provenance comment, located with `rg -n "2.*sigma|two.*sigma|addendum|PAPER" application/source`
- Modify: `application/source/neyer_app.m` header comment
- Create: `tests/TestV2MathFrozen.m`

**Step 1: Add frozen-math regression tests**

Test the published replay and the approved constants directly:

```matlab
function publishedReplayIsUnchanged(testCase)
    demo = run_demo();
    testCase.verifyEqual(demo.got_mu, 5.3922, 'AbsTol', 5e-5);
    testCase.verifyEqual(demo.got_sigma, 1.0412, 'AbsTol', 5e-5);
    testCase.verifyTrue(demo.is_match);
end
```

Also assert:

- Stage-2 transition width is one sigma
- its repeated shrink is `0.8`
- its planning floor is two usable steps
- larger gaps reduce Interaction probability
- the same response sequence produces the same requested numeric gaps as V1.13 for regular mode

**Step 2: Run the tests before comments change**

```powershell
matlab -wait -batch "r=runtests('tests/TestV2MathFrozen.m'); assertSuccess(r)"
```

Expected: behavior tests pass. Any traceability-text assertion should fail until the comment is corrected.

**Step 3: Correct comments only**

- Mark the first two-sigma request as originating from the Neyer paper where the audit evidence supports that statement.
- Explain any retained legacy `break/survive` names as internal compatibility wording and map them to Interaction/No interaction.
- Do not edit formulas or numeric constants in this task.

**Step 4: Run the focused math suite**

```powershell
matlab -wait -batch "r=runtests({'tests/TestV2MathFrozen.m','tests/TestPaperConformance.m','tests/TestResolutionAwareStage2.m','tests/TestTransitionOnly.m','tests/TestGapReliability.m'}); assertSuccess(r)"
```

**Step 5: Commit**

```powershell
git add application/source tests/TestV2MathFrozen.m
git commit -m "docs: correct V2 method traceability without changing math"
```

---

## Task 8: Assemble and Test the Self-Contained V2 Live Script

**Files:**

- Modify: `tools/build_standalone_v2.ps1`
- Modify: `tools/build_v2_mlx.m`
- Rebuild: `delivery/Neyer_Gap_Test_v2.m`
- Rebuild: `delivery/Neyer_Gap_Test_v2.mlx`
- Create: `tools/verify_v2_clean_start.m`
- Modify: `tests/TestV2Release.m`
- Create evidence under: `audit/v2/clean-start/`

**Step 1: Extend the failing standalone tests**

Require the converted MLX to contain every source function exactly once, contain no path to `application/source`, and include the V2 operating sections. Add a clean-start test that copies only the MLX into an empty temporary folder.

**Step 2: Rebuild from the explicit source inventory**

```powershell
powershell -ExecutionPolicy Bypass -File tools/build_standalone_v2.ps1
matlab -wait -batch "run('tools/build_v2_mlx.m')"
```

**Step 3: Run the clean-start workflow**

`verify_v2_clean_start.m` must, from a temporary folder containing only the V2 MLX:

- convert and load the embedded source
- confirm all embedded functions are available without helper files
- run the 20-result direct workflow
- run the published replay (`5.3922`, `1.0412`)
- calculate a probability answer
- save real CSV and self-contained HTML output
- confirm the shown save paths equal the actual files
- reject a same-name second save
- confirm invalid and incomplete input messages are understandable

Run:

```powershell
matlab -wait -batch "run('tools/verify_v2_clean_start.m')"
matlab -wait -batch "r=runtests('tests/TestV2Release.m'); assertSuccess(r)"
```

Expected: all clean-start checks pass with no file outside the temporary folder required.

**Step 4: Commit**

```powershell
git add tools/build_standalone_v2.ps1 tools/build_v2_mlx.m tools/verify_v2_clean_start.m tests/TestV2Release.m delivery/Neyer_Gap_Test_v2.m delivery/Neyer_Gap_Test_v2.mlx audit/v2/clean-start
git commit -m "build: assemble and verify standalone Neyer V2"
```

---

## Task 9: Run the Golden-Candidate Release Gates

**Files:**

- Create: `tools/run_v2_regular_matrix.m`
- Create: `tools/run_v2_list_matrix.m`
- Create: `tools/v2_release_fingerprint.m`
- Create: `audit/v2/V2_GOLDEN_CANDIDATE_REPORT.md`
- Create evidence under: `audit/v2/`
- Copy only after all gates pass: `C:\Users\games\OneDrive\CHATGPT-Neyer\V2\Neyer_Gap_Test_v2.mlx`

**Step 1: Run the complete MATLAB suite**

```powershell
matlab -wait -batch "r=run_tests; assert(~isempty(r)); assertSuccess(r); r2=runtests({'tests/TestV113CompleteAudit.m','tests/TestV2*.m'}); assertSuccess(r2)"
```

Expected: zero failed and zero incomplete tests. Record total passed count in `audit/v2/full-suite-results.txt`.

**Step 2: Repeat the verified 1,800-run regular-grid matrix**

Use the exact V1.13 audit matrix: steps `0.05`, `0.10`, `0.15`, `0.50`; middle gaps `1.5`, `5`, `8.5`; true variations `0.15`, `0.25`, `0.5`, `1`, `1.5`; starting variation guesses `0.25`, `1`, `2`; budgets `20`, `62`; five repeats. Use parallel workers when available and deterministic seeds.

Expected invariants:

- no out-of-range request
- every request belongs to the chosen reachable model
- no immediate duplicate while a different reachable and useful gap exists
- replay produces identical requested gaps
- boundary pause occurs only after its required confirmation
- result direction is correct

**Step 3: Add an irregular confirmed-list stress matrix**

Include lists such as:

```matlab
{[1 1.1 2.5 4.1 5.5 10], ...
 [0 0.15 0.5 1.1 2.07 3.67 5 10], ...
 [1 1.03 1.47 2.18 3.02 4.95 7.4 10]}
```

Vary true middle gap, variation, budget, and response seed. Verify every requested value is a member of the confirmed list and the selector does not invent intermediate gaps.

**Step 4: Inspect every V2 screenshot**

Review all PNGs under `audit/v2/ui/` at original resolution. Record pass/fail for clipping, overlap, unreadable text, misleading empty states, two-decimal requests, and visible save-location wording.

**Step 5: Re-run clean-start and fingerprint both releases**

```powershell
matlab -wait -batch "run('tools/verify_v2_clean_start.m')"
matlab -wait -batch "run('tools/v2_release_fingerprint.m')"
```

The evidence must report:

- unchanged V1.13 SHA-256
- V2 `.m` and `.mlx` SHA-256 values
- MATLAB release used
- standalone function count
- full-suite counts
- both stress-matrix counts and invariant failures
- published example result

**Step 6: Write the concise golden-candidate report**

The report must separate:

- unchanged verified mathematics
- V2 fixes
- optional ideas deliberately left out
- executed evidence
- remaining limitations, especially that a confirmed list is only as trustworthy as the user's physical confirmation

Do not call V2 golden if any required check failed or remained incomplete.

**Step 7: Copy the passed candidate to the dated/versioned OneDrive area**

First resolve and verify the exact destination is inside `C:\Users\games\OneDrive\CHATGPT-Neyer\`. Preserve earlier versions. Copy the V2 MLX and its specific audit report into a `V2` subfolder, then verify local OneDrive file size and hash match the built release. Report sync status honestly; a matching local OneDrive copy does not by itself prove cloud upload unless the OneDrive client provides verifiable status.

**Step 8: Final review and commit**

Use `superpowers:requesting-code-review`, address verified issues, then use `superpowers:verification-before-completion` before any completion claim.

```powershell
git add application/source tests tools delivery audit/v2 docs/superpowers
git status --short
git diff --check
git commit -m "release: complete Neyer Gap Test V2 golden candidate"
```

Do not push to GitHub until the final repository-content and secret scan passes and the user authorizes/preserves the agreed release route.

---

## Final Acceptance Checklist

- V1.13 MLX hash is unchanged.
- V2 asks for regular step or confirmed list and never invents a gap outside that choice.
- One new spacer setup receives one measured-gap reading.
- All requests show two decimals.
- Direct Run a Test works without the planner.
- Unfinished results show a clear status instead of blank charts.
- Calculated results retain two useful charts and plain wording.
- Help and all input explanations are readable and jargon-free.
- Published example remains middle `5.3922` and overall variation `1.0412`.
- Full tests, regular matrix, irregular-list matrix, clean-start workflow, save collision check, and visual review all pass.
- The final `.mlx` is self-contained in an otherwise empty folder.
- OneDrive delivery is versioned and hash-verified without deleting older files.
