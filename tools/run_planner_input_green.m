project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestPreTestPlanner.m')));
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-input-green-test.txt');
file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not create planner test evidence.');
cleanup_file = onCleanup(@() fclose(file_id));
fprintf(file_id, 'Planner input tests after implementation\n');
fprintf(file_id, 'Passed: %d\n', sum([result.Passed]));
fprintf(file_id, 'Failed: %d\n', sum([result.Failed]));
fprintf(file_id, 'Incomplete: %d\n', sum([result.Incomplete]));
for result_number = 1:numel(result)
    if ~result(result_number).Passed
        fprintf(file_id, 'NOT PASSED: %s\n', result(result_number).Name);
        details = result(result_number).Details;
        if isfield(details, 'DiagnosticRecord') && ~isempty(details.DiagnosticRecord)
            for record_number = 1:numel(details.DiagnosticRecord)
                report_text = details.DiagnosticRecord(record_number).Report;
                fprintf(file_id, '%s\n', report_text);
            end
        end
    end
end
clear cleanup_file;
if all([result.Passed])
    exit(0);
end
exit(1);
