project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'tools'));
failure_folder = fullfile(project_root, 'audit', 'direct-62-trials');
if ~isfolder(failure_folder), mkdir(failure_folder); end
failure_path = fullfile(failure_folder, 'five-trial-failure.txt');
if isfile(failure_path), delete(failure_path); end
try
    run_five_direct_62_trials();
    exit(0);
catch trial_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, '%s\n', getReport(trial_error, ...
            'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
