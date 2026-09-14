classdef TestV2OperatorWording < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'application', 'source')));
        end
    end

    methods (TestMethodSetup)
        function closeOperatorWindowsBefore(~)
            setappdata(groot, 'NeyerV2CaptureDirectInputs', true);
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer Gap Test V2'));
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test'));
        end
    end

    methods (TestMethodTeardown)
        function closeOperatorWindowsAfter(~)
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer Gap Test V2'));
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test'));
            if isappdata(groot, 'NeyerV2CaptureDirectInputs')
                rmappdata(groot, 'NeyerV2CaptureDirectInputs');
            end
        end
    end

    methods (Test)
        function mainMenuUsesV2IdentityAndWrappedGuide(testCase)
            neyer_app;
            drawnow;
            menu = findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer Gap Test V2');
            testCase.assertNumElements(menu, 1);
            labels = findall(menu, 'Type', 'uilabel');
            text = string({labels.Text});
            title = labels(text == "Neyer Gap Test V2");
            guide = labels(contains(text, "Run a test directly"));

            testCase.assertNumElements(title, 1);
            testCase.assertNumElements(guide, 1);
            testCase.verifyEqual(string(guide.WordWrap), "on");
        end

        function requestedGapUsesApprovedBuildPrefix(testCase)
            testCase.verifyEqual(format_requested_gap(5, 'mm'), ...
                'Build the requested gap: 5.00 mm');
        end

        function regularAndListPromptsKeepOneBuildInstruction(testCase)
            regular = capture_test_prompt('Regular gap step');
            testCase.verifyEqual(regular.request, ...
                'Build the requested gap: 5.00 mm');
            testCase.verifyEqual(count(regular.request, ...
                'Build the requested gap:'), 1);
            testCase.verifySubstring(regular.measurementNote, ...
                'Measure this new setup once.');

            listed = capture_test_prompt('Confirmed gap list');
            testCase.verifyEqual(count(listed.request, ...
                'Build the requested gap:'), 1);
            testCase.verifySubstring(listed.request, ...
                'confirmed buildable gaps');
            testCase.verifyFalse(contains(listed.request, 'Set the gap'));
            testCase.verifySubstring(listed.measurementNote, ...
                'Measure this new setup once.');
        end
    end
end

function observation = capture_test_prompt(mode)
observation = struct('request', '', 'measurementNote', '');
stage = 'settings';
watcher = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.20, ...
    'BusyMode', 'drop', 'TimerFcn', @observe_prompt);
cleanup = onCleanup(@() stop_and_delete_timer(watcher)); %#ok<NASGU>
start(watcher);
result = run_test_ui([], []);
assert(isempty(result), 'The prompt observation should cancel the test.');
assert(~isempty(observation.request), 'The test prompt was not observed.');

    function observe_prompt(~, ~)
        if strcmp(stage, 'settings')
            settings = findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs');
            if isempty(settings), return; end
            startButton = findall(settings(1), 'Type', 'uibutton', ...
                'Text', 'Start test');
            if isempty(startButton), return; end
            configure_settings(settings(1), mode);
            stage = 'prompt';
            return;
        end

        prompt = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test');
        if isempty(prompt), return; end
        labels = findall(prompt(1), 'Type', 'uilabel');
        labels = labels(arrayfun(@(label) isprop(label, 'Text'), labels));
        if isempty(labels), return; end
        labelText = string({labels.Text});
        request = labelText(contains(labelText, 'Build the requested gap:'));
        note = labelText(contains(labelText, 'Measure this new setup once.'));
        if isempty(request) || isempty(note), return; end
        assert(numel(request) == 1, 'The test prompt has no unique build instruction.');
        assert(numel(note) == 1, 'The one-reading explanation is missing.');
        observation.request = char(request);
        observation.measurementNote = char(note);
        feval(prompt(1).CloseRequestFcn, prompt(1), []);
        stop(watcher);
    end
end

function configure_settings(fig, mode)
set_field(fig, 'low_guess', '0');
set_field(fig, 'high_guess', '10');
set_field(fig, 'variation_guess', '1');
set_field(fig, 'maximum_tests', '3');
set_field(fig, 'minimum_gap', '0');
set_field(fig, 'maximum_gap', '10');
set_field(fig, 'unit', 'mm');
set_field(fig, 'regular_step', '0.05');
set_field(fig, 'confirmed_gaps', '1.00, 5.00, 9.00');
set_field(fig, 'foil_thickness', '0.015');
dropdown = findall(fig, 'Type', 'uidropdown', 'Tag', 'physical_mode');
assert(numel(dropdown) == 1, 'The physical-method selector is missing.');
dropdown.Value = mode;
feval(dropdown.ValueChangedFcn, dropdown, []);
button = findall(fig, 'Type', 'uibutton', 'Text', 'Start test');
assert(numel(button) == 1, 'The Start test button is missing.');
feval(button.ButtonPushedFcn, button, []);
end

function set_field(fig, tag, value)
field = findall(fig, 'Tag', tag);
assert(numel(field) == 1, 'The %s input is missing.', tag);
field.Value = value;
end

function stop_and_delete_timer(watcher)
if isvalid(watcher)
    if strcmp(watcher.Running, 'on'), stop(watcher); end
    delete(watcher);
end
end
