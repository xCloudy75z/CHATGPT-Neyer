project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestStudyPlanStorage.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'plan-storage-red-test.txt');
file_id = fopen(output_path, 'w');
assert(file_id >= 0, 'Could not create storage red evidence.');
fprintf(file_id, 'Study-plan storage tests before implementation\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fclose(file_id);
if any([result.Failed]), exit(0); end
exit(1);
