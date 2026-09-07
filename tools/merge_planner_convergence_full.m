project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'simulation'));
config_path = fullfile(project_root, 'simulation', ...
    'planner-convergence-config.json');
shard_files = arrayfun(@(index) fullfile(project_root, 'simulation', ...
    sprintf('planner-convergence-shard-%d.csv', index)), 1:4, ...
    'UniformOutput', false);
summary_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-convergence-summary.csv');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-convergence-merge.txt');
try
    summary = merge_planner_validation(config_path, shard_files, summary_path);
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'Planner convergence merge complete\n');
    fprintf(file_id, 'Scenarios: %d\n', height(summary));
    fprintf(file_id, 'Accepted: %d\n', sum(summary.conclusion == "accepted"));
    fclose(file_id);
catch merge_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'MERGE ERROR\n%s\n', ...
        getReport(merge_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
exit(0);
