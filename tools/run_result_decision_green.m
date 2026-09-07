project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestResultDecision.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'result-decision-green-test.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create result-decision green evidence.');
fprintf(file_id, 'Result decision tests after implementation\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fprintf(file_id, '\n%s\n', evalc('disp(result)'));
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
if any([result.Failed]), exit(1); end
exit(0);
