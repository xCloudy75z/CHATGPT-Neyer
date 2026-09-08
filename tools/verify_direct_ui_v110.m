project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
addpath(fullfile(project_root, 'tools'));
setappdata(groot, 'direct_ui_checked', false);
setappdata(groot, 'direct_ui_error', 'The settings window was not checked.');

settings_timer = timer('StartDelay', 0.5, 'ExecutionMode', 'fixedSpacing', ...
    'Period', 0.5, 'TasksToExecute', 30, ...
    'TimerFcn', @verify_direct_ui_callback, ...
    'StopFcn', @verify_direct_ui_timeout_callback);
timer_cleanup = onCleanup(@() stop_and_delete_timer(settings_timer)); %#ok<NASGU>
start(settings_timer);
run_test_ui([], []);
drawnow;
if ~getappdata(groot, 'direct_ui_checked')
    error('verify_direct_ui_v110:settingsWindow', ...
        '%s', getappdata(groot, 'direct_ui_error'));
end

unfinished_result = struct( ...
    'has_overlap', false, 'status', 'complete', 'stop_reason', '', ...
    'n', 3, 'unit', 'mm', 'levels', [5.5; 3.3; 1.1], ...
    'successes', logical([0; 0; 1]), ...
    'requested_levels', [5.5; 3.3; 1.1], ...
    'measurements', {{[5.5 5.5 5.5 5.5], ...
        [3.3 3.3 3.3 3.3], [1.1 1.1 1.1 1.1]}}, ...
    'mu', NaN, 'mu_lo', NaN, 'mu_hi', NaN, ...
    'sigma', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
    'confidence_level', 0.95, 'tail_fraction', 0.999);
result_figure = show_result(unfinished_result);
result_cleanup = onCleanup(@() delete_if_valid(result_figure)); %#ok<NASGU>
drawnow;

buttons = findall(result_figure, 'Type', 'uibutton');
button_text = string({buttons.Text});
save_button = buttons(button_text == "Save results...");
calculate_button = buttons(button_text == "Calculate");
assert(numel(save_button) == 1 && strcmp(save_button.Enable, 'on'), ...
    'An unfinished study must allow its completed data to be saved.');
assert(numel(calculate_button) == 1 && strcmp(calculate_button.Enable, 'off'), ...
    'Probability calculation must remain disabled before a fit exists.');
labels = findall(result_figure, 'Type', 'uilabel');
visible_text = lower(strjoin(string({labels.Text}), ' | '));
assert(contains(visible_text, 'completed test data can still be saved'), ...
    'The unfinished result screen must explain that completed data can be saved.');
assert(~contains(visible_text, 'nan'), ...
    'The unfinished result screen must not display NaN.');

evidence_path = fullfile(project_root, 'audit', 'direct-run', ...
    'direct-ui-smoke.txt');
file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not record direct-screen evidence.');
fprintf(file_id, 'MATLAB %s direct Run a Test screen check passed.\n', ...
    version('-release'));
fprintf(file_id, 'Nine input boxes were shown, including maximum permitted gap.\n');
fprintf(file_id, 'The screen stated that no Pre-Test Planner was used.\n');
fprintf(file_id, 'No-fit result: Save enabled, Calculate disabled, no NaN shown.\n');
fclose(file_id);

function stop_and_delete_timer(timer_object)
    if isvalid(timer_object)
        stop(timer_object);
        delete(timer_object);
    end
end

function delete_if_valid(figure_handle)
    if isvalid(figure_handle), delete(figure_handle); end
end
