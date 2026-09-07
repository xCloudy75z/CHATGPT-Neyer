project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'fixed-gap-green-test.txt');

try
    suite = [testsuite(fullfile(project_root, 'tests', ...
        'TestFixedGapConfidence.m')), testsuite(fullfile(project_root, ...
        'tests', 'TestGapReliability.m'))];
    test_result = run(suite);

    file_id = fopen(evidence_path, 'w');
    assert(file_id >= 0, 'Could not create corrected-test evidence.');
    cleanup_file = onCleanup(@() fclose(file_id));
    fprintf(file_id, 'Fixed-gap correction focused tests\n');
    fprintf(file_id, 'MATLAB: %s\n', version);
    fprintf(file_id, 'Passed: %d\n', sum([test_result.Passed]));
    fprintf(file_id, 'Failed: %d\n', sum([test_result.Failed]));
    fprintf(file_id, 'Incomplete: %d\n', sum([test_result.Incomplete]));
    clear cleanup_file;

    if all([test_result.Passed])
        exit(0);
    end
    exit(1);
catch runner_error
    file_id = fopen(evidence_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'RUNNER ERROR\n%s\n', ...
            getReport(runner_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(2);
end
