classdef TestV2ResultUi < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function unfinishedResultShowsOneHonestSaveableStatus(testCase)
            if ~usejava('desktop')
                source = lower(fileread(which('show_result')));
                testCase.verifySubstring(source, 'show_unfinished_result');
                testCase.verifySubstring(source, 'completed tests:');
                testCase.verifySubstring(source, 'interaction observed:');
                testCase.verifySubstring(source, 'no interaction observed:');
                testCase.verifySubstring(source, ...
                    'middle gap and overall variation cannot yet be calculated');
                return;
            end

            close(findall(groot, 'Type', 'figure'));
            cleanupFigures = onCleanup(@() close( ...
                findall(groot, 'Type', 'figure'))); %#ok<NASGU>
            resultFigure = show_result(unfinishedResult());
            drawnow;

            visibleText = lower(visibleResultText(resultFigure));
            panels = findall(resultFigure, 'Type', 'uipanel');
            axesHandles = findall(resultFigure, 'Type', 'axes');
            numericFields = findall(resultFigure, ...
                'Type', 'uinumericeditfield');
            dropdowns = findall(resultFigure, 'Type', 'uidropdown');
            buttons = findall(resultFigure, 'Type', 'uibutton');
            buttonText = string({buttons.Text});
            saveButton = buttons(buttonText == "Save results...");

            testCase.verifyNumElements(panels, 1);
            testCase.verifyEmpty(axesHandles);
            testCase.verifyEmpty(numericFields);
            testCase.verifyEmpty(dropdowns);
            testCase.verifyFalse(any(buttonText == "Calculate"));
            testCase.assertNumElements(saveButton, 1);
            testCase.verifyTrue(strcmp(saveButton.Enable, 'on'));
            testCase.verifySubstring(visibleText, ...
                'middle gap and overall variation cannot yet be calculated');
            testCase.verifySubstring(visibleText, 'completed tests: 3');
            testCase.verifySubstring(visibleText, ...
                'interaction observed: yes (1)');
            testCase.verifySubstring(visibleText, ...
                'no interaction observed: yes (2)');
            testCase.verifySubstring(visibleText, 'next action:');
            testCase.verifyFalse(contains(visibleText, 'probability'));
            testCase.verifyFalse(contains(visibleText, 'nan'));
        end

        function calculatedResultUsesEstimatesWithoutConfidenceClaims(testCase)
            if ~usejava('desktop')
                source = lower(fileread(which('show_result')));
                testCase.verifySubstring(source, ...
                    'middle gap (about 50%% interaction)');
                testCase.verifyFalse(contains(source, ...
                    'cautious minimum supported by the data'));
                testCase.verifyFalse(contains(source, ...
                    'direction: smaller gaps make interaction more likely'));
                testCase.verifyFalse(contains(source, ...
                    'this 95% view describes uncertainty'));
                testCase.verifyFalse(contains(source, ...
                    'format_confidence_range(confidence'));
                testCase.verifyFalse(contains(source, ...
                    'isnan(answer.bound_percent)'));
                return;
            end

            close(findall(groot, 'Type', 'figure'));
            cleanupFigures = onCleanup(@() close( ...
                findall(groot, 'Type', 'figure'))); %#ok<NASGU>
            demo = run_demo();
            resultFigure = show_result(demo.result);
            drawnow;

            testCase.verifyNumElements( ...
                findall(resultFigure, 'Type', 'axes'), 2);
            visibleText = lower(visibleResultText(resultFigure));
            testCase.verifySubstring(visibleText, 'calculated result');
            testCase.verifyFalse(contains(visibleText, 'fitted result'));
            testCase.verifySubstring(visibleText, ...
                'middle gap (about 50% interaction)');
            testCase.verifyFalse(contains(visibleText, '95% confidence'));
            testCase.verifyFalse(contains(visibleText, '95% view'));
            testCase.verifyFalse(contains(visibleText, 'cautious minimum'));
            testCase.verifyFalse(contains(visibleText, 'direction:'));

            gapEdit = findall(resultFigure, ...
                'Type', 'uinumericeditfield');
            outcomeChoice = findall(resultFigure, 'Type', 'uidropdown');
            buttons = findall(resultFigure, 'Type', 'uibutton');
            calculateButton = buttons( ...
                string({buttons.Text}) == "Calculate");
            gapEdit.Value = demo.result.mu;
            outcomeChoice.Value = 'Interaction';
            feval(calculateButton.ButtonPushedFcn, calculateButton, []);
            drawnow;

            visibleText = lower(visibleResultText(resultFigure));
            testCase.verifySubstring(visibleText, ...
                'best estimated chance 50%');
            testCase.verifyFalse(contains(visibleText, 'cautious minimum'));
            testCase.verifyFalse(contains(visibleText, 'confidence'));
        end

        function compactResultChartOmitsConfidenceRange(testCase)
            source = fileread(which('draw_distribution'));
            compactFunction = regexp(source, ...
                '(?ms)^function draw_compact_distribution.*?(?=^function strip_patch)', ...
                'match', 'once');
            testCase.assertNotEmpty(compactFunction);
            compactFunction = lower(compactFunction);
            testCase.verifyFalse(contains(compactFunction, 'confidence'));
            testCase.verifyFalse(contains(compactFunction, ...
                'middle-gap range'));
        end
    end
end

function text = visibleResultText(resultFigure)
labels = findall(resultFigure, 'Type', 'uilabel');
panels = findall(resultFigure, 'Type', 'uipanel');
buttons = findall(resultFigure, 'Type', 'uibutton');
text = strjoin([string({labels.Text}), string({panels.Title}), ...
    string({buttons.Text})], ' | ');
end

function result = unfinishedResult()
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
