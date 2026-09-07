project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'simulation'));
config_path = fullfile(project_root, 'simulation', ...
    'planner-validation-config.json');
shard_files = arrayfun(@(index) fullfile(project_root, 'simulation', ...
    sprintf('planner-validation-shard-%d.csv', index)), 1:4, ...
    'UniformOutput', false);
summary_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-validation-summary.csv');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-validation-merge.txt');
try
    summary = merge_planner_validation(config_path, shard_files, summary_path);
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'Planner validation merge complete\n');
    fprintf(file_id, 'Scenarios: %d\n', height(summary));
    fprintf(file_id, 'Accepted: %d\n', sum(summary.conclusion == "accepted"));
    fprintf(file_id, 'Not accepted: %d\n', ...
        sum(summary.conclusion == "not accepted"));
    fprintf(file_id, 'Withheld: %d\n', sum(summary.conclusion == "withheld"));
    fclose(file_id);
catch merge_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'MERGE ERROR\n%s\n', ...
        getReport(merge_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
exit(0);
