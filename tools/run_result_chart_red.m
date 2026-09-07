project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
result = run(testsuite(fullfile(project_root, 'tests', 'TestResultDecision.m')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'result-chart-language-red-test.txt');
file_id = fopen(output_path, 'w');
fprintf(file_id, 'Result chart wording before correction\n');
fprintf(file_id, 'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([result.Passed]), sum([result.Failed]), sum([result.Incomplete]));
fclose(file_id);
exit(0);
