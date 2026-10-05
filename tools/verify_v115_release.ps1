param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'invoke_matlab.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher `
    -ProjectRoot $ProjectRoot `
    -PreferenceName 'v115-release' `
    -BatchCommand "run('tools/run_v115_release_verification.m')"
exit $LASTEXITCODE
