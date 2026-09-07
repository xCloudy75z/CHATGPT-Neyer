project_root = fileparts(fileparts(mfilename('fullpath')));
failure_path = fullfile(project_root, 'audit', 'overnight', ...
    'mock-lab-failure.txt');
try
    run(fullfile(project_root, 'tools', 'run_overnight_mock_lab.m'));
catch mock_error
    file_id = fopen(failure_path, 'w');
    if file_id >= 0
        fprintf(file_id, 'MOCK LAB ERROR\n%s\n', ...
            getReport(mock_error, 'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(1);
end
