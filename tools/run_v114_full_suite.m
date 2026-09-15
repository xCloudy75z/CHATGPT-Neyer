function results = run_v114_full_suite()
%RUN_V114_FULL_SUITE Run current shared tests plus every V1.14 release test.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
testFiles = dir(fullfile(projectRoot, 'tests', 'Test*.m'));
names = string({testFiles.name});
archivedVersionGate = ~cellfun('isempty', regexp(cellstr(names), ...
    '^TestV(19|110|111|112|113|2)', 'once'));
currentFiles = fullfile({testFiles(~archivedVersionGate).folder}, ...
    {testFiles(~archivedVersionGate).name});
suiteParts = cell(numel(currentFiles), 1);
for fileNumber = 1:numel(currentFiles)
    oneSuite = testsuite(currentFiles{fileNumber});
    suiteParts{fileNumber} = oneSuite(:);
end
suite = vertcat(suiteParts{:});
recorderFolder = fullfile(projectRoot, 'measurement-recorder', 'tests');
if isfolder(recorderFolder)
    recorderSuite = testsuite(recorderFolder);
    suite = [suite; recorderSuite(:)];
end

startTime = tic;
results = run(suite);
elapsedSeconds = toc(startTime);
passed = sum([results.Passed]);
failed = sum([results.Failed]);
incomplete = sum([results.Incomplete]);

evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
evidencePath = fullfile(evidenceFolder, 'full-suite-results.txt');
fileId = fopen(evidencePath, 'w');
assert(fileId >= 0, 'Could not write the V1.14 suite evidence.');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer Gap Test V1.14 full relevant suite\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    passed, failed, incomplete);
fprintf(fileId, 'Elapsed seconds: %.3f\n', elapsedSeconds);
fprintf(fileId, ['Archived version-specific gates excluded: V1.9, V1.10, ' ...
    'V1.11, V1.12, V1.13 audit snapshots, and abandoned V2.\n']);
fprintf(fileId, 'V1.13 preservation is covered by TestV114ReleaseIsolation.\n');
for resultNumber = 1:numel(results)
    fprintf(fileId, '%s | Passed=%d Failed=%d Incomplete=%d\n', ...
        results(resultNumber).Name, results(resultNumber).Passed, ...
        results(resultNumber).Failed, results(resultNumber).Incomplete);
end
fprintf('\nV1.14 FULL SUITE: %d passed, %d failed, %d incomplete.\n', ...
    passed, failed, incomplete);
assert(failed == 0 && incomplete == 0, ...
    'V1.14 full suite did not pass completely.');
end
