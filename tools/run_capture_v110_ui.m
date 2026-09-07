project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'tools'));
failure_path = fullfile(project_root, 'audit', 'overnight', ...
    'final-ui-capture-failure.txt');
try
    capture_v110_ui();
catch capture_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'FINAL UI CAPTURE ERROR\n%s\n', ...
            getReport(capture_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
