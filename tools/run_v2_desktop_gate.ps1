param(
    [ValidateSet('suite','capture','clean')][string]$Gate='suite',
    [ValidatePattern('^(candidate-[0-9]{2})?$')][string]$AuditVersion=''
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$matlab=(Get-Command matlab.exe).Source
$env:NEYER_V2_AUDIT_VERSION=$AuditVersion
$script = switch ($Gate) {
    'suite' { "run('tools/run_v2_full_suite.m');" }
    'capture' { "run('tools/capture_v2_inputs.m'); clear; run('tools/capture_v2_help.m'); clear; run('tools/capture_v2_menu_and_test.m'); clear; addpath('tools'); capture_v2_results;" }
    'clean' { "run('tools/verify_v2_clean_start.m');" }
}
$code="try, addpath('tools'); $script exit(0); catch problem, disp(getReport(problem,'extended')); exit(1); end"
$evidenceFolder=Join-Path $root 'audit/v2'
if ($AuditVersion) { $evidenceFolder=Join-Path $evidenceFolder $AuditVersion }
New-Item -ItemType Directory -Force -Path $evidenceFolder | Out-Null
$log=Join-Path $evidenceFolder "desktop-$Gate.log"
$process=Start-Process -FilePath $matlab -WorkingDirectory $root -WindowStyle Hidden -PassThru -Wait -ArgumentList @('-wait','-desktop','-logfile',('"'+$log+'"'),'-r',('"'+$code+'"'))
if ($process.ExitCode -ne 0) { throw "V2 $Gate gate exited with $($process.ExitCode); see $log" }
Write-Output "V2 desktop $Gate process completed successfully. See $log"
