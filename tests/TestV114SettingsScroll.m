classdef TestV114SettingsScroll < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (TestMethodSetup)
        function prepareCapture(~)
            setappdata(groot, 'NeyerV2CaptureDirectInputs', true);
            setappdata(groot, 'V114ScrollObservation', struct());
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
        end
    end

    methods (TestMethodTeardown)
        function cleanCapture(~)
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
            if isappdata(groot, 'NeyerV2CaptureDirectInputs')
                rmappdata(groot, 'NeyerV2CaptureDirectInputs');
            end
            if isappdata(groot, 'V114ScrollObservation')
                rmappdata(groot, 'V114ScrollObservation');
            end
        end
    end

    methods (Test)
        function lowerSettingsAndButtonsAreReachableByScrolling(testCase)
            watcher = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.20, 'BusyMode', 'drop', ...
                'TimerFcn', @observeSettings);
            cleanup = onCleanup(@() stopTimer(watcher)); %#ok<NASGU>
            start(watcher);

            result = run_test_ui([], []);
            testCase.verifyEmpty(result);
            observation = getappdata(groot, 'V114ScrollObservation');
            testCase.assertNotEmpty(fieldnames(observation), ...
                'The settings window was not observed.');
            testCase.verifyEmpty(observation.error);
            testCase.verifyTrue(observation.scrollable);
            testCase.verifyLessThanOrEqual(observation.height, 680);
            testCase.verifyTrue(observation.startButtonFound);
            testCase.verifyTrue(observation.cancelButtonFound);
            testCase.verifyTrue(observation.scrolledToBottom);
        end
    end
end

function observeSettings(watcher, ~)
figures = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer gap test - inputs');
if isempty(figures), return; end
figureHandle = figures(1);
cancelButtons = findall(figureHandle, 'Type', 'uibutton', 'Text', 'Cancel');
if isempty(cancelButtons), return; end
stop(watcher);
observation = struct('error', '', 'scrollable', false, 'height', Inf, ...
    'startButtonFound', false, 'cancelButtonFound', false, ...
    'scrolledToBottom', false);
try
    scrollLayout = findall(figureHandle, ...
        'Tag', 'direct_input_scroll_layout');
    startButtons = findall(figureHandle, 'Type', 'uibutton', ...
        'Text', 'Start test');
    assert(numel(scrollLayout) == 1, ...
        'Expected one identifiable main settings layout.');
    observation.scrollable = strcmp(scrollLayout.Scrollable, 'on');
    observation.height = figureHandle.Position(4);
    observation.startButtonFound = numel(startButtons) == 1;
    observation.cancelButtonFound = numel(cancelButtons) == 1;
    scroll(scrollLayout, 'bottom');
    drawnow;
    observation.scrolledToBottom = true;
catch problem
    observation.error = getReport(problem, 'basic', 'hyperlinks', 'off');
end
setappdata(groot, 'V114ScrollObservation', observation);
feval(cancelButtons(1).ButtonPushedFcn, cancelButtons(1), []);
end

function stopTimer(watcher)
if isvalid(watcher)
    if strcmp(watcher.Running, 'on'), stop(watcher); end
    delete(watcher);
end
end
