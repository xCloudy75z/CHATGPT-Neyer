param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$html = Join-Path $ProjectRoot 'delivery\Neyer_Gap_Test_v1_9_Report.html'
$pdf = Join-Path $ProjectRoot 'review-preview\html-layout-check.pdf'
$word = $null
$document = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $document = $word.Documents.Open($html, $false, $true)
    $document.ExportAsFixedFormat($pdf, 17)
}
finally {
    if ($null -ne $document) { $document.Close($false) }
    if ($null -ne $word) { $word.Quit() }
}
Write-Output "Rendered $pdf"
