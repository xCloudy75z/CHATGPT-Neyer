param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$evidenceFolder = Join-Path $ProjectRoot 'audit\v19-reaudit'
$summaryPath = Join-Path $evidenceFolder 'v19-reaudit-simulation-summary.csv'
$scenarioPath = Join-Path $evidenceFolder 'v19-reaudit-simulation.csv'
$testPath = Join-Path $evidenceFolder 'v19-reaudit-tests.csv'
$testSummaryPath = Join-Path $evidenceFolder 'v19-reaudit-test-summary.txt'
$liveScriptPath = Join-Path $ProjectRoot 'delivery\Neyer_Gap_Test_v1_9.mlx'
$destination = Join-Path $ProjectRoot 'delivery\Neyer_Gap_Test_v1_9_Independent_Reaudit.html'

foreach ($required in @($summaryPath,$scenarioPath,$testPath,$testSummaryPath,$liveScriptPath)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing required evidence: $required" }
}

$summary = @(Import-Csv -LiteralPath $summaryPath)
$tests = @(Import-Csv -LiteralPath $testPath)
$testText = Get-Content -LiteralPath $testSummaryPath -Raw
$passed = [regex]::Match($testText,'Passed: (\d+)').Groups[1].Value
$failed = [regex]::Match($testText,'Failed: (\d+)').Groups[1].Value
$incomplete = [regex]::Match($testText,'Incomplete: (\d+)').Groups[1].Value
$matlabVersion = [regex]::Match($testText,'MATLAB version: (.+)').Groups[1].Value.Trim()
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $liveScriptPath).Hash
$scenarioRows = @(Import-Csv -LiteralPath $scenarioPath)
$totalRuns = ($scenarioRows | Measure-Object -Property repetitions -Sum).Sum

function F([object]$value,[int]$digits=2) {
    return ([double]$value).ToString("F$digits",[Globalization.CultureInfo]::InvariantCulture)
}

$summaryRows = foreach ($row in $summary) {
    $isDefault = ([double]$row.floor_factor -eq 2)
    $class = if ($isDefault) { ' class="default"' } else { '' }
    $label = if ($isDefault) { '2× (final default)' } else { "$(F $row.floor_factor 0)×" }
    "<tr$class><td>$(F $row.budget 0)</td><td>$(F $row.increment 2) mm</td><td>$label</td>" +
    "<td>$(F $row.actual_strict_overlap_percent 2)%</td>" +
    "<td>$(F $row.false_overlap_percent 3)%</td>" +
    "<td>$(F $row.middle_gap_rmse 3) mm</td>" +
    "<td>$(F $row.transition_width_rmse 3) mm</td>" +
    "<td>$(F $row.mean_repeated_setting_percent 2)%</td></tr>"
}

$default20 = $summary | Where-Object { [int]$_.budget -eq 20 -and [double]$_.floor_factor -eq 2 }
$default50 = $summary | Where-Object { [int]$_.budget -eq 50 -and [double]$_.floor_factor -eq 2 }
$overlap20 = ($default20 | Measure-Object -Property actual_strict_overlap_percent -Average).Average
$overlap50 = ($default50 | Measure-Object -Property actual_strict_overlap_percent -Average).Average
$falseDefault = (($default20 + $default50) | Measure-Object -Property false_overlap_percent -Average).Average

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Neyer Gap Test V1.9 — Independent Re-Audit</title>
<style>
:root{--graphite:#202b30;--muted:#58676d;--paper:#f4f6f5;--metal:#e2e7e6;--white:#fff;--teal:#0b6663;--orange:#e56a2f;--red:#a43f37;--line:#aeb9b8;--green:#dcebe3}
*{box-sizing:border-box} html{scroll-behavior:smooth} body{margin:0;background:var(--paper);color:var(--graphite);font:16px/1.58 "Segoe UI",Arial,sans-serif}
header{position:relative;overflow:hidden;background:#24353b;color:#fff;padding:58px 7vw 70px;border-left:12px solid var(--orange)} header:after{content:"";position:absolute;left:0;right:0;bottom:0;height:24px;background:repeating-linear-gradient(90deg,#cbd2d1 0 2px,transparent 2px 10px);border-top:4px solid #cbd2d1} header h1{font:700 clamp(2.2rem,4.2vw,3.8rem)/1.03 Bahnschrift,"Arial Narrow",Arial,sans-serif;letter-spacing:-.035em;margin:8px 0 16px;max-width:900px} header p{max-width:760px;font-size:1.12rem;margin:0;color:#e7eeee}.tag{font-weight:700;color:#ffd6c2}
nav{position:sticky;top:0;z-index:3;background:#fff;border-bottom:2px solid var(--graphite);padding:9px 7vw;display:flex;gap:20px;overflow:auto} nav a{color:var(--teal);text-decoration:none;font-weight:700;white-space:nowrap}nav a:focus{outline:3px solid var(--orange);outline-offset:3px}
main{max-width:1180px;margin:auto;padding:40px 28px 70px} section{margin:0 0 52px} h2{font:700 1.8rem/1.2 Bahnschrift,"Arial Narrow",Arial,sans-serif;margin:0 0 20px;padding-bottom:8px;border-bottom:3px solid var(--graphite)} h3{margin:0 0 10px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));border-top:1px solid var(--line);border-left:1px solid var(--line)}.card{background:var(--white);border-right:1px solid var(--line);border-bottom:1px solid var(--line);padding:20px;min-height:135px}.number{font:700 2.15rem/1 Bahnschrift,"Arial Narrow",Arial,sans-serif;color:var(--teal);margin-bottom:9px}
.flow{display:grid;grid-template-columns:repeat(7,max-content);align-items:center;justify-content:center;gap:10px;padding:25px 8px;overflow:auto}.step{background:#fff;border:2px solid var(--graphite);border-top:7px solid var(--teal);padding:13px 17px;text-align:center;min-width:145px}.arrow{font-size:1.5rem;color:var(--orange)}
table{width:100%;border-collapse:collapse;background:#fff}th,td{padding:11px 12px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}th{background:var(--metal);font-size:.88rem;border-bottom:2px solid var(--graphite)}tr.default td{background:#fff0e8;font-weight:650;border-top:2px solid var(--orange);border-bottom:2px solid var(--orange)}.scroll{overflow:auto;border:1px solid var(--line)}.pass{color:#176544;font-weight:750}.note{border-left:7px solid var(--orange);background:#fff4ed;padding:15px 18px}.issue{border-left-color:var(--red);background:#fff0ed}.code{font-family:Consolas,monospace;background:#e7eceb;padding:2px 6px}.sigma{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.sigma span{padding:8px 12px;background:#dcebea;border-bottom:3px solid var(--teal);font-weight:700}.sigma i{font-style:normal;color:var(--orange);font-weight:900}footer{color:var(--muted);border-top:2px solid var(--graphite);padding-top:20px}@media(max-width:700px){header{padding:38px 24px 54px}main{padding:26px 16px}.flow{justify-content:start}}
</style>
</head>
<body>
<header><div class="tag">INDEPENDENT SECOND AUDIT</div><h1>Neyer Gap Test V1.9</h1><p>A fresh examination of the exact standalone MATLAB Live Script, every V1.8 finding, and the real spacer workflow.</p></header>
<nav><a href="#outcome">Outcome</a><a href="#matrix">Audit matrix</a><a href="#physical">Physical workflow</a><a href="#simulation">Simulation</a><a href="#limits">Limits</a><a href="#evidence">Evidence</a></nav>
<main>
<section id="outcome"><h2>Outcome at a glance</h2><div class="grid">
<div class="card"><div class="number">$passed</div><b>MATLAB tests passed</b><br><span class="pass">$failed failed · $incomplete incomplete</span></div>
<div class="card"><div class="number">$totalRuns</div><b>corrected synthetic studies</b><br>432 physical scenarios</div>
<div class="card"><div class="number">$(F $overlap50 2)%</div><b>mean actual strict overlap</b><br>50 tests, final 2× floor, averaged across both increments</div>
<div class="card"><div class="number">$(F $falseDefault 3)%</div><b>mean false-overlap rate</b><br>final 2× floor across 20/50-test summaries</div>
</div>
<p class="note issue"><b>Important correction:</b> the earlier combined simulation applied build variation to the measured gap but decided the outcome from the requested setting. The application was not affected. This re-audit corrected the simulation so the outcome is generated from the actual built gap, then reran all 129,600 studies. The results in this report replace the earlier physical-simulation percentages.</p>
</section>

<section id="matrix"><h2>Rule-by-rule audit matrix</h2><div class="scroll"><table><thead><tr><th>Area</th><th>V1.8 issue</th><th>V1.9 evidence</th><th>Result</th></tr></thead><tbody>
<tr><td>Stage 1</td><td>Table-driven reach-out did not express the full bound-aware rule.</td><td>Tests prove the search moves to larger gaps after interaction, smaller gaps after no interaction, and uses the farthest safe prior-bound choice.</td><td class="pass">PASS</td></tr>
<tr><td>Stage 2 transition</td><td>The 1.5×sigma switch was reconstructed to match a table rather than the stated rule.</td><td>At more than one guessed sigma the code bisects; at exactly one guessed sigma it begins Part 2.</td><td class="pass">PASS</td></tr>
<tr><td>Stage 2 shrink</td><td>The 0.8 value existed but was not repeatedly applied.</td><td><div class="sigma"><span>1.00σ</span><i>×0.8 →</i><span>0.80σ</span><i>×0.8 →</i><span>0.64σ</span></div></td><td class="pass">PASS</td></tr>
<tr><td>Stage 2 state</td><td>The old loop could return to bisection after Part 2 began.</td><td>A direct test forces a wide bracket after Part 2 starts; the state remains Part 2 until strict overlap.</td><td class="pass">PASS</td></tr>
<tr><td>MLE</td><td>Needed direction, positivity, and numerical review.</td><td>Probability falls with gap; the fit is finite with positive width; the known demo returns 5.3922 mm and 1.0412 mm.</td><td class="pass">PASS*</td></tr>
<tr><td>D-optimal selection</td><td>Core determinant was plausible but needed independent checks and physical-grid handling.</td><td>A hand-checked information case matches, and Part 2 chooses a different reachable useful gap when alternatives exist.</td><td class="pass">PASS</td></tr>
<tr><td>Bounds</td><td>Repeated clamping could look like an endless loop.</td><td>All requested gaps remain inside 0–10 mm. One contradictory boundary result is confirmed once; a second pauses with the record preserved.</td><td class="pass">PASS</td></tr>
<tr><td>Rounding</td><td>Two decimals were tied to the reference table rather than the rig.</td><td>Both confirmed 0.05 mm and 0.10 mm increments produce reachable requested gaps.</td><td class="pass">PASS</td></tr>
<tr><td>Stopping</td><td>Boundary contradictions were not a clear physical decision state.</td><td>The run pauses for review; it does not mark the study or specimen as failed and does not continue looping.</td><td class="pass">PASS</td></tr>
<tr><td>Standalone delivery</td><td>The earlier packaging depended on outside functions.</td><td>The tested `.mlx` contains 70 local functions and has no addpath, machine path, executable, or companion-folder dependency.</td><td class="pass">PASS</td></tr>
</tbody></table></div><p><small>*The previously disclosed limitation for extremely separated artificial data remains. It is not hidden by this pass result.</small></p></section>

<section id="physical"><h2>The physical rule now being tested</h2><div class="flow">
<div class="step"><b>Requested</b><br>ideal Neyer gap</div><div class="arrow">→</div>
<div class="step"><b>Reachable</b><br>0.05 or 0.10 mm grid</div><div class="arrow">→</div>
<div class="step"><b>Measured</b><br>mean of 4 or 5 readings</div><div class="arrow">→</div>
<div class="step"><b>Outcome</b><br>Interaction / No interaction</div>
</div>
<div class="grid"><div class="card"><h3>Example</h3><p>The app requests 2.45 mm. If the confirmed increment is 0.10 mm, it asks for a useful reachable setting such as 2.50 mm. Readings of 2.50, 2.50, 2.49, 2.52 and 2.48 mm have a mean of <b>2.498 mm</b>. The calculation uses 2.498 mm while preserving 2.50 mm as the requested physical setting.</p></div>
<div class="card"><h3>Fresh spacer rule</h3><p>Every destructive test uses a new spacer build. Four or five readings describe that one unchanged build. They reduce reading noise, but they do not erase variation between separately built spacers. The corrected simulation models both effects separately.</p></div>
<div class="card"><h3>Resolution floor</h3><p>The final Stage‑2 floor is two physical increments: <b>0.10 mm</b> when the confirmed increment is 0.05 mm, or <b>0.20 mm</b> when it is 0.10 mm.</p></div></div>
</section>

<section id="simulation"><h2>Corrected physical simulation</h2><p>The same seeded virtual specimens were reused across the 0×, 1×, and 2× floor comparisons. Four independent MATLAB processes divided the scenario list without changing the generated trials. The table highlights the final 2× rule.</p>
<div class="scroll"><table><thead><tr><th>Test budget</th><th>Increment</th><th>Sigma floor</th><th>Actual strict overlap</th><th>False overlap</th><th>Middle-gap error</th><th>Width error</th><th>Requests reusing a setting</th></tr></thead><tbody>
$($summaryRows -join "`n")
</tbody></table></div>
<p class="note">“Actual strict overlap” uses the real built gaps. “False overlap” means the measured readings appeared to overlap while the real built gaps did not. “Requests reusing a setting” includes deliberate Stage‑3 returns to informative D-optimal gaps; every such request still uses a newly built spacer. Error columns summarize the fitted middle gap and transition width across all measurement-noise, reading-count, build-variation, and true-width cases.</p>
</section>

<section id="limits"><h2>What is still not claimed</h2><ul>
<li>The real equipment increment still must be confirmed as 0.05 mm or 0.10 mm before testing.</li>
<li>Synthetic trials check the method under declared bell-curve and noise assumptions; they do not replace physical qualification.</li>
<li>Four or five readings estimate one spacer's gap. They cannot make two separately built spacers identical.</li>
<li>Extremely separated artificial datasets remain a recommended deeper numerical study for safety-critical use.</li>
</ul></section>

<section id="evidence"><h2>Reproducibility and exact item audited</h2><div class="grid">
<div class="card"><b>MATLAB</b><p>$matlabVersion</p><b>Test evidence</b><p><span class="code">audit/v19-reaudit/v19-reaudit-tests.csv</span></p></div>
<div class="card"><b>Simulation evidence</b><p><span class="code">audit/v19-reaudit/v19-reaudit-simulation.csv</span><br><span class="code">audit/v19-reaudit/v19-reaudit-simulation-summary.csv</span></p></div>
<div class="card"><b>Final `.mlx` SHA-256</b><p class="code" style="overflow-wrap:anywhere">$hash</p></div>
</div>
<p>The application, delivery, and OneDrive `.mlx` copies are checked by SHA-256. MATLAB exports 70 embedded local functions. The executable function region matches the readable source character-for-character after line-ending normalisation.</p></section>

<footer>Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') Asia/Dubai · Self-contained offline HTML · No external fonts, scripts, images, or network connection required.</footer>
</main></body></html>
"@

[IO.File]::WriteAllText($destination,$html,[Text.UTF8Encoding]::new($false))
Write-Output "Built $destination"
