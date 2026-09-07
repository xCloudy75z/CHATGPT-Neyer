project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestPreTestPlanner.m')));
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-input-red-test.txt');
file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not create planner red-test evidence.');
cleanup_file = onCleanup(@() fclose(file_id));
fprintf(file_id, 'Planner input tests before implementation\n');
fprintf(file_id, 'Passed: %d\n', sum([result.Passed]));
fprintf(file_id, 'Failed: %d\n', sum([result.Failed]));
fprintf(file_id, 'Incomplete: %d\n', sum([result.Incomplete]));
clear cleanup_file;
if any([result.Failed])
    exit(0);
end
exit(1);
