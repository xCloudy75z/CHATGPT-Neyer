project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestPreTestPlanner.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'plan-summary-green-test.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create plan-summary evidence.');
fprintf(file_id, 'Plan summary tests after implementation\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fclose(file_id);
if all([result.Passed]), exit(0); end
exit(1);
