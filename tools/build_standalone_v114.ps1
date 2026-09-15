param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path $ProjectRoot 'application\source'
$destination = Join-Path $ProjectRoot 'delivery\Neyer_Gap_Test_v1_14.m'
$manifest = Join-Path $PSScriptRoot 'v114-source-files.txt'
$utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$requiredFiles = @([System.IO.File]::ReadAllLines($manifest) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$actualFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.m' |
    Sort-Object Name | ForEach-Object Name)
$missing = @($requiredFiles | Where-Object { $_ -notin $actualFiles })
$unexpected = @($actualFiles | Where-Object { $_ -notin $requiredFiles })
if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
    throw "V1.14 source list mismatch. Missing: $($missing -join ', '). Unexpected: $($unexpected -join ', ')."
}

$sourceTexts = @{}
foreach ($fileName in $requiredFiles) {
    $fileText = [System.IO.File]::ReadAllText(
        (Join-Path $sourceRoot $fileName), $utf8Strict)
    if ($fileName -eq 'parse_confirmed_gap_list.m') {
        $fileText = [regex]::Replace($fileText,
            '(?<![A-Za-z0-9_])validate_bounds(?![A-Za-z0-9_])',
            'validate_confirmed_gap_bounds')
    }
    $sourceTexts[$fileName] = $fileText
}

$functionPattern = '(?m)^([ \t]*)function[ \t]+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)[ \t]*=[ \t]*(?:\.\.\.[^\r\n]*\r?\n[ \t]*)?)?([A-Za-z]\w*)'
$declarations = foreach ($fileName in $requiredFiles) {
    foreach ($match in [regex]::Matches($sourceTexts[$fileName], $functionPattern)) {
        [pscustomobject]@{ Name = $match.Groups[2].Value; File = $fileName }
    }
}
$duplicates = @($declarations | Group-Object Name | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    throw "Duplicate local MATLAB functions: $(($duplicates.Name | Sort-Object) -join ', ')"
}

$header = @"
%% Neyer Gap Test V1.14
% Supported version: MATLAB R2022b.
%
% This Live Script contains the complete application. Open it in MATLAB and
% press Run once. No helper folder, internet connection, or add-on is needed.

%% What this study answers
% The tool estimates the middle gap (about 50% Interaction), the overall
% variation, and the probability curve. Smaller gaps make Interaction more
% likely; larger gaps make No interaction more likely.

%% First study - variation unknown
% Choose this default route when sigma is not known. Enter reasonable low and
% high guesses for the middle gap, the maximum number of destructive tests,
% the permitted gap range, and the gaps that can actually be built. The tool
% chooses an internal starting search scale. It does not call that value a
% known or measured variation.

%% One measurement for each new setup
% Build the requested gap, measure that completed setup once, and enter that
% measured gap. The calculation uses the measured value. Each destructive
% test uses a newly built setup.

%% Saving
% Save results chooses a visible user-selected base name and creates matching
% CSV and offline HTML files. Existing files are never replaced silently.

%% Important separation
% This changing-gap Neyer study is used to estimate a response curve. A
% fixed-gap reliability demonstration is a separate later study and is not a
% Pre-Test Planner or qualification claim inside V1.14.

%% Start the application
neyer_app;
"@

$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add($header.TrimEnd())
foreach ($fileName in $requiredFiles) {
    $parts.Add((@(
        "% === BEGIN EMBEDDED SOURCE: $fileName ==="
        $sourceTexts[$fileName].Trim()
        "% === END EMBEDDED SOURCE: $fileName ==="
    ) -join "`r`n"))
}
[System.IO.File]::WriteAllText($destination,
    (($parts -join "`r`n`r`n") + "`r`n"),
    [System.Text.UTF8Encoding]::new($false))
Write-Output "Built $destination"
Write-Output "Embedded source files: $($requiredFiles.Count)"
Write-Output "Function declarations: $($declarations.Count)"
