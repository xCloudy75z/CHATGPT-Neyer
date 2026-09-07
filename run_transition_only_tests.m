root = fileparts(mfilename('fullpath'));
results = run(testsuite(fullfile(root, 'tests', 'TestTransitionOnly.m')));
disp(table(results));
assertSuccess(results);
