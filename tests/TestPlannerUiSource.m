classdef TestPlannerUiSource < matlab.unittest.TestCase
    methods (Test)
        function plannerIsOneGuidedWorksheet(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            sourcePath = fullfile(projectRoot, 'application', 'source', ...
                'pretest_planner_ui.m');
            testCase.assertTrue(isfile(sourcePath));
            source = fileread(sourcePath);

            testCase.verifySubstring(source, 'Plan  >  Prepare  >  Test  >  Check  >  Finish');
            testCase.verifySubstring(source, 'How would you like to plan?');
            testCase.verifySubstring(source, 'What result do you need?');
            testCase.verifySubstring(source, 'What do you know?');
            testCase.verifySubstring(source, 'What can you build?');
            testCase.verifySubstring(source, 'Requirements first');
            testCase.verifySubstring(source, 'Articles available first');
            testCase.verifySubstring(source, 'No, this is my first study');
            testCase.verifySubstring(source, 'Review plan');
            testCase.verifySubstring(source, 'Save plan');
            testCase.verifyFalse(contains(lower(source), 'transition width'));
        end

        function everyMainPlannerQuestionHasPlainHelp(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            source = fileread(fullfile(projectRoot, 'application', 'source', ...
                'pretest_planner_ui.m'));
            explanations = { ...
                'The physical result you need the final operating gap to produce.', ...
                'The minimum fraction of similar articles expected to give that result.', ...
                'How strongly the completed evidence must support the reliability.', ...
                'How close the calculated gap needs to be in millimetres.', ...
                'A smaller gap where Interaction is expected almost every time.', ...
                'A larger gap where No interaction is expected almost every time.'};
            for explanationNumber = 1:numel(explanations)
                testCase.verifySubstring(source, explanations{explanationNumber});
            end
        end

        function mainMenuUsesNewPlannerAndCanLoadPlanForTesting(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            menuSource = fileread(fullfile(projectRoot, 'application', 'source', ...
                'neyer_app.m'));
            testSource = fileread(fullfile(projectRoot, 'application', 'source', ...
                'run_test_ui.m'));
            testCase.verifySubstring(menuSource, 'pretest_planner_ui');
            testCase.verifySubstring(menuSource, 'Load a saved plan');
            testCase.verifySubstring(testSource, 'loaded_plan');
            testCase.verifySubstring(testSource, 'Planned checkpoint');
        end

        function saveScreenShowsExactDestinationBeforeWriting(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            source = fileread(fullfile(projectRoot, 'application', 'source', ...
                'pretest_planner_ui.m'));
            testCase.verifySubstring(source, 'This exact file will be created:');
            testCase.verifySubstring(source, 'An existing file will not be replaced.');
            testCase.verifySubstring(source, 'save_study_plan');
        end
    end
end
