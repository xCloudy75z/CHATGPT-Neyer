classdef TestV114FocusedUi < matlab.unittest.TestCase
    methods (Test)
        function mainMenuIsOnlyForTheGapStudy(testCase)
            source = applicationSource('neyer_app.m');
            testCase.verifySubstring(source, 'Neyer Gap Test V1.14');
            testCase.verifySubstring(source, 'Start a Gap Study');
            testCase.verifySubstring(source, 'Run the Published Example');
            testCase.verifySubstring(source, 'Help and Definitions');
            testCase.verifyFalse(contains(source, 'Pre-Test Planner (separate)'));
            testCase.verifyFalse(contains(source, 'Review latest results'));
            testCase.verifyFalse(contains(source, '@onPlanner'));
            testCase.verifyFalse(contains(source, '@onReliability'));
        end

        function resultScreenDoesNotIssuePlannerDecision(testCase)
            source = applicationSource('show_result.m');
            testCase.verifySubstring(source, ...
                'Gap-study summary');
            testCase.verifySubstring(source, ...
                'How certain is this estimate?');
            testCase.verifySubstring(source, ...
                'This 95% view describes uncertainty in the fitted estimate');
            testCase.verifyFalse(contains(source, ...
                'Supported operating instruction'));
            testCase.verifyFalse(contains(source, ...
                'reliable operating gap shown in the decision above'));
        end

        function helpExplainsFirstStudyAndExcludesQualificationPlanner(testCase)
            source = applicationSource('show_manual.m');
            testCase.verifySubstring(source, ...
                'First study - variation unknown');
            testCase.verifySubstring(source, ...
                'one measured gap reading');
            testCase.verifySubstring(source, ...
                'fixed-gap reliability demonstration is a separate later study');
            testCase.verifyFalse(contains(source, ...
                'needs at least 400 independent articles'));
        end
    end
end

function source = applicationSource(fileName)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
source = fileread(fullfile(projectRoot, 'application', 'source', fileName));
end
