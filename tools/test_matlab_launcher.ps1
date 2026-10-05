param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'invoke_matlab.ps1'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw 'MATLAB launcher is missing.'
}

$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$preferenceFolder = Join-Path $resolvedRoot `
    '.matlab-prefs\R2022b-automation\launcher-test'
$matlabPreference = $preferenceFolder.Replace("'", "''")
$checkCommand = "assert(strcmp(prefdir, '$matlabPreference')); " +
    "disp('NEYER_MATLAB_LAUNCHER_PASS')"
$originalPreference = $env:MATLAB_PREFDIR

try {
    # Reproduce the original bad condition before each protected launch.
    $env:MATLAB_PREFDIR = 'MathWorks\MATLAB\R2022b'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher `
        -ProjectRoot $resolvedRoot `
        -PreferenceName 'launcher-test' `
        -BatchCommand $checkCommand
    if ($LASTEXITCODE -ne 0) {
        throw 'First protected MATLAB launch failed.'
    }

    $env:MATLAB_PREFDIR = 'MathWorks\MATLAB\R2022b'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher `
        -ProjectRoot $resolvedRoot `
        -PreferenceName 'launcher-test' `
        -BatchCommand $checkCommand
    if ($LASTEXITCODE -ne 0) {
        throw 'Second protected MATLAB launch failed.'
    }
}
finally {
    $env:MATLAB_PREFDIR = $originalPreference
}

Write-Output 'MATLAB launcher repeat test: PASS'
