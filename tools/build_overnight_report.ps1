param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$outputPath = Join-Path $ProjectRoot 'delivery\Neyer_Overnight_Verification_Report.html'
$screenshotRoot = Join-Path $ProjectRoot 'assets\screenshots'
$evidenceRoot = Join-Path $ProjectRoot 'audit\overnight'

function Require-File([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing required evidence: $Path" }
}

function Image-Data([string]$Name) {
    $path = Join-Path $screenshotRoot $Name
    Require-File $path
    return 'data:image/png;base64,' + [Convert]::ToBase64String(
        [System.IO.File]::ReadAllBytes($path))
}

function Percent([object]$Value) {
    return ([double]$Value * 100).ToString('0.0',
        [Globalization.CultureInfo]::InvariantCulture) + '%'
}

function Html([object]$Value) {
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

$fullSuitePath = Join-Path $evidenceRoot 'final-full-suite.txt'
$mockSummaryPath = Join-Path $evidenceRoot 'full-test-summary.txt'
$mockRoutesPath = Join-Path $evidenceRoot 'mock-lab-results.csv'
$validationPath = Join-Path $evidenceRoot 'planner-validation-summary.csv'
$validationMergePath = Join-Path $evidenceRoot 'planner-validation-merge.txt'
$hardCasesPath = Join-Path $evidenceRoot 'planner-hard-cases-summary.csv'
$standalonePath = Join-Path $evidenceRoot 'standalone-clean-start.txt'
$capturePath = Join-Path $evidenceRoot 'final-ui-capture.txt'
$reviewRegressionPath = Join-Path $evidenceRoot 'final-review-regressions.txt'
@($fullSuitePath, $mockSummaryPath, $mockRoutesPath, $validationPath,
  $validationMergePath, $hardCasesPath, $standalonePath, $capturePath,
  $reviewRegressionPath) |
    ForEach-Object { Require-File $_ }

$fullSuite = Get-Content -LiteralPath $fullSuitePath -Raw
$mockSummary = Get-Content -LiteralPath $mockSummaryPath -Raw
$standalone = Get-Content -LiteralPath $standalonePath -Raw
$reviewRegression = Get-Content -LiteralPath $reviewRegressionPath -Raw
$passedTests = [regex]::Match($fullSuite, 'Passed: (\d+)').Groups[1].Value
$failedTests = [regex]::Match($fullSuite, 'Failed: (\d+)').Groups[1].Value
$mockPassed = [regex]::Match($mockSummary, 'Passed: (\d+)').Groups[1].Value
$mockRoutes = [regex]::Match($mockSummary, 'Routes: (\d+)').Groups[1].Value
$embeddedFunctions = [regex]::Match($standalone, 'Embedded local functions: (\d+)').Groups[1].Value
$reviewPassed = [regex]::Match($reviewRegression, 'Passed: (\d+)').Groups[1].Value
if (-not $passedTests -or -not $mockPassed -or -not $embeddedFunctions -or
        -not $reviewPassed) {
    throw 'Could not read the recorded test evidence.'
}

$validationRows = @(Import-Csv -LiteralPath $validationPath)
$acceptedCount = @($validationRows | Where-Object conclusion -eq 'accepted').Count
$withheldCount = @($validationRows | Where-Object conclusion -eq 'withheld').Count
$notAcceptedCount = @($validationRows | Where-Object conclusion -eq 'not accepted').Count
if ($validationRows.Count -ne 12 -or $acceptedCount -ne 8 -or
        $withheldCount -ne 4 -or $notAcceptedCount -ne 0) {
    throw 'Planner validation evidence does not match the frozen acceptance record.'
}

$validationTableRows = foreach ($row in $validationRows) {
    $resultClass = if ($row.conclusion -eq 'accepted') { 'pass' } else { 'hold' }
    $resultText = if ($row.conclusion -eq 'accepted') { 'Accepted' } else { 'Withheld' }
    $middleCoverage = if ($row.conclusion -eq 'accepted') {
        Percent $row.middle_coverage_rate
    } else { 'Not claimed' }
    $operatingCoverage = if ($row.conclusion -eq 'accepted') {
        Percent $row.operating_gap_coverage_rate
    } else { 'Not issued' }
    $increment = if ($row.scenario_id -match 'regular-(\d{3})') {
        ([double]$Matches[1] / 100).ToString('0.00') + ' mm'
    } else { 'Irregular reachable set' }
    "<tr><td>$(Html $row.outcome)</td><td>$([double]$row.reliability * 100)%</td><td>$([double]$row.confidence * 100)%</td><td>$increment</td><td>$middleCoverage</td><td>$operatingCoverage</td><td><span class=`"tag $resultClass`">$resultText</span></td></tr>"
}

$hardRows = @(Import-Csv -LiteralPath $hardCasesPath)
$hardTableRows = foreach ($row in $hardRows) {
    $caseName = if ($row.scenario_id -like '*irregular*') {
        'Irregular spacers, No interaction target'
    } else { '0.50 mm steps, sudden Interaction target' }
    $resultClass = if ($row.conclusion -eq 'accepted') { 'pass' } else { 'fail' }
    $resultText = if ($row.conclusion -eq 'accepted') { 'Accepted' } else { 'Not enough' }
    "<tr><td>$caseName</td><td>$($row.planned_total)</td><td>$(Percent $row.middle_coverage_rate)</td><td>$(Percent $row.operating_gap_coverage_rate)</td><td><span class=`"tag $resultClass`">$resultText</span></td></tr>"
}

$mockRows = @(Import-Csv -LiteralPath $mockRoutesPath)
$mockTableRows = foreach ($row in $mockRows) {
    "<tr><td>$(Html $row.route)</td><td>$(Html $row.purpose)</td><td>$($row.passed) / $($row.test_methods)</td></tr>"
}

$images = @{}
1..7 | ForEach-Object {
    $names = @(
        'v110-01-main-menu.png', 'v110-02-planner-input.png',
        'v110-03-planner-review.png', 'v110-04-test-inputs.png',
        'v110-05-requested-gap.png', 'v110-06-results.png',
        'v110-07-help.png')
    $images[$_] = Image-Data $names[$_ - 1]
}

$htmlDocument = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Neyer v1.10 overnight verification</title>
<style>
:root{--ink:#18313f;--deep:#153e56;--blue:#277b9d;--green:#2f806d;--green-pale:#e2f0eb;--amber:#b87521;--amber-pale:#fff3da;--red:#a44836;--red-pale:#f9e8e3;--line:#b9c9d1;--soft:#edf3f5;--paper:#fbfcfc;--white:#fff}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.58 "Segoe UI",Tahoma,Arial,sans-serif}a{color:#166687}a:focus{outline:3px solid #e7ad4b;outline-offset:3px}header{background:var(--deep);color:white;border-bottom:10px solid var(--green)}.hero{max-width:1280px;margin:auto;padding:58px 42px 46px;display:grid;grid-template-columns:minmax(0,1.4fr) minmax(280px,.6fr);gap:52px;align-items:end}.hero h1{font-size:clamp(38px,6vw,68px);line-height:1.02;margin:0 0 20px;letter-spacing:-.035em}.hero p{font-size:20px;max-width:780px;color:#e6f0f4}.clearance{background:white;color:var(--ink);padding:25px 28px;border-left:9px solid var(--green)}.clearance strong{display:block;color:#17624f;font-size:24px;margin-bottom:7px}.clearance span{display:block}.shell{max-width:1280px;margin:auto;display:grid;grid-template-columns:255px minmax(0,1fr);gap:42px;padding:36px 42px 90px}nav{position:sticky;top:20px;align-self:start;border-top:6px solid var(--blue);padding-top:16px}nav strong{font-size:18px;display:block;margin-bottom:9px}nav a{display:block;padding:7px 0;border-bottom:1px solid #dce5e9;text-decoration:none}main{min-width:0}section{padding:20px 0 44px;border-bottom:1px solid var(--line);scroll-margin-top:18px}h2{font-size:32px;line-height:1.17;margin:18px 0 16px;letter-spacing:-.02em}h3{font-size:21px;margin:26px 0 9px}.lead{font-size:20px;max-width:830px}.evidence-strip{display:grid;grid-template-columns:repeat(4,1fr);border:1px solid var(--line);margin:24px 0}.evidence-strip div{padding:19px;border-right:1px solid var(--line)}.evidence-strip div:last-child{border-right:0}.evidence-strip strong{display:block;font-size:27px;color:var(--deep)}.decision-grid{display:grid;grid-template-columns:1fr 1fr;gap:24px}.decision{padding:21px 24px;border-top:6px solid var(--green);background:var(--green-pale)}.decision.caution{border-color:var(--amber);background:var(--amber-pale)}.gap-scale{margin:28px 0 34px;display:grid;grid-template-columns:1fr 1fr;position:relative;gap:20px}.gap-scale:before{content:"";position:absolute;left:0;right:0;top:34px;height:7px;background:linear-gradient(90deg,#c76945 0,#e2b66f 45%,#6d9e92 70%,#277b9d 100%)}.gap-end{position:relative;padding-top:53px;font-weight:650}.gap-end:last-child{text-align:right}.flow{display:grid;grid-template-columns:repeat(5,1fr);gap:0;margin:26px 0}.flow div{padding:18px 16px;background:var(--soft);border-top:5px solid var(--blue);border-right:1px solid var(--paper)}.flow b{display:block;margin-bottom:5px}.audit-grid{display:grid;grid-template-columns:190px 1fr 1fr;border-top:1px solid var(--line);border-left:1px solid var(--line)}.audit-grid div{padding:14px;border-right:1px solid var(--line);border-bottom:1px solid var(--line)}.audit-grid .head{background:var(--deep);color:white;font-weight:700}.audit-grid .area{font-weight:700;background:var(--soft)}table{width:100%;border-collapse:collapse;margin:20px 0 30px;font-size:14px}th{background:var(--deep);color:white;text-align:left}th,td{padding:10px 11px;border:1px solid var(--line);vertical-align:top}tbody tr:nth-child(even) td{background:#f1f5f6}.tag{display:inline-block;padding:3px 8px;font-weight:700;border-radius:2px;white-space:nowrap}.tag.pass{background:var(--green-pale);color:#17624f}.tag.hold{background:var(--amber-pale);color:#7b4d12}.tag.fail{background:var(--red-pale);color:#883724}.note{border-left:7px solid var(--amber);background:var(--amber-pale);padding:17px 21px;margin:22px 0;max-width:900px}.success{border-left-color:var(--green);background:var(--green-pale)}.screen-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}.screen-grid figure{margin:0}.screen-grid figure.wide{grid-column:1/-1}.screen-grid img{width:100%;display:block;border:1px solid #9fb1ba;background:white}.screen-grid figcaption{font-size:14px;margin-top:7px;color:#526975}.steps{counter-reset:step;list-style:none;padding:0;max-width:900px}.steps li{counter-increment:step;position:relative;padding:0 0 24px 58px}.steps li:before{content:counter(step);position:absolute;left:0;top:0;width:36px;height:36px;border:2px solid var(--blue);color:var(--deep);display:grid;place-items:center;font-weight:800;border-radius:50%}.file{font-family:Consolas,"Courier New",monospace;background:var(--soft);padding:2px 5px}.small{font-size:14px;color:#526975}.check-list{columns:2;column-gap:42px}.check-list li{break-inside:avoid;margin-bottom:9px}.footer{padding-top:28px;font-size:14px;color:#526975}@media(max-width:900px){.hero,.shell{grid-template-columns:1fr}.shell{padding:24px}.hero{padding:42px 24px}.hero nav,nav{position:static}.evidence-strip{grid-template-columns:1fr 1fr}.flow{grid-template-columns:1fr}.decision-grid,.screen-grid{grid-template-columns:1fr}.screen-grid figure.wide{grid-column:auto}.audit-grid{grid-template-columns:120px 1fr}.audit-grid .third{grid-column:2}.check-list{columns:1}}@media(max-width:520px){.evidence-strip{grid-template-columns:1fr}.evidence-strip div{border-right:0;border-bottom:1px solid var(--line)}h2{font-size:27px}}
</style>
</head>
<body>
<header><div class="hero"><div><h1>Neyer Gap Test v1.10</h1><p>Overnight build record, final re-audit, physical-workflow check, and MATLAB R2022b proof.</p></div><div class="clearance"><strong>Ready for your mock test</strong><span>The standalone Live Script passed its recorded checks. Your physical spacer confirmation is still a separate next step.</span></div></div></header>
<div class="shell">
<nav aria-label="Report contents"><strong>Contents</strong><a href="#outcome">Outcome</a><a href="#work-completed">What was completed</a><a href="#audit">Final audit</a><a href="#planner">Pre-test planner</a><a href="#physical-workflow">Physical workflow</a><a href="#testing">Testing</a><a href="#screens">MATLAB screens</a><a href="#operation">How to use it</a><a href="#saving">Saving</a><a href="#limitations">Limits</a><a href="#evidence">Evidence files</a></nav>
<main>
<section id="outcome"><h2>Outcome</h2><p class="lead">The v1.10 Live Script now stands alone. It plans the study, requests only reachable test gaps, records the measured gap from each new build, estimates the middle and overall variation, and withholds a safety instruction when the evidence is outside the tested rules.</p><div class="evidence-strip"><div><strong>$passedTests</strong>MATLAB tests passed</div><div><strong>$mockPassed / $mockPassed</strong>mock-route checks passed</div><div><strong>$acceptedCount accepted</strong>supported simulations</div><div><strong>$withheldCount withheld</strong>outside the supported range</div></div><div class="decision-grid"><div class="decision"><h3>What the software can do now</h3><p>Guide a gap study, estimate the 50/50 middle, show overall variation, and issue a cautious operating instruction when all supported conditions are met.</p></div><div class="decision caution"><h3>What it does not claim</h3><p>It does not call the middle gap 99% reliable. It does not treat 298 or 299 fixed-condition articles as the Neyer estimation rule. It does not claim that the unconfirmed foil setup can control every 0.015 mm step.</p></div></div></section>

<section id="work-completed"><h2>What was completed from the start of the project</h2><div class="flow"><div><b>Preserve</b>Kept the original v1.8 behaviour for comparison.</div><div><b>Characterise</b>Made regression tests reproduce the reference result before changing the method.</div><div><b>Correct</b>Fixed Stage 1, Stage 2, gap direction, bounds, rounding, and stopping behaviour.</div><div><b>Make physical</b>Separated requested gaps, measured readings, and the mean actually used.</div><div><b>Prove and package</b>Ran simulations, mock routes, a clean standalone start, and visual checks.</div></div><p>The final operator file is <span class="file">Neyer_Gap_Test_v1_10.mlx</span>. It contains all required functions inside the Live Script; the operator does not need the source folder.</p></section>

<section id="audit"><h2>Final re-audit against the v1.8 issues</h2><div class="audit-grid"><div class="head">Area</div><div class="head">Problem found in v1.8</div><div class="head third">v1.10 result</div><div class="area">Stage 1</div><div>The reference sequence was reproduced, but the outward search did not fully respect the intended bounds in every branch.</div><div>The bound-aware rule is used in the correct smaller-gap Interaction direction and is covered by regression tests.</div><div class="area">Stage 2 changeover</div><div>A 1.5 × guessed sigma rule was chosen to copy the table; it was not established by the Neyer method.</div><div>The changeover uses 1.0 × the guessed overall variation. The 1.5 choice was removed.</div><div class="area">Stage 2 narrowing</div><div>The configured 0.8 narrowing factor was not applied by the decision loop.</div><div>Each separated Stage-2 result multiplies the working variation by 0.8. It never grows back or returns to the earlier stage.</div><div class="area">MLE estimate</div><div>The probit likelihood and positive sigma form were conceptually sound, but confidence-tail behaviour needed checks.</div><div>The fitted middle and overall variation are retained, with corrected one-sided confidence handling and disclosed numerical limits for extreme artificial data.</div><div class="area">D-optimal choice</div><div>The information calculation matched the method, while the search fence and grid were engineering choices.</div><div>The information choice is retained, then mapped to a reachable and useful physical setting.</div><div class="area">Bounds</div><div>Repeated use of a boundary could appear to be a failed or looping test.</div><div>One confirmation is requested. A second contradiction pauses safely, preserves the data, and asks for review.</div><div class="area">Rounding</div><div>Fixed decimal rounding could request a gap the equipment could not build.</div><div>The app selects from the study's reachable settings. The request is always displayed with two decimal places; raw readings keep their entered precision.</div><div class="area">Stopping</div><div>Some no-alternative cases could repeat a setting without a clear reason.</div><div>The app chooses the nearest different reachable and useful setting. If none exists, it pauses instead of pretending the run can continue.</div></div><div class="note"><b>Independent final-review fixes:</b> A second review found that edited safety fields could fail open, a 0.015 mm foil component could be mistaken for the usable test step, and a later boundary clamp could undo a reachable setting. All three were reproduced before correction. The final focused group recorded <b>$reviewPassed / $reviewPassed</b> passing checks after the fixes.</div></section>

<section id="planner"><h2>What the pre-test planner means</h2><p>The planner answers two separate questions. First: how many new articles are likely to estimate the middle gap to the requested accuracy? Second: has enough supported evidence been collected to issue a cautious reliability instruction?</p><div class="decision-grid"><div class="decision"><h3>Main study</h3><p>The main quantity is calculated from the requested gap accuracy. It can estimate the middle gap and overall variation before 400 articles.</p></div><div class="decision caution"><h3>Reliability checkpoint</h3><p>A safety-supported operating instruction requires at least <b>400 independent articles</b>. Reserve groups are prepared but never used automatically.</p></div></div><table><thead><tr><th>Confidence entered</th><th>What v1.10 does</th><th>Reason</th></tr></thead><tbody><tr><td>10% to 50%</td><td>Calculates an exploratory study, but withholds the reliability instruction.</td><td>The recorded simulations did not support a safety claim in this range.</td></tr><tr><td>Above 50% to 95%</td><td>Uses the supported planner and the 400-article checkpoint.</td><td>This is the tested confidence range.</td></tr><tr><td>Above 95% to 99.9%</td><td>Calculates for learning, but withholds the reliability instruction.</td><td>The overnight simulation size cannot prove a claim as high as 99.9% confidence.</td></tr></tbody></table><div class="note"><b>Separate qualification idea:</b> A zero-failure demonstration at one already-chosen gap is not the Neyer study. The specific 298-article requirement and the conservative 299-article calculation belong to that separate fixed-condition task; v1.10 does not mix them into the Neyer planner.</div></section>

<section id="physical-workflow"><h2>How the physical gap enters the calculation</h2><div class="gap-scale"><div class="gap-end">Smaller gap<br>Interaction more likely</div><div class="gap-end">Larger gap<br>No interaction more likely</div></div><ol class="steps"><li><b>The app requests a reachable build gap.</b> It shows two decimal places, for example 2.45 mm.</li><li><b>You build one new spacer setup.</b> Each destructive reaction consumes that build, so the next test uses another new build.</li><li><b>You measure the unchanged build four or five times.</b> For readings 2.50, 2.50, 2.49, 2.52, and 2.48 mm, the mean is 2.498 mm.</li><li><b>The app uses the measured mean.</b> The outcome belongs to 2.498 mm, not to the original 2.45 mm request.</li><li><b>You record Interaction or No interaction.</b> The raw readings, mean, request, and outcome remain together in the saved data.</li></ol><table><thead><tr><th>Physical item</th><th>Current information</th><th>How the code treats it</th></tr></thead><tbody><tr><td>Aluminium foil</td><td>About 0.015 mm per sheet</td><td>Construction information only. It does not prove 0.015 mm repeatable control.</td></tr><tr><td>Printed 0.5 mm spacer</td><td>Examples around 0.49 to 0.52 mm</td><td>Actual complete builds must be measured.</td></tr><tr><td>Printed 1 mm spacer</td><td>One observation around 1.10 mm</td><td>Nominal size is not used as if exact.</td></tr><tr><td>Printed 2 mm spacer</td><td>One observation around 2.09 mm</td><td>Nominal size is not used as if exact.</td></tr><tr><td>Combined 0.5 + 1 + 2 mm</td><td>One observation around 3.67 mm</td><td>Combination error is why the measured complete gap is used.</td></tr></tbody></table><div class="note"><b>Provisional equipment choice:</b> 0.05 mm remains a setting to confirm with repeated complete builds. The software also handles 0.10, 0.15, and 0.50 mm steps; a larger step gives fewer reachable choices and can reduce how precisely the change can be located.</div></section>

<section id="testing"><h2>Testing and simulation results</h2><h3>Fresh MATLAB and mock-laboratory checks</h3><table><thead><tr><th>Route</th><th>What it checked</th><th>Result</th></tr></thead><tbody>$($mockTableRows -join "`n")</tbody></table><p class="success note"><b>Recorded result:</b> $passedTests MATLAB tests passed, $failedTests failed, and none remained incomplete. The seven mock routes contained $mockPassed passing checks.</p><h3>Why the reliability checkpoint became 400 articles</h3><table><thead><tr><th>Difficult case</th><th>Articles</th><th>Middle covered</th><th>Operating gap covered</th><th>Decision</th></tr></thead><tbody>$($hardTableRows -join "`n")</tbody></table><p>The irregular-spacer No-interaction case missed the required 95% middle coverage with 200 and 300 articles, then reached 96.9% at 400. This is the recorded reason for the 400-article minimum. It is a conservative project rule supported by these simulations, not a universal Neyer number.</p><h3>Frozen 12-scenario check</h3><table><thead><tr><th>Outcome target</th><th>Reliability</th><th>Confidence</th><th>Reachable gaps</th><th>Middle covered</th><th>Operating gap covered</th><th>Result</th></tr></thead><tbody>$($validationTableRows -join "`n")</tbody></table><p>The eight scenarios inside the supported confidence range were accepted. Four were deliberately withheld because their confidence was at or below 50%, or above 95%. No supported scenario was rejected in this recorded run.</p><div class="note"><b>Extra physical safety step:</b> The calculated reliability boundary is first rounded in the safe direction, then moved one additional reachable setting in that same direction. This turned the difficult gradual R99.9/C95 case from 90% coverage to the required 95% in the stored comparison. If no extra safe setting exists inside the permitted range, the app withholds the instruction.</div></section>

<section id="screens"><h2>MATLAB R2022b screens checked visually</h2><div class="screen-grid"><figure><img src="$($images[1])" alt="Neyer v1.10 main menu"><figcaption>Main menu: plan, test, review, example, and help.</figcaption></figure><figure><img src="$($images[2])" alt="Pre-test planner input"><figcaption>Planner questions explain every required answer.</figcaption></figure><figure class="wide"><img src="$($images[3])" alt="Pre-test planner review"><figcaption>The review separates the main study, reserve groups, total preparation, and the reliability rule.</figcaption></figure><figure><img src="$($images[4])" alt="Run a test inputs"><figcaption>Physical study inputs keep usable gap step separate from foil thickness.</figcaption></figure><figure><img src="$($images[5])" alt="Requested gap and measured readings"><figcaption>The request uses two decimal places; four or five readings describe the new build.</figcaption></figure><figure class="wide"><img src="$($images[6])" alt="Results and supported operating instruction"><figcaption>The result screen separates the supported operating instruction, the 50/50 middle, overall variation, and the response curve.</figcaption></figure><figure><img src="$($images[7])" alt="Built-in operator guide"><figcaption>The standalone file contains its own guide and definitions.</figcaption></figure></div></section>

<section id="operation"><h2>How to use the final Live Script</h2><ol class="steps"><li>Open <span class="file">Neyer_Gap_Test_v1_10.mlx</span> in MATLAB R2022b.</li><li>Run the Live Script once. Select <b>Run the published example</b>; it must show a middle gap of <b>5.39 mm</b> and overall variation of <b>1.04 mm</b>.</li><li>Select <b>Pre-test Planner</b>. Enter the outcome you need, reliability, confidence, desired gap accuracy, known end conditions, permitted range, and reachable gap information.</li><li>Review the proposed main quantity and reserves. Save the plan if you want to reopen it later.</li><li>Select <b>Run a Test</b>. Load the saved plan, or enter the setup directly.</li><li>For each request, build and measure a new setup, enter four or five readings, then select the observed outcome.</li><li>At a checkpoint, decide whether to stop, use a reserve group, or review an unsupported result. The app does not consume reserves without your decision.</li></ol></section>

<section id="saving"><h2>Where the app saves data</h2><p>The app does not silently choose a hidden results folder. You select the folder and base name. Before saving, it shows both complete destinations:</p><ul><li><span class="file">&lt;your selected folder&gt;\&lt;your name&gt;.csv</span> contains the test requests, raw readings, measured means, and outcomes.</li><li><span class="file">&lt;your selected folder&gt;\&lt;your name&gt;.html</span> is a self-contained result report.</li></ul><p>If either name already exists, the app writes neither file and asks you to choose another name. Saved study plans use the same no-silent-overwrite rule.</p><h3>Standalone proof</h3><ul class="check-list"><li>Tested in a new temporary folder containing only the `.mlx`.</li><li>$embeddedFunctions embedded local functions found and matched to the reviewed build source.</li><li>No source folder, executable, internet connection, or add-on package required.</li><li>The published example opened and produced the recorded reference values.</li></ul></section>

<section id="limitations"><h2>Known limits and what remains for you</h2><ul><li>The 0.015 mm foil thickness is approximate. It must not be confused with proven 0.015 mm complete-gap control.</li><li>The provisional 0.05 mm usable step still needs repeated measurements of complete builds in the real casing, held radially without pressing or squeezing.</li><li>The 400-article rule is the conservative supported project checkpoint from the recorded simulation set. It is not a universal law for every material, machine, or requirement.</li><li>Confidence above 95% can be calculated for exploration, but v1.10 withholds a safety-supported operating instruction because that range was not validated here.</li><li>Very separated artificial data can still challenge the numerical fit. A safety-critical qualification programme should add an independent statistical review and more extreme-case testing.</li><li>Your next activity is a hands-on mock test of the complete app and the physical spacer build process. That user acceptance activity has not been claimed as completed.</li></ul></section>

<section id="evidence"><h2>Evidence and file map</h2><table><thead><tr><th>Evidence</th><th>Repository location</th></tr></thead><tbody><tr><td>Complete MATLAB suite</td><td><span class="file">audit/overnight/final-full-suite.txt</span></td></tr><tr><td>Independent-review regressions</td><td><span class="file">audit/overnight/final-review-regressions.txt</span></td></tr><tr><td>Seven mock-laboratory routes</td><td><span class="file">audit/overnight/full-test-summary.txt</span> and <span class="file">mock-lab-results.csv</span></td></tr><tr><td>400-article calibration</td><td><span class="file">audit/overnight/planner-hard-cases-summary.csv</span></td></tr><tr><td>Frozen 12-scenario result</td><td><span class="file">audit/overnight/planner-validation-summary.csv</span></td></tr><tr><td>Standalone clean start</td><td><span class="file">audit/overnight/standalone-clean-start.txt</span></td></tr><tr><td>Seven checked screens</td><td><span class="file">assets/screenshots/v110-01-main-menu.png</span> through <span class="file">v110-07-help.png</span></td></tr><tr><td>Final operator file</td><td><span class="file">delivery/Neyer_Gap_Test_v1_10.mlx</span></td></tr></tbody></table><p>Method basis: Barry T. Neyer, “A D-Optimality-Based Sensitivity Test,” <i>Technometrics</i>, 36(1), 61–70 (1994). The original v1.8 reference implementation remains preserved separately for comparison.</p><p class="footer">Built from the recorded v1.10 evidence. This report contains its styling and screenshots, so it opens without an internet connection.</p></section>
</main></div></body></html>
"@

[System.IO.File]::WriteAllText(
    $outputPath, $htmlDocument, [System.Text.UTF8Encoding]::new($false))
Write-Output "Built $outputPath"
Write-Output "Bytes: $((Get-Item -LiteralPath $outputPath).Length)"
