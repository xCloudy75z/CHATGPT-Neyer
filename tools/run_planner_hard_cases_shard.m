function run_planner_hard_cases_shard(shard_index, shard_count)
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
addpath(fullfile(project_root, 'simulation'));
config_path = fullfile(project_root, 'simulation', ...
    'planner-hard-cases-config.json');
output_path = fullfile(project_root, 'simulation', sprintf( ...
    'planner-hard-cases-shard-%d.csv', shard_index));
evidence_path = fullfile(project_root, 'audit', 'overnight', sprintf( ...
    'planner-hard-cases-shard-%d-complete.txt', shard_index));
start_time = tic;
try
    rows = run_planner_validation_shard(config_path, shard_index, ...
        shard_count, output_path);
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'Hard-case calibration shard %d of %d complete\n', ...
        shard_index, shard_count);
    fprintf(file_id, 'Rows: %d\nElapsed seconds: %.3f\n', ...
        height(rows), toc(start_time));
    fprintf(file_id, 'Simulated rows: %d\n', ...
        sum(rows.run_status == "simulated"));
    fprintf(file_id, 'Rows with errors: %d\n', ...
        sum(rows.run_status == "simulation_error"));
    fclose(file_id);
catch shard_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'SHARD ERROR\n%s\n', ...
        getReport(shard_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
end
