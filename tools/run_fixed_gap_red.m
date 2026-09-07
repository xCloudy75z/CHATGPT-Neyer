project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
test_result = run(testsuite(fullfile(project_root, 'tests', ...
    'TestFixedGapConfidence.m')));
disp(test_result);
fprintf('FIXED-GAP RED CHECK: %d passed, %d failed, %d incomplete.\n', ...
    sum([test_result.Passed]), sum([test_result.Failed]), ...
    sum([test_result.Incomplete]));
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'fixed-gap-red-test.txt');
file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not create red-test evidence.');
cleanup_file = onCleanup(@() fclose(file_id));
fprintf(file_id, 'Expected failing regression test before correction\n');
fprintf(file_id, 'Passed: %d\n', sum([test_result.Passed]));
fprintf(file_id, 'Failed: %d\n', sum([test_result.Failed]));
fprintf(file_id, 'Incomplete: %d\n', sum([test_result.Incomplete]));
for result_number = 1:numel(test_result)
    if test_result(result_number).Failed
        fprintf(file_id, 'EXPECTED FAILURE: %s\n', test_result(result_number).Name);
    end
end
clear cleanup_file;
if any([test_result.Failed])
    exit(0);
end
exit(1);
