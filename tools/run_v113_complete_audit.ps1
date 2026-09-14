[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('inventory')]
    [string]$Phase
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceFolder = Join-Path $projectRoot 'audit\v113-complete'
$liveScriptPath = Join-Path $projectRoot 'delivery\Neyer_Gap_Test_v1_13.mlx'
$sourceFolder = Join-Path $projectRoot 'application\source'
New-Item -ItemType Directory -Force -Path $evidenceFolder | Out-Null

function Get-AuditGate([string]$functionName) {
    $stageFunctions = @('choose_stage', 'has_overlap', 'pick_next_level', 'run_test', 'run_loop')
    $mathFunctions = @(
        'best_fit', 'find_root', 'fit_sigma0', 'height_for_reliability',
        'info_terms', 'loglik', 'lr_confidence', 'one_sided_profile_threshold',
        'operating_gap_coverage', 'pl_opts', 'prof_quantile',
        'reliability_at_height', 'sanity_clamp', 'select_operating_gap',
        'shape_model'
    )
    $physicalFunctions = @(
        'apply_run_configuration_overrides', 'check_study_checkpoint',
        'format_requested_gap', 'parse_physical_response', 'reachable_gap_model',
        'round_reachable_gap', 'run_physical_test', 'select_reachable_request',
        'usable_resolution_for_plan'
    )
    $recordFunctions = @(
        'load_study_plan', 'result_output_paths', 'result_save_available',
        'results_to_csv_text', 'results_to_html', 'save_results_files',
        'save_study_plan'
    )
    $plannerFunctions = @(
        'estimate_study_plan', 'estimate_supported_targets', 'plan_prep',
        'plan_prep_message', 'plan_prep_numbers', 'plan_samples',
        'validate_planner_components', 'validate_study_plan_safety'
    )
    $inputFunctions = @('check_inputs', 'parse_run_inputs', 'validate_plan_inputs')

    if ($stageFunctions -contains $functionName) { return 'Neyer stages and next gap' }
    if ($mathFunctions -contains $functionName) { return 'Mathematics and confidence' }
    if ($physicalFunctions -contains $functionName) { return 'Physical gap workflow' }
    if ($recordFunctions -contains $functionName) { return 'Saving and records' }
    if ($plannerFunctions -contains $functionName) { return 'Pre-Test Planner' }
    if ($inputFunctions -contains $functionName) { return 'Input validation' }
    return 'User interface and explanation'
}

if ($Phase -eq 'inventory') {
    if (-not (Test-Path -LiteralPath $liveScriptPath -PathType Leaf)) {
        throw "The sealed V1.13 Live Script is missing: $liveScriptPath"
    }

    $releaseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $liveScriptPath).Hash.ToUpperInvariant()
    $releaseFile = Get-Item -LiteralPath $liveScriptPath
    $releaseCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Git could not read the audit commit.' }
    $fingerprintLines = @(
        'Neyer V1.13 frozen release fingerprint',
        "Audit commit: $releaseCommit",
        "File: delivery/Neyer_Gap_Test_v1_13.mlx",
        "Bytes: $($releaseFile.Length)",
        "SHA-256: $releaseHash",
        'Expected SHA-256: 2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E',
        "Hash matches frozen release: $($releaseHash -eq '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E')"
    )
    $fingerprintLines | Set-Content -Encoding utf8 -LiteralPath (Join-Path $evidenceFolder 'release-fingerprint.txt')

    $components = foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceFolder -Filter '*.m' -File | Sort-Object Name) {
        $functionName = [IO.Path]::GetFileNameWithoutExtension($sourceFile.Name)
        $lines = Get-Content -LiteralPath $sourceFile.FullName
        $purposeLine = $lines | Where-Object { $_ -match '^\s*%[A-Za-z0-9_]+\s{2,}.+' } | Select-Object -First 1
        if ($purposeLine) {
            $purpose = ($purposeLine -replace '^\s*%[A-Za-z0-9_]+\s*', '').Trim()
        } else {
            $purpose = "Application component for $($functionName -replace '_', ' ')."
        }
        [pscustomobject]@{
            gate = Get-AuditGate $functionName
            source_file = $sourceFile.Name
            public_function = $functionName
            purpose = $purpose
        }
    }
    $components | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath (Join-Path $evidenceFolder 'component-map.csv')

    Write-Output "V1.13 inventory complete: $($components.Count) source components mapped."
    Write-Output "Release SHA-256: $releaseHash"
}
