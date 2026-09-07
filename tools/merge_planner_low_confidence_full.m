project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'simulation'));
config_path = fullfile(project_root, 'simulation', ...
    'planner-low-confidence-config.json');
shard_files = arrayfun(@(index) fullfile(project_root, 'simulation', ...
    sprintf('planner-low-confidence-shard-%d.csv', index)), 1:4, ...
    'UniformOutput', false);
summary_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-low-confidence-summary.csv');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-low-confidence-merge.txt');
try
    summary = merge_planner_validation(config_path, shard_files, summary_path);
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'Low-confidence merge complete\n');
    fprintf(file_id, 'Scenarios: %d\nAccepted: %d\n', ...
        height(summary), sum(summary.conclusion == "accepted"));
    fclose(file_id);
catch merge_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'MERGE ERROR\n%s\n', ...
        getReport(merge_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
exit(0);
