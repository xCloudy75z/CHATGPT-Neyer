function capture_v113_audit_screens()
%CAPTURE_V113_AUDIT_SCREENS Save the six main V1.13 screens for visual review.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
addpath(fullfile(projectRoot, 'tools'));
outputFolder = fullfile(projectRoot, 'audit', 'v113-complete', 'ui');
if ~isfolder(outputFolder), mkdir(outputFolder); end
delete(findall(groot, 'Type', 'figure'));

neyer_app();
drawnow;
menuFigure = require_one_figure('Neyer Gap Test');
exportapp(menuFigure, fullfile(outputFolder, '01-main-menu.png'));
delete(menuFigure);

capture_input_and_test_windows(outputFolder);

demo = run_demo();
fittedFigure = show_result(demo.result);
drawnow;
exportapp(fittedFigure, fullfile(outputFolder, '04-fitted-result.png'));
delete(fittedFigure);

unfinishedFigure = show_result(unfinished_result());
drawnow;
exportapp(unfinishedFigure, fullfile(outputFolder, '05-unfinished-result.png'));
delete(unfinishedFigure);

show_manual();
drawnow;
helpFigure = require_one_figure('Neyer Gap Test - Help');
exportapp(helpFigure, fullfile(outputFolder, '06-help.png'));
delete(helpFigure);

capture_planner_window(outputFolder);

markerPath = fullfile(projectRoot, 'audit', 'v113-complete', ...
    'ui-capture-complete.txt');
fileId = fopen(markerPath, 'w');
assert(fileId >= 0, 'Could not write the UI capture marker.');
fprintf(fileId, 'Seven V1.13 screens captured in MATLAB %s.\n', ...
    version('-release'));
fclose(fileId);
fprintf('V1.13 UI CAPTURE: seven screens saved.\n');
end

function capture_planner_window(outputFolder)
setappdata(groot, 'v113PlannerCaptured', false);
captureTimer = timer('StartDelay', 0.5, 'ExecutionMode', 'fixedSpacing', ...
    'Period', 0.5, 'TasksToExecute', 30, ...
    'TimerFcn', @(~, ~) capture_and_close_planner(outputFolder));
timerCleanup = onCleanup(@() stop_and_delete_timer(captureTimer)); %#ok<NASGU>
start(captureTimer);
pretest_planner_ui();
assert(getappdata(groot, 'v113PlannerCaptured'), ...
    'The Pre-Test Planner screen was not captured.');
end

function capture_and_close_planner(outputFolder)
plannerFigure = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer Pre-Test Planner');
if numel(plannerFigure) == 1
    exportapp(plannerFigure, fullfile(outputFolder, ...
        '07-pre-test-planner.png'));
    setappdata(groot, 'v113PlannerCaptured', true);
    buttons = findall(plannerFigure, 'Type', 'uibutton');
    closeButton = buttons(string({buttons.Text}) == "Close");
    assert(numel(closeButton) == 1, ...
        'The Pre-Test Planner Close button was not found.');
    feval(closeButton.ButtonPushedFcn, closeButton, []);
end
end

function capture_input_and_test_windows(outputFolder)
state = struct('inputCaptured', false, 'testCaptured', false, 'error', '');
setappdata(groot, 'v113AuditCaptureState', state);
captureTimer = timer('StartDelay', 0.5, 'ExecutionMode', 'fixedSpacing', ...
    'Period', 0.5, 'TasksToExecute', 40, ...
    'TimerFcn', @(~, ~) capture_visible_step(outputFolder));
timerCleanup = onCleanup(@() stop_and_delete_timer(captureTimer)); %#ok<NASGU>
start(captureTimer);
run_test_ui([], []);
drawnow;
state = getappdata(groot, 'v113AuditCaptureState');
assert(isempty(state.error), state.error);
assert(state.inputCaptured, 'The direct-run input screen was not captured.');
assert(state.testCaptured, 'The per-test entry screen was not captured.');
end

function capture_visible_step(outputFolder)
state = getappdata(groot, 'v113AuditCaptureState');
try
    if ~state.inputCaptured
        inputFigure = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test - inputs');
        if numel(inputFigure) == 1
            exportapp(inputFigure, fullfile(outputFolder, ...
                '02-direct-run-inputs.png'));
            buttons = findall(inputFigure, 'Type', 'uibutton');
            startButton = buttons(string({buttons.Text}) == "Start test");
            assert(numel(startButton) == 1, ...
                'The Start test button could not be found.');
            state.inputCaptured = true;
            setappdata(groot, 'v113AuditCaptureState', state);
            feval(startButton.ButtonPushedFcn, startButton, []);
            return;
        end
    end
    if state.inputCaptured && ~state.testCaptured
        testFigure = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test');
        if numel(testFigure) == 1
            exportapp(testFigure, fullfile(outputFolder, ...
                '03-test-entry.png'));
            state.testCaptured = true;
            setappdata(groot, 'v113AuditCaptureState', state);
            delete(testFigure);
        end
    end
catch problem
    state.error = problem.message;
    setappdata(groot, 'v113AuditCaptureState', state);
    delete(findall(groot, 'Type', 'figure'));
end
end

function figureHandle = require_one_figure(name)
figureHandle = findall(groot, 'Type', 'figure', 'Name', name);
assert(numel(figureHandle) == 1, 'Expected one window named "%s".', name);
end

function result = unfinished_result()
result = struct( ...
    'has_overlap', false, 'status', 'complete', 'stop_reason', '', ...
    'n', 3, 'unit', 'mm', 'levels', [5.50; 3.30; 1.10], ...
    'successes', logical([0; 0; 1]), ...
    'requested_levels', [5.50; 3.30; 1.10], ...
    'measurements', {{5.50, 3.30, 1.10}}, ...
    'mu', NaN, 'mu_lo', NaN, 'mu_hi', NaN, ...
    'sigma', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
    'confidence_level', 0.95, 'tail_fraction', 0.999);
end

function stop_and_delete_timer(timerObject)
if isvalid(timerObject)
    stop(timerObject);
    delete(timerObject);
end
end
