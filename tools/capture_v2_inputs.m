project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
output_folder = fullfile(v2_audit_folder(project_root), 'ui');
output_path = fullfile(output_folder, '02-direct-inputs.png');
if ~isfolder(output_folder)
    mkdir(output_folder);
end
delete(findall(groot, 'Type', 'figure', 'Name', 'Neyer gap test - inputs'));
setappdata(groot, 'NeyerV2CaptureDirectInputs', true);
setappdata(groot, 'NeyerV2CaptureDirectInputsError', '');
capture_timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.20, ...
    'BusyMode', 'drop', ...
    'TimerFcn', @(timerObject, eventData) capture_and_close( ...
        timerObject, eventData, output_path));
cleanup = onCleanup(@() finish_capture(capture_timer));
start(capture_timer);
run_test_ui([], []);
drawnow;
capture_error = getappdata(groot, 'NeyerV2CaptureDirectInputsError');
assert(isempty(capture_error), capture_error);
assert(isfile(output_path), 'The direct-input audit image was not created.');

function capture_and_close(timer_object, ~, output_path)
    figures = findall(groot, 'Type', 'figure', ...
        'Name', 'Neyer gap test - inputs');
    if isempty(figures)
        return;
    end
    figure_handle = figures(1);
    cancel_buttons = findall(figure_handle, 'Type', 'uibutton', ...
        'Text', 'Cancel');
    if isempty(cancel_buttons)
        return;
    end
    stop(timer_object);
    try
        drawnow;
        exportapp(figure_handle, output_path);
        mode = findall(figure_handle, 'Tag', 'physical_mode');
        mode.Value = 'Confirmed gap list';
        feval(mode.ValueChangedFcn, mode, []);
        list = findall(figure_handle, 'Tag', 'confirmed_gaps');
        list.Value = '1.00, 1.10, 2.50';
        pause(0.5); drawnow;
        exportapp(figure_handle, fullfile(fileparts(output_path), ...
            '02-direct-inputs-confirmed-list.png'));
    catch capture_error
        setappdata(groot, 'NeyerV2CaptureDirectInputsError', ...
            getReport(capture_error, 'basic', 'hyperlinks', 'off'));
    end
    feval(cancel_buttons(1).ButtonPushedFcn, cancel_buttons(1), []);
end

function finish_capture(timer_object)
    if isvalid(timer_object)
        if strcmp(timer_object.Running, 'on')
            stop(timer_object);
        end
        delete(timer_object);
    end
    if isappdata(groot, 'NeyerV2CaptureDirectInputs')
        rmappdata(groot, 'NeyerV2CaptureDirectInputs');
    end
    if isappdata(groot, 'NeyerV2CaptureDirectInputsError')
        rmappdata(groot, 'NeyerV2CaptureDirectInputsError');
    end
end
