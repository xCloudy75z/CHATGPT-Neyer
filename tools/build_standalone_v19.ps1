param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$functionRoot = Join-Path $ProjectRoot 'application\source'
$destination = Join-Path $ProjectRoot 'delivery\Neyer_Gap_Test_v1_9.m'
$files = @(Get-ChildItem -LiteralPath $functionRoot -Filter '*.m' | Sort-Object Name)

if ($files.Count -eq 0) {
    throw "No MATLAB application functions were found in $functionRoot"
}

$functionPattern = '(?m)^\s*function\s+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*)?([A-Za-z]\w*)'
$declarations = foreach ($file in $files) {
    $fileText = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($fileText, $functionPattern)) {
        [pscustomobject]@{ Name = $match.Groups[1].Value; File = $file.Name }
    }
}

$duplicates = @($declarations | Group-Object Name | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    $names = ($duplicates.Name | Sort-Object) -join ', '
    throw "Duplicate local MATLAB function names prevent a standalone build: $names"
}

$header = @'
%% Neyer Gap Test v1.9
% MATLAB R2022b
%
% This single Live Script contains the complete application. It does not
% need a helper folder, an executable, an internet connection, or addpath.
% Open this file in MATLAB and press Run once. The main menu then appears.
%
% The application estimates how interaction chance changes with physical
% gap. Smaller gaps make interaction more likely; larger gaps make it less
% likely.

%% What the user must know before starting
% Enter the lowest and highest usable gap in millimetres. For the current
% equipment, the intended physical study range is 0 to 10 mm. Also select
% the usable gap step for the study. The current provisional choice is
% 0.05 mm, which must still be confirmed through repeated physical builds.
%
% The app uses three clearly separated gap values:
%
% * Requested gap: the ideal value chosen by the Neyer method.
% * Reachable gap: the nearest useful value the physical equipment can make.
% * Measured mean: the average of 4 or 5 readings of the newly built spacer.
%
% The measured mean, not the requested gap, is used in the calculation.
% Physical build instructions are shown with exactly two decimal places;
% entered measurements retain their available precision.

%% Physical resolution and aluminium foil
% Aluminium foil is approximately 0.015 mm thick, but that material thickness
% is not treated as the equipment's usable resolution. Printed 0.50 mm spacers
% have so far varied from approximately 0.49 to 0.52 mm. The physical settings
% therefore keep foil thickness separate from the usable gap step.
%
% The Stage-2 working transition width cannot shrink below two usable gap
% steps. With a provisional 0.05 mm usable step, the planning floor is
% 0.10 mm. This protects Stage-2 selection from false physical precision; it
% does not impose a 0.10 mm lower limit on the final fitted transition width.

%% What the method does
% The early tests safely establish an interaction and a no-interaction
% result. The app then narrows the search and selects useful later gaps by
% the Neyer D-optimal rule. In Part 2, the working transition width shrinks
% by 0.8 after each result until the estimated ranges strictly overlap.
% The app never returns to the earlier bisection stage after Part 2 begins.

%% Results shown by the application
%
% * Middle gap: the estimated gap with about 50% interaction chance.
% * Transition width: how sharply the outcome changes with gap.
% * High-interaction and negligible-interaction reference gaps.
% * A bell curve and a chance-of-interaction curve.
% * Confidence limits, with out-of-range limits clearly labelled rather
%   than presented as usable physical settings.

%% Physical procedure for every destructive test
% 1. Build a new spacer setup at the reachable gap requested by the app.
% 2. Measure that unchanged setup 4 or 5 times before the test.
% 3. Enter all readings. Their mean is used as the actual statistical gap.
% 4. Perform one test and select Interaction or No interaction.
% 5. Do not reuse the spacer setup after the destructive test.
%
% Confirm the usable gap step before the real study. Do not enter 0.015 mm
% merely because that is the approximate thickness of one foil sheet.

%% Saving results
% Select Save results in the result window and choose a folder and base
% name. The app creates a CSV data file and a self-contained HTML result report
% in that selected folder. It shows both complete paths before saving.
% The app never replaces an existing result file. If either intended file
% already exists, nothing is written and the app asks for a different name.

%% Input checks and understandable pauses
% The app rejects missing, non-numeric, out-of-range, or incorrectly spaced
% inputs with a plain explanation. A boundary contradiction pauses the run
% for review; it does not falsely declare the physical test a failure.

%% Plain-language glossary
% mu (middle gap): the estimated 50% interaction gap.
% sigma (transition width): how gradually or sharply interaction changes.
% D-optimal: a rule that chooses a next gap expected to add useful evidence.
% confidence interval: a range showing uncertainty around an estimate.

%% Known limitations
% The selected 0.05 mm or 0.10 mm increment must be confirmed on the real
% equipment. Each destructive test needs a newly built spacer, so repeated
% readings describe measurement uncertainty but cannot remove build-to-build
% variation. The deep numerical behaviour of the maximum-likelihood estimate
% in extremely separated artificial data remains a recommended future study.

%% Start the application
neyer_app;

'@

$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add($header.TrimEnd())
foreach ($file in $files) {
    $parts.Add((Get-Content -Raw -LiteralPath $file.FullName).Trim())
}

$output = ($parts -join "`r`n`r`n") + "`r`n"
[System.IO.File]::WriteAllText($destination, $output, [System.Text.UTF8Encoding]::new($false))

Write-Output "Built $destination"
Write-Output "Embedded files: $($files.Count)"
Write-Output "Unique functions: $($declarations.Count)"
