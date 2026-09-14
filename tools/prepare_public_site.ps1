[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepositoryRoot) {
    $RepositoryRoot = Join-Path $PSScriptRoot ".."
}

try {
    $repository = Get-Item -LiteralPath $RepositoryRoot -ErrorAction Stop
}
catch {
    throw "Repository root is missing: $RepositoryRoot"
}

if (-not $repository.PSIsContainer) {
    throw "Repository root is not a directory: $($repository.FullName)"
}

$siteRoot = Join-Path $repository.FullName "site"
New-Item -ItemType Directory -Path $siteRoot -Force | Out-Null

$copies = @(
    [PSCustomObject]@{
        Source = "delivery/Neyer_Gap_Test_v1_12.mlx"
        Destination = "site/downloads/Neyer_Gap_Test_v1_12.mlx"
    },
    [PSCustomObject]@{
        Source = "delivery/General_Measurement_Recorder.m"
        Destination = "site/downloads/General_Measurement_Recorder.m"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-01-main-menu.png"
        Destination = "site/assets/screens/v110-01-main-menu.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-02-planner-input.png"
        Destination = "site/assets/screens/v110-02-planner-input.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-03-planner-review.png"
        Destination = "site/assets/screens/v110-03-planner-review.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-04-test-inputs.png"
        Destination = "site/assets/screens/v110-04-test-inputs.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-05-requested-gap.png"
        Destination = "site/assets/screens/v110-05-requested-gap.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-06-results.png"
        Destination = "site/assets/screens/v110-06-results.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v110-07-help.png"
        Destination = "site/assets/screens/v110-07-help.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v112-05-one-measured-gap.png"
        Destination = "site/assets/screens/v112-05-one-measured-gap.png"
    },
    [PSCustomObject]@{
        Source = "assets/screenshots/v112-07-help.png"
        Destination = "site/assets/screens/v112-07-help.png"
    },
    [PSCustomObject]@{
        Source = "audit/v112/full-suite-results.txt"
        Destination = "site/evidence-files/v112-full-suite-results.txt"
    },
    [PSCustomObject]@{
        Source = "audit/v112/test-matrix.md"
        Destination = "site/evidence-files/v112-test-matrix.md"
    },
    [PSCustomObject]@{
        Source = "audit/direct-62-trials/five-trial-audit.txt"
        Destination = "site/evidence-files/v112-five-trial-audit.txt"
    },
    [PSCustomObject]@{
        Source = "audit/v112/standalone-clean-start.txt"
        Destination = "site/evidence-files/v112-standalone-clean-start.txt"
    },
    [PSCustomObject]@{
        Source = "audit/v112/general-recorder-clean-start.txt"
        Destination = "site/evidence-files/v112-general-recorder-clean-start.txt"
    },
    [PSCustomObject]@{
        Source = "audit/v112/spacer-sample-summary.md"
        Destination = "site/evidence-files/v112-spacer-sample-summary.md"
    },
    [PSCustomObject]@{
        Source = "audit/v112/spacer-sample-readings.csv"
        Destination = "site/evidence-files/v112-spacer-sample-readings.csv"
    }
)

foreach ($copy in $copies) {
    $sourcePath = Join-Path $repository.FullName $copy.Source
    try {
        $source = Get-Item -LiteralPath $sourcePath -ErrorAction Stop
    }
    catch {
        throw "Required reviewed source is missing: $($copy.Source)"
    }
    if ($source.PSIsContainer) {
        throw "Required reviewed source is not a file: $($copy.Source)"
    }

    $destinationPath = Join-Path $repository.FullName $copy.Destination
    $destinationDirectory = Split-Path -Parent $destinationPath
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $source.FullName -Destination $destinationPath -Force
}

Write-Output "Prepared 18 verified public release files."
