root = fileparts(mfilename('fullpath'));
results = run(testsuite(fullfile(root, 'tests', 'TestStage1Only.m')));
disp(table(results));
assertSuccess(results);
