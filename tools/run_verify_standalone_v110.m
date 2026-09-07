project_root = fileparts(fileparts(mfilename('fullpath')));
failure_path = fullfile(project_root, 'audit', 'overnight', ...
    'standalone-clean-start-failure.txt');
try
    run(fullfile(project_root, 'tools', 'verify_standalone_v110.m'));
catch verification_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'STANDALONE CLEAN-START ERROR\n%s\n', ...
            getReport(verification_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
