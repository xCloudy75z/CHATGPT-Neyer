param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$vendorDir = Join-Path $RepositoryRoot 'vendor'
$baselineDir = Join-Path $RepositoryRoot 'baseline'
$functionsDir = Join-Path $baselineDir 'functions'
$vendorCopy = Join-Path $vendorDir 'neyer-v1.8.mlx'
$bundleFile = Join-Path $baselineDir 'neyer_v1_8.m'
$extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ('neyer-mlx-' + [guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Force -Path $vendorDir, $baselineDir, $functionsDir, $extractDir | Out-Null
Copy-Item -LiteralPath $Source -Destination $vendorCopy -Force

try {
    tar -xf $Source -C $extractDir
    if ($LASTEXITCODE -ne 0) {
        throw "tar failed with exit code $LASTEXITCODE"
    }

    $documentPath = Join-Path $extractDir 'matlab\document.xml'
    [xml]$document = Get-Content -Raw -LiteralPath $documentPath
    $namespaces = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
    $namespaces.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    $codeBlocks = $document.SelectNodes('//w:p[w:pPr/w:pStyle[@w:val="code"]]', $namespaces) |
        ForEach-Object { $_.InnerText }
    $bundle = ($codeBlocks -join "`r`n`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($bundleFile, $bundle, [System.Text.UTF8Encoding]::new($false))

    $pattern = '(?ms)^% ==== from (?<path>.+?) ====\r?\n(?<body>.*?)(?=^% ==== from |\z)'
    $matches = [regex]::Matches($bundle, $pattern)
    foreach ($match in $matches) {
        $relativeSource = $match.Groups['path'].Value.Trim()
        $filename = [System.IO.Path]::GetFileName($relativeSource)
        $body = $match.Groups['body'].Value.TrimEnd() + "`r`n"
        $destination = Join-Path $functionsDir $filename
        [System.IO.File]::WriteAllText($destination, $body, [System.Text.UTF8Encoding]::new($false))
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Source).Hash
    $copyHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $vendorCopy).Hash
    if ($sourceHash -ne $copyHash) {
        throw 'Vendor copy hash differs from supplied Live Script.'
    }

    [pscustomobject]@{
        Source = $Source
        VendorCopy = $vendorCopy
        SHA256 = $sourceHash
        ExtractedBundle = $bundleFile
        FunctionFiles = $matches.Count
    }
}
finally {
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
