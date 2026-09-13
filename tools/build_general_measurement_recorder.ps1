param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$source = Join-Path $ProjectRoot 'measurement-recorder\source\General_Measurement_Recorder.m'
$delivery = Join-Path $ProjectRoot 'delivery\General_Measurement_Recorder.m'
$siteDelivery = Join-Path $ProjectRoot 'site\downloads\General_Measurement_Recorder.m'

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Recorder source was not found: $source"
}

Copy-Item -LiteralPath $source -Destination $delivery -Force
Copy-Item -LiteralPath $source -Destination $siteDelivery -Force
Write-Output "Built standalone recorder: $delivery"
