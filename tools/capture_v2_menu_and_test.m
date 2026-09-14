%CAPTURE_V2_MENU_AND_TEST Save the V2 menu and one real test request.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
output_folder = fullfile(v2_audit_folder(project_root), 'ui');
if ~isfolder(output_folder), mkdir(output_folder); end
menu_path = fullfile(output_folder, '01-main-menu.png');
test_path = fullfile(output_folder, '03-test-request.png');

delete(findall(groot, 'Type', 'figure'));
neyer_app;
drawnow;
menu = find_named_figure('Neyer Gap Test V2');
exportapp(menu, menu_path);
delete(menu);

setappdata(groot, 'NeyerV2CaptureDirectInputs', true);
setappdata(groot, 'NeyerV2MenuAndTestCaptureState', 'settings');
capture_timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.20, ...
    'BusyMode', 'drop', 'TimerFcn', @(timer_object, event_data) ...
        capture_test_request(timer_object, event_data, test_path));
cleanup = onCleanup(@() finish_capture(capture_timer)); %#ok<NASGU>
start(capture_timer);
run_test_ui([], []);
drawnow;
assert(isfile(menu_path), 'The V2 main-menu image was not created.');
assert(isfile(test_path), 'The V2 test-request image was not created.');

function capture_test_request(capture_timer, ~, test_path)
    capture_state = getappdata(groot, 'NeyerV2MenuAndTestCaptureState');
    if strcmp(capture_state, 'settings')
        settings = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test - inputs');
        if isempty(settings), return; end
        start_button = findall(settings(1), 'Type', 'uibutton', ...
            'Text', 'Start test');
        if isempty(start_button), return; end
        configure_regular_settings(settings(1));
        setappdata(groot, 'NeyerV2MenuAndTestCaptureState', 'request');
        return;
    end

    test_window = findall(groot, 'Type', 'figure', ...
        'Name', 'Neyer gap test');
    if isempty(test_window), return; end
    labels = findall(test_window(1), 'Type', 'uilabel');
    labels = labels(arrayfun(@(label) isprop(label, 'Text'), labels));
    if isempty(labels), return; end
    label_text = string({labels.Text});
    if ~any(contains(label_text, 'Build the requested gap:')) || ...
            ~any(contains(label_text, 'Measure this new setup once.'))
        return;
    end
    drawnow;
    exportapp(test_window(1), test_path);
    feval(test_window(1).CloseRequestFcn, test_window(1), []);
    stop(capture_timer);
end

function configure_regular_settings(fig)
set_field(fig, 'low_guess', '0');
set_field(fig, 'high_guess', '10');
set_field(fig, 'variation_guess', '1');
set_field(fig, 'maximum_tests', '3');
set_field(fig, 'minimum_gap', '0');
set_field(fig, 'maximum_gap', '10');
set_field(fig, 'unit', 'mm');
set_field(fig, 'regular_step', '0.05');
set_field(fig, 'foil_thickness', '0.015');
button = findall(fig, 'Type', 'uibutton', 'Text', 'Start test');
feval(button(1).ButtonPushedFcn, button(1), []);
end

function set_field(fig, tag, value)
field = findall(fig, 'Tag', tag);
assert(numel(field) == 1, 'The %s input is missing.', tag);
field.Value = value;
end

function fig = find_named_figure(name)
fig = findall(groot, 'Type', 'figure', 'Name', name);
assert(~isempty(fig), 'Screen did not open: %s', name);
fig = fig(1);
end

function finish_capture(capture_timer)
if isvalid(capture_timer)
    if strcmp(capture_timer.Running, 'on'), stop(capture_timer); end
    delete(capture_timer);
end
if isappdata(groot, 'NeyerV2CaptureDirectInputs')
    rmappdata(groot, 'NeyerV2CaptureDirectInputs');
end
if isappdata(groot, 'NeyerV2MenuAndTestCaptureState')
    rmappdata(groot, 'NeyerV2MenuAndTestCaptureState');
end
end
