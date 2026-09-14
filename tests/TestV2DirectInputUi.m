classdef TestV2DirectInputUi < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (TestMethodSetup)
        function clearUiObservation(~)
            if isappdata(groot, 'V2DirectInputUiObservation')
                rmappdata(groot, 'V2DirectInputUiObservation');
            end
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
        end
    end

    methods (TestMethodTeardown)
        function closeUiAndClearObservation(~)
            delete(findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test - inputs'));
            if isappdata(groot, 'V2DirectInputUiObservation')
                rmappdata(groot, 'V2DirectInputUiObservation');
            end
        end
    end

    methods (Test)
        function sourceExplainsEveryDirectInputInPlainLanguage(testCase)
            source = direct_ui_source();
            requiredText = { ...
                'How can you build the test gaps?', ...
                'Regular gap step', ...
                'Confirmed gap list', ...
                'no more than two decimal places', ...
                'every multiple of this step can genuinely be built', ...
                'rough starting guess, not the final answer', ...
                'The smallest gap the study is allowed to request.', ...
                'The largest useful gap the study is allowed to request.', ...
                'No Pre-Test Planner result is required'};
            for textNumber = 1:numel(requiredText)
                testCase.verifySubstring(source, requiredText{textNumber});
            end

            expectedHelpTags = { ...
                'low_guess_help', 'high_guess_help', ...
                'variation_guess_help', 'maximum_tests_help', ...
                'minimum_gap_help', 'maximum_gap_help', 'unit_help', ...
                'physical_mode_help', 'regular_step_help', ...
                'confirmed_gaps_help', 'foil_thickness_help'};
            for tagNumber = 1:numel(expectedHelpTags)
                testCase.verifySubstring(source, expectedHelpTags{tagNumber});
            end
        end

        function physicalModeShowsOnlyItsUsableEntryAndKeepsValues(testCase)
            testCase.assumeTrue(usejava('desktop'), ...
                'This control-state test requires the MATLAB desktop.');
            watcher = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', 0.20, 'BusyMode', 'drop', ...
                'TimerFcn', @observe_direct_input_window);
            cleanup = onCleanup(@() stop_and_delete_timer(watcher));
            start(watcher);

            result = run_test_ui([], []);

            testCase.verifyEmpty(result, ...
                'Cancelling the independent direct-input window should return empty.');
            testCase.assertTrue(isappdata(groot, ...
                'V2DirectInputUiObservation'), ...
                'The direct-input window was not observed before it closed.');
            observation = getappdata(groot, 'V2DirectInputUiObservation');
            if ~isempty(observation.error)
                testCase.assertFail(observation.error);
            end
            testCase.verifyEqual(observation.modeChoices, ...
                {'Regular gap step', 'Confirmed gap list'});
            testCase.verifyEqual(observation.initialMode, 'Regular gap step');
            testCase.verifyTrue(observation.regularInitiallyVisible);
            testCase.verifyTrue(observation.regularInitiallyEnabled);
            testCase.verifyFalse(observation.listInitiallyVisible);
            testCase.verifyFalse(observation.listInitiallyEnabled);
            testCase.verifyFalse(observation.regularInListModeVisible);
            testCase.verifyFalse(observation.regularInListModeEnabled);
            testCase.verifyTrue(observation.listInListModeVisible);
            testCase.verifyTrue(observation.listInListModeEnabled);
            testCase.verifyEqual(observation.regularValueAfterToggle, '0.10');
            testCase.verifyEqual(observation.listValueAfterToggle, ...
                '1.00, 1.10, 2.50');
            testCase.verifyTrue(observation.regularAfterReturnVisible);
            testCase.verifyTrue(observation.regularAfterReturnEnabled);
            testCase.verifyFalse(observation.listAfterReturnVisible);
            testCase.verifyFalse(observation.listAfterReturnEnabled);
            testCase.verifyTrue(observation.noPlannerRequired);
            testCase.verifyTrue(observation.everyInputHasHelp);
        end

        function captureScriptWritesTheApprovedAuditImage(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            scriptPath = fullfile(projectRoot, 'tools', 'capture_v2_inputs.m');
            testCase.assertTrue(isfile(scriptPath));
            source = fileread(scriptPath);
            testCase.verifySubstring(source, 'audit');
            testCase.verifySubstring(source, 'v2');
            testCase.verifySubstring(source, 'ui');
            testCase.verifySubstring(source, '02-direct-inputs.png');
            testCase.verifySubstring(source, 'exportapp');
            testCase.verifySubstring(source, 'run_test_ui([], [])');
        end
    end
end

function source = direct_ui_source()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    source = fileread(fullfile(projectRoot, 'application', 'source', ...
        'run_test_ui.m'));
end

function observe_direct_input_window(watcher, ~)
    figures = findall(groot, 'Type', 'figure', ...
        'Name', 'Neyer gap test - inputs');
    if isempty(figures)
        return;
    end
    figureHandle = figures(1);
    cancelButtons = findall(figureHandle, 'Type', 'uibutton', 'Text', 'Cancel');
    if isempty(cancelButtons)
        return;
    end
    stop(watcher);
    observation = empty_observation();
    try
        dropdown = findall(figureHandle, 'Type', 'uidropdown', ...
            'Tag', 'physical_mode');
        regularField = findall(figureHandle, 'Type', 'uieditfield', ...
            'Tag', 'regular_step');
        listField = findall(figureHandle, 'Type', 'uieditfield', ...
            'Tag', 'confirmed_gaps');
        assert(numel(dropdown) == 1, 'Physical-method dropdown is missing.');
        assert(numel(regularField) == 1, 'Regular-step field is missing.');
        assert(numel(listField) == 1, 'Confirmed-list field is missing.');

        labels = findall(figureHandle, 'Type', 'uilabel');
        labelText = string({labels.Text});
        observation.noPlannerRequired = any(contains(labelText, ...
            'No Pre-Test Planner result is required'));
        helpTags = {labels.Tag};
        expectedHelpTags = { ...
            'low_guess_help', 'high_guess_help', ...
            'variation_guess_help', 'maximum_tests_help', ...
            'minimum_gap_help', 'maximum_gap_help', 'unit_help', ...
            'physical_mode_help', 'regular_step_help', ...
            'confirmed_gaps_help', 'foil_thickness_help'};
        observation.everyInputHasHelp = all(ismember(expectedHelpTags, helpTags));
        observation.modeChoices = dropdown.Items;
        observation.initialMode = dropdown.Value;
        observation.regularInitiallyVisible = strcmp(regularField.Visible, 'on');
        observation.regularInitiallyEnabled = strcmp(regularField.Enable, 'on');
        observation.listInitiallyVisible = strcmp(listField.Visible, 'on');
        observation.listInitiallyEnabled = strcmp(listField.Enable, 'on');

        regularField.Value = '0.10';
        listField.Value = '1.00, 1.10, 2.50';
        dropdown.Value = 'Confirmed gap list';
        feval(dropdown.ValueChangedFcn, dropdown, []);
        drawnow;
        observation.regularInListModeVisible = strcmp(regularField.Visible, 'on');
        observation.regularInListModeEnabled = strcmp(regularField.Enable, 'on');
        observation.listInListModeVisible = strcmp(listField.Visible, 'on');
        observation.listInListModeEnabled = strcmp(listField.Enable, 'on');
        observation.regularValueAfterToggle = regularField.Value;
        observation.listValueAfterToggle = listField.Value;

        dropdown.Value = 'Regular gap step';
        feval(dropdown.ValueChangedFcn, dropdown, []);
        drawnow;
        observation.regularAfterReturnVisible = strcmp(regularField.Visible, 'on');
        observation.regularAfterReturnEnabled = strcmp(regularField.Enable, 'on');
        observation.listAfterReturnVisible = strcmp(listField.Visible, 'on');
        observation.listAfterReturnEnabled = strcmp(listField.Enable, 'on');
    catch inputError
        observation.error = getReport(inputError, 'basic', 'hyperlinks', 'off');
    end
    setappdata(groot, 'V2DirectInputUiObservation', observation);
    feval(cancelButtons(1).ButtonPushedFcn, cancelButtons(1), []);
end

function observation = empty_observation()
    observation = struct( ...
        'error', '', ...
        'modeChoices', {{}}, ...
        'initialMode', '', ...
        'regularInitiallyVisible', false, ...
        'regularInitiallyEnabled', false, ...
        'listInitiallyVisible', false, ...
        'listInitiallyEnabled', false, ...
        'regularInListModeVisible', false, ...
        'regularInListModeEnabled', false, ...
        'listInListModeVisible', false, ...
        'listInListModeEnabled', false, ...
        'regularValueAfterToggle', '', ...
        'listValueAfterToggle', '', ...
        'regularAfterReturnVisible', false, ...
        'regularAfterReturnEnabled', false, ...
        'listAfterReturnVisible', false, ...
        'listAfterReturnEnabled', false, ...
        'noPlannerRequired', false, ...
        'everyInputHasHelp', false);
end

function stop_and_delete_timer(watcher)
    if isvalid(watcher)
        if strcmp(watcher.Running, 'on')
            stop(watcher);
        end
        delete(watcher);
    end
end
