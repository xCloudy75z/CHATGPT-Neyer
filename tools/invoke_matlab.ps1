param(
    [Parameter(Mandatory = $true)]
    [string]$BatchCommand,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$PreferenceName = 'default',
    [string]$LogFile = ''
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not [System.IO.Path]::IsPathRooted($resolvedRoot)) {
    throw 'The MATLAB project folder must be a full path.'
}

$preferenceFolder = Join-Path $resolvedRoot `
    ".matlab-prefs\R2022b-automation\$PreferenceName"
New-Item -ItemType Directory -Force -Path $preferenceFolder | Out-Null
$preferenceFolder = (Resolve-Path -LiteralPath $preferenceFolder).Path

$matlab = Get-Command matlab -ErrorAction Stop
$originalPreference = $env:MATLAB_PREFDIR
$exitCode = 1

try {
    # MATLAB officially supports this value at startup. Keeping it inside the
    # writable project prevents the relative-path startup failure seen when an
    # automated process cannot use the normal Windows preferences folder.
    $env:MATLAB_PREFDIR = $preferenceFolder
    Write-Output "MATLAB preferences: $preferenceFolder"

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        & $matlab.Source -batch $BatchCommand
    }
    else {
        $resolvedLog = $LogFile
        if (-not [System.IO.Path]::IsPathRooted($resolvedLog)) {
            $resolvedLog = Join-Path $resolvedRoot $resolvedLog
        }
        $logFolder = Split-Path -Parent $resolvedLog
        if (-not [string]::IsNullOrWhiteSpace($logFolder)) {
            New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
        }
        & $matlab.Source -logfile $resolvedLog -batch $BatchCommand
    }
    $exitCode = $LASTEXITCODE
}
finally {
    if ($null -eq $originalPreference) {
        Remove-Item Env:MATLAB_PREFDIR -ErrorAction SilentlyContinue
    }
    else {
        $env:MATLAB_PREFDIR = $originalPreference
    }
}

exit $exitCode
