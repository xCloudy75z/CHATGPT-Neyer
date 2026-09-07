project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);

evidence_folder = fullfile(project_root, 'audit', 'overnight');
if ~isfolder(evidence_folder)
    mkdir(evidence_folder);
end

started_at = datetime('now', 'TimeZone', 'local');
test_results = runtests(fullfile(project_root, 'tests'));
finished_at = datetime('now', 'TimeZone', 'local');

summary_path = fullfile(evidence_folder, 'baseline-test-summary.txt');
file_id = fopen(summary_path, 'w');
assert(file_id >= 0, 'Could not create the baseline evidence file.');
cleanup_file = onCleanup(@() fclose(file_id));
fprintf(file_id, 'Neyer V1.9 baseline before overnight changes\n');
fprintf(file_id, 'MATLAB: %s\n', version);
fprintf(file_id, 'Started: %s\n', char(started_at, 'yyyy-MM-dd HH:mm:ss Z'));
fprintf(file_id, 'Finished: %s\n', char(finished_at, 'yyyy-MM-dd HH:mm:ss Z'));
fprintf(file_id, 'Passed: %d\n', sum([test_results.Passed]));
fprintf(file_id, 'Failed: %d\n', sum([test_results.Failed]));
fprintf(file_id, 'Incomplete: %d\n', sum([test_results.Incomplete]));
clear cleanup_file;

disp(test_results);
fprintf('\nBASELINE: %d passed, %d failed, %d incomplete.\n', ...
    sum([test_results.Passed]), sum([test_results.Failed]), ...
    sum([test_results.Incomplete]));

if all([test_results.Passed])
    exit(0);
end
exit(1);
