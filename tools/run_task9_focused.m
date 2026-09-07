project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'task9-focused-tests.txt');
try
    result = runtests(fullfile(project_root, 'tests'));
    file_id = fopen(output_path, 'w');
    assert(file_id >= 0, 'Could not create focused test evidence.');
    fprintf(file_id, 'Complete integration regression suite after planner UI\n');
    fprintf(file_id, 'MATLAB: %s\n', version);
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
catch runner_error
    file_id = fopen(output_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'RUNNER ERROR\n%s\n', ...
            getReport(runner_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(2);
end
