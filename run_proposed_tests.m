root = fileparts(mfilename('fullpath'));
suite = testsuite(fullfile(root, 'tests', 'TestProposedNeyer.m'));
results = run(suite);
disp(table(results));
assertSuccess(results);
