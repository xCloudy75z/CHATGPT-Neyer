project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
test_files = { ...
    'TestResultDecision.m', ...
    'TestStudyCheckpoint.m', ...
    'TestStudyPlanStorage.m', ...
    'TestPhysicalUiInputs.m', ...
    'TestReachableGapModel.m'};
suite = testsuite(fullfile(project_root, 'tests', test_files{1}));
for file_number = 2:numel(test_files)
    suite = [suite testsuite(fullfile(project_root, 'tests', ...
        test_files{file_number}))]; %#ok<AGROW>
end
result = run(suite);
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'final-review-regressions.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not record the final-review regression tests.');
fprintf(file_id, 'Final independent-review regression group\n');
fprintf(file_id, 'MATLAB release: %s\n', version('-release'));
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
for result_index = 1:numel(result)
    if result(result_index).Failed
        fprintf(file_id, '\nFAILED: %s\n', result(result_index).Name);
        records = result(result_index).Details.DiagnosticRecord;
        for record_index = 1:numel(records)
            fprintf(file_id, '%s\n', records(record_index).Report);
        end
    end
end
fclose(file_id);
if any([result.Failed]) || any([result.Incomplete]), exit(1); end
exit(0);
