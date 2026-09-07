project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestPlannerUiSource.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-ui-red-test.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create planner UI red evidence.');
fprintf(file_id, 'Planner UI source tests before implementation\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fclose(file_id);
if any([result.Failed]), exit(0); end
exit(1);
