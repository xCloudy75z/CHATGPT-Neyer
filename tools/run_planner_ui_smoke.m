project_root = fileparts(fileparts(mfilename('fullpath')));
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-ui-outer-error.txt');
try
    smoke_pretest_planner_ui();
catch outer_error
    file_id = fopen(output_path, 'w');
    if file_id >= 0
        fprintf(file_id, '%s\n', getReport(outer_error, ...
            'extended', 'hyperlinks', 'off'));
        fclose(file_id);
    end
    exit(2);
end
