project_root = fileparts(fileparts(mfilename('fullpath')));
failure_path = fullfile(project_root, 'audit', 'overnight', ...
    'final-full-suite-launch-failure.txt');
try
    run(fullfile(project_root, 'tools', 'run_v110_full_suite.m'));
catch suite_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'FULL SUITE LAUNCH ERROR\n%s\n', ...
            getReport(suite_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
