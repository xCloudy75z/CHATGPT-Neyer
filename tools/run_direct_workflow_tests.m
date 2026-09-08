project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));

results = runtests({ ...
    fullfile(project_root, 'tests', 'TestPhysicalUiInputs.m'), ...
    fullfile(project_root, 'tests', 'TestGapPresentation.m'), ...
    fullfile(project_root, 'tests', 'TestDirectRunSafety.m'), ...
    fullfile(project_root, 'tests', 'TestPlannerUiSource.m')});

summary_text = evalc('disp(table(results))');
disp(summary_text);

audit_folder = fullfile(project_root, 'audit', 'direct-run');
if ~exist(audit_folder, 'dir')
    mkdir(audit_folder);
end
summary_file = fullfile(audit_folder, 'targeted-test-results.txt');
file_id = fopen(summary_file, 'w');
if file_id >= 0
    fprintf(file_id, '%s', summary_text);
    fclose(file_id);
end

assertSuccess(results);
