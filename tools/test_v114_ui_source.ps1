param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$appSource = Get-Content -LiteralPath (Join-Path $ProjectRoot 'application\source\neyer_app.m') -Raw
$inputSource = Get-Content -LiteralPath (Join-Path $ProjectRoot 'application\source\run_test_ui.m') -Raw

if ($appSource.Contains('Run the Published Example') -or $appSource.Contains('@onDemo')) {
    throw 'The opening menu still exposes the published-example shortcut.'
}
if (-not $appSource.Contains('Start a Gap Study') -or
        -not $appSource.Contains('Help and Definitions')) {
    throw 'The opening menu lost a required operator button.'
}
if (-not $inputSource.Contains("gl.Tag = 'direct_input_scroll_layout'") -or
        -not $inputSource.Contains("gl.Scrollable = 'on'")) {
    throw 'The direct-input settings layout is not explicitly scrollable.'
}
if (-not $inputSource.Contains("'Position', [220 30 860 680]")) {
    throw 'The direct-input settings window is not using the approved screen-sized position.'
}

Write-Output 'V1.14 UI source gate passed.'
