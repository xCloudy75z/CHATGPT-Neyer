classdef TestV114FirstStudyInputs < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function directWindowDefaultsToUnknownVariationRoute(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            source = fileread(fullfile(projectRoot, 'application', ...
                'source', 'run_test_ui.m'));
            testCase.verifySubstring(source, ...
                '''First study - variation unknown''');
            testCase.verifySubstring(source, ...
                '''Advanced - starting variation known''');
            testCase.verifySubstring(source, '''study_mode''');
            testCase.verifySubstring(source, 'update_study_mode');
        end

        function automaticScaleUsesOneSixthOfMiddleRange(testCase)
            scale = automatic_search_scale(1, 10, 0.10, 10);
            testCase.verifyEqual(scale, 1.5, 'AbsTol', 1e-12);
        end

        function automaticScaleNeverFallsBelowReachableSpacing(testCase)
            scale = automatic_search_scale(4.9, 5.1, 0.10, 10);
            testCase.verifyEqual(scale, 0.10, 'AbsTol', 1e-12);
        end

        function firstStudyNeedsNoVariationEntry(testCase)
            answers = regularAnswers();
            answers.study_mode = 'First study - variation unknown';
            answers.variation_guess = '';
            parsed = parse_run_inputs(answers);

            testCase.verifyEqual(parsed.params.spread_guess, 1.5, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(parsed.cfg.study_mode, 'first_study');
            testCase.verifyEqual(parsed.cfg.search_scale_source, 'automatic');
        end

        function advancedStudyKeepsEnteredStartingVariation(testCase)
            answers = regularAnswers();
            answers.study_mode = 'Advanced - starting variation known';
            answers.variation_guess = '0.25';
            parsed = parse_run_inputs(answers);

            testCase.verifyEqual(parsed.params.spread_guess, 0.25, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(parsed.cfg.study_mode, 'advanced');
            testCase.verifyEqual(parsed.cfg.search_scale_source, 'operator');
        end

        function confirmedListUsesItsSmallestSpacing(testCase)
            answers = regularAnswers();
            answers.study_mode = 'First study - variation unknown';
            answers.variation_guess = '';
            answers.physical_mode = 'Confirmed gap list';
            answers.confirmed_gaps = '0.00, 0.20, 0.50, 1.00, 10.00';
            parsed = parse_run_inputs(answers);

            testCase.verifyEqual(parsed.cfg.level_increment, 0.20, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(parsed.params.spread_guess, 1.5, ...
                'AbsTol', 1e-12);
        end

        function invalidStudyModeIsRejectedClearly(testCase)
            answers = regularAnswers();
            answers.study_mode = 'Guess for me';
            testCase.verifyError(@() parse_run_inputs(answers), ...
                'parse_run_inputs:badStudyMode');
        end
    end
end

function answers = regularAnswers()
answers = struct( ...
    'low_guess', '1', ...
    'high_guess', '10', ...
    'variation_guess', '1', ...
    'maximum_tests', '62', ...
    'minimum_gap', '0', ...
    'maximum_gap', '10', ...
    'unit', 'mm', ...
    'physical_mode', 'Regular gap step', ...
    'regular_step', '0.10', ...
    'confirmed_gaps', '', ...
    'foil_thickness', '0.015');
end
