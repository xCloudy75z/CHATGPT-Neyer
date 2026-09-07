root = fileparts(mfilename('fullpath'));
suite = [testsuite(fullfile(root, 'tests', 'TestReferenceTable.m')); ...
         testsuite(fullfile(root, 'tests', 'TestBaselineCharacterization.m'))];
results = run(suite);
disp(table(results));
assertSuccess(results);
