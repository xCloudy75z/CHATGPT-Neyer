project_root = fileparts(fileparts(mfilename('fullpath')));
failure_path = fullfile(project_root, 'audit', 'direct-run', ...
    'direct-ui-smoke-failure.txt');
try
    run(fullfile(project_root, 'tools', 'verify_direct_ui_v110.m'));
    exit(0);
catch verification_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'DIRECT UI CHECK ERROR\n%s\n', ...
            getReport(verification_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
