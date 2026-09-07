root = fileparts(mfilename('fullpath'));
suite = testsuite(fullfile(root, 'tests', 'TestPaperConformance.m'));
results = run(suite);
disp(table(results));
assertSuccess(results);
