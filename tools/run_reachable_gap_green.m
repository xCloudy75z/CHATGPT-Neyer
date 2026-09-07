project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', ...
    'TestReachableGapModel.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'reachable-gap-green-test.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create reachable-gap test evidence.');
fprintf(file_id, 'Reachable-gap tests after implementation\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
for result_number = 1:numel(result)
    if ~result(result_number).Passed
        fprintf(file_id, 'NOT PASSED: %s\n', result(result_number).Name);
        details = result(result_number).Details;
        if isfield(details, 'DiagnosticRecord') && ~isempty(details.DiagnosticRecord)
            for record_number = 1:numel(details.DiagnosticRecord)
                fprintf(file_id, '%s\n', ...
                    details.DiagnosticRecord(record_number).Report);
            end
        end
    end
end
fclose(file_id);
if all([result.Passed]), exit(0); end
exit(1);
