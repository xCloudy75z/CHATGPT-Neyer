param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $ProjectRoot 'application\source'
$deliveryRoot = Join-Path $ProjectRoot 'delivery'
$destination = Join-Path $deliveryRoot 'Neyer_Gap_Test_v1_10.m'

$requiredFiles = @(
    'best_fit.m',
    'check_inputs.m',
    'check_study_checkpoint.m',
    'choose_stage.m',
    'draw_distribution.m',
    'draw_interaction_curve.m',
    'estimate_study_plan.m',
    'estimate_supported_targets.m',
    'find_root.m',
    'fit_sigma0.m',
    'format_requested_gap.m',
    'format_result_text.m',
    'has_overlap.m',
    'height_for_reliability.m',
    'info_terms.m',
    'load_study_plan.m',
    'loglik.m',
    'lr_confidence.m',
    'neyer_app.m',
    'neyer_settings.m',
    'one_sided_profile_threshold.m',
    'operating_gap_coverage.m',
    'parse_physical_response.m',
    'parse_run_inputs.m',
    'pick_next_level.m',
    'pl_opts.m',
    'plan_prep.m',
    'plan_prep_message.m',
    'plan_prep_numbers.m',
    'plan_samples.m',
    'plot_result.m',
    'pretest_planner_ui.m',
    'prof_quantile.m',
    'reachable_gap_model.m',
    'reliability_at_height.m',
    'reliability_query.m',
    'report.m',
    'result_decision_summary.m',
    'result_output_paths.m',
    'results_to_csv_text.m',
    'results_to_html.m',
    'round_reachable_gap.m',
    'run_demo.m',
    'run_loop.m',
    'run_physical_test.m',
    'run_test.m',
    'run_test_ui.m',
    'sanity_clamp.m',
    'save_results_files.m',
    'save_study_plan.m',
    'select_reachable_request.m',
    'select_operating_gap.m',
    'shape_model.m',
    'show_manual.m',
    'show_result.m',
    'usable_resolution_for_plan.m',
    'validate_study_plan_safety.m',
    'validate_plan_inputs.m'
)

if (-not (Test-Path -LiteralPath $deliveryRoot)) {
    New-Item -ItemType Directory -Path $deliveryRoot | Out-Null
}

$actualFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.m' |
    Sort-Object Name | ForEach-Object Name)
$missing = @($requiredFiles | Where-Object { $_ -notin $actualFiles })
$unexpected = @($actualFiles | Where-Object { $_ -notin $requiredFiles })
if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
    throw "Standalone list mismatch. Missing: $($missing -join ', '). Unexpected: $($unexpected -join ', ')."
}

$functionPattern = '(?m)^\s*function\s+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*)?([A-Za-z]\w*)'
$declarations = foreach ($fileName in $requiredFiles) {
    $fileText = Get-Content -Raw -LiteralPath (Join-Path $sourceRoot $fileName)
    foreach ($match in [regex]::Matches($fileText, $functionPattern)) {
        [pscustomobject]@{ Name = $match.Groups[1].Value; File = $fileName }
    }
}
$duplicates = @($declarations | Group-Object Name | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    throw "Duplicate local MATLAB functions: $(($duplicates.Name | Sort-Object) -join ', ')"
}

$header = @'
%% Neyer Gap Test v1.10
% Supported version: MATLAB R2022b.
%
% This one Live Script contains the complete application. Open it and press
% Run once. The Neyer Gap Test menu then appears. No helper-code folder,
% internet connection, or add-on package is needed.

%% What this tool answers
% The tool studies destructive tests in which a smaller physical gap makes
% Interaction more likely and a larger gap makes No interaction more likely.
% It estimates:
%
% * the middle gap, where similar articles are expected to interact about
%   half the time;
% * the overall variation, which says how gradual or sudden the change is;
% * a cautious operating gap for the chosen reliability and confidence.
%
% Reliability is the predicted chance at a gap. Confidence describes how
% much support the completed data give that prediction. They are different.

%% Start with the Pre-Test Planner
% Choose one of two routes:
%
% * Requirements first: enter the reliability, confidence, middle-gap
%   accuracy, rough Interaction and No-interaction endpoints, permitted gap
%   range, and the gap settings your equipment can actually build.
% * Available articles first: enter how many independent articles are
%   available, then keep either reliability or confidence fixed. The other
%   value is only a pre-test expectation, not a final claim.
%
% The plan separates the main study from two reserve groups. Reserve groups
% are not used automatically. The user decides at each named checkpoint.
% The main study may estimate the middle gap and overall variation, but a
% supported reliability result requires at least 400 independent articles
% under the recorded virtual-study safety rule. Some requests need more.

%% Physical gap settings
% Define settings from measured physical capability, not from the foil label.
% The current aluminium foil value of about 0.015 mm and the printed-spacer
% observations are unconfirmed starting information. The planner can use a
% regular step such as 0.05, 0.10, 0.15, or 0.50 mm, a list of measured gaps,
% or combinations of measured spacer components and maximum counts.
%
% A requested build gap is shown with two decimal places. The exact reachable
% value remains stored. A setting is never chosen just because it is nearest:
% it must also be inside the permitted range and safe for the requested result.
% A final operating instruction moves one additional reachable setting in the
% safe direction to protect against differences in a newly built spacer setup.

%% Procedure for every destructive article
% 1. Use a new spacer setup at the reachable gap shown by the app.
% 2. Measure that unchanged setup 4 or 5 times before the test.
% 3. Enter every reading. The Measured mean is the actual gap used in the
%    calculation; the ideal requested gap is not substituted for it.
% 4. Perform one test and record Interaction or No interaction.
% 5. Do not reuse the setup after the destructive test.
%
% Repeated readings describe measurement uncertainty for one build. They do
% not remove the variation between separately built articles.

%% How the next gap is chosen
% The early tests establish both outcomes. The narrowing stage multiplies its
% working overall-variation value by 0.8 after each result and cannot shrink
% below two usable physical setting steps. Once the outcomes overlap, the
% fitted model chooses later gaps expected to add the most useful information.
% The two-step limit affects planning only; it is not a lower limit imposed on
% the final fitted overall variation.

%% Saving and reopening
% A study plan is saved as JSON in a folder and filename chosen by the user.
% Results are saved as a CSV data file and a self-contained HTML result page.
% The complete intended paths are shown before saving. The application never replaces an existing
% plan or result file silently; choose another name.

%% Important limits
% Confirm the real reachable gap list with repeated physical builds before a
% formal study. A model result does not replace a separate fixed-gap,
% zero-failure qualification demonstration when a standard requires one.
% Confidence of 50% or less is exploratory, so it does not produce a
% safety-supported operating instruction. Confidence above 95% can be
% calculated but is also kept outside the recorded validation envelope.
% Results outside the permitted gap range are never shown as usable build
% instructions.

%% Start the application
neyer_app;

'@

$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add($header.TrimEnd())
foreach ($fileName in $requiredFiles) {
    $parts.Add((Get-Content -Raw -LiteralPath (Join-Path $sourceRoot $fileName)).Trim())
}
$output = ($parts -join "`r`n`r`n") + "`r`n"
[System.IO.File]::WriteAllText($destination, $output,
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Built $destination"
Write-Output "Embedded source files: $($requiredFiles.Count)"
Write-Output "Unique local functions: $($declarations.Count)"
