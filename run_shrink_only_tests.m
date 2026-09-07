root = fileparts(mfilename('fullpath'));
results = run(testsuite(fullfile(root, 'tests', 'TestShrinkOnly.m')));
disp(table(results));
assertSuccess(results);
