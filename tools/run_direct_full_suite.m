project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
start_time = tic;
results = run(testsuite(fullfile(project_root, 'tests')));
elapsed_seconds = toc(start_time);

summary_text = sprintf([ ...
    'Neyer direct-workflow full MATLAB test suite\n' ...
    'MATLAB release: %s\nPassed: %d\nFailed: %d\nIncomplete: %d\n' ...
    'Elapsed seconds: %.3f\n'], ...
    version('-release'), sum([results.Passed]), sum([results.Failed]), ...
    sum([results.Incomplete]), elapsed_seconds);
disp(summary_text);

output_path = fullfile(project_root, 'audit', 'direct-run', ...
    'full-suite-results.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create the full-suite evidence.');
fprintf(file_id, '%s', summary_text);
for result_index = 1:numel(results)
    if results(result_index).Failed
        fprintf(file_id, '\nFAILED: %s\n', results(result_index).Name);
        records = results(result_index).Details.DiagnosticRecord;
        for record_index = 1:numel(records)
            fprintf(file_id, '%s\n', records(record_index).Report);
        end
    end
end
fclose(file_id);
assertSuccess(results);
