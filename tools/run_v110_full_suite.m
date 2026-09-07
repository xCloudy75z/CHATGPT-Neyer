project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
start_time = tic;
result = run(testsuite(fullfile(project_root, 'tests')));
elapsed_seconds = toc(start_time);
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'final-full-suite.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create the final full-suite evidence.');
fprintf(file_id, 'Neyer v1.10 final full MATLAB test suite\n');
fprintf(file_id, 'MATLAB release: %s\n', version('-release'));
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fprintf(file_id, 'Elapsed seconds: %.3f\n', elapsed_seconds);
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
if any([result.Failed]) || any([result.Incomplete])
    exit(1);
end
exit(0);
