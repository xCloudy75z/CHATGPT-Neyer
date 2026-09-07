function capture_v110_result_ui()
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
image_path = fullfile(project_root, 'assets', 'screenshots', ...
    'v110-02-results.png');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'result-ui-launch.txt');

demo = run_demo();
result = demo.result;
plan = struct( ...
    'outcome', 'interaction', 'reliability', 0.90, 'confidence', 0.95, ...
    'accuracy_mm', 10, 'minimum_gap_mm', 0, 'maximum_gap_mm', 10, ...
    'main_articles', 20, 'reserve_1_articles', 0, 'reserve_2_articles', 0, ...
    'reachable_model', reachable_gap_model( ...
        struct('mode', 'regular', 'increment_mm', 0.10), 0, 10));
result.study_plan = plan;
result.checkpoint_decision = struct('status', 'complete');

try
    result_figure = show_result(result);
    drawnow;
    pause(4);
    exportapp(result_figure, image_path);
    delete(result_figure);
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, ...
        'Result UI opened, rendered, and was captured in MATLAB %s.\n', version);
    fclose(file_id);
catch ui_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'RESULT UI ERROR\n%s\n', ...
        getReport(ui_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
exit(0);
end
