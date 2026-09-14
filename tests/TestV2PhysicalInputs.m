classdef TestV2PhysicalInputs < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function listIsSortedDeduplicatedAndKeptInsideBounds(testCase)
            actual = parse_confirmed_gap_list('2.50, 1.00, 2.50, 4.10', 1, 5);

            testCase.verifyEqual(actual, [1; 2.5; 4.1], 'AbsTol', 1e-12);
        end

        function listNeedsTwoUsableGaps(testCase)
            testCase.verifyError(@() parse_confirmed_gap_list('2.5, 20', 1, 10), ...
                'parse_confirmed_gap_list:notEnoughGaps');
        end

        function listRejectsValuesEntirelyOutsideBounds(testCase)
            testCase.verifyError(@() parse_confirmed_gap_list('20, 30', 1, 10), ...
                'parse_confirmed_gap_list:notEnoughGaps');
        end

        function listFiltersValuesJustOutsideBoundsExactly(testCase)
            actual = parse_confirmed_gap_list( ...
                '0.99999999995, 1.10, 1.20', 1, 2);

            testCase.verifyEqual(actual, [1.1; 1.2], 'AbsTol', 1e-12);
        end

        function listRejectsBlankEntries(testCase)
            testCase.verifyError(@() parse_confirmed_gap_list('1,,2', 0, 3), ...
                'parse_confirmed_gap_list:badEntry');
        end

        function listRejectsNonNumbers(testCase)
            testCase.verifyError(@() parse_confirmed_gap_list('1, two, 2', 0, 3), ...
                'parse_confirmed_gap_list:badEntry');
        end

        function listRejectsNonFiniteAndNegativeEntries(testCase)
            invalid = {'1, NaN, 2', '1, Inf, 2', '1, -0.1, 2'};
            for index = 1:numel(invalid)
                testCase.verifyError(@() parse_confirmed_gap_list( ...
                    invalid{index}, 0, 3), 'parse_confirmed_gap_list:badEntry');
            end
        end

        function listRejectsAmbiguousSeparators(testCase)
            invalid = {'1; 2', '1 2'};
            for index = 1:numel(invalid)
                testCase.verifyError(@() parse_confirmed_gap_list( ...
                    invalid{index}, 0, 3), 'parse_confirmed_gap_list:badFormat');
            end
        end

        function listErrorsNameVisibleQuestionAndCorrection(testCase)
            invalid = {'1,,2', '1, two, 2', '1, NaN, 2', '1, Inf, 2', ...
                '1, -0.1, 2', '1; 2', '1 2', '20, 30', '2.5, 20'};
            for index = 1:numel(invalid)
                try
                    parse_confirmed_gap_list(invalid{index}, 1, 10);
                    testCase.assertFail('Invalid confirmed list was accepted.');
                catch input_error
                    testCase.verifySubstring(input_error.message, ...
                        'Confirmed gap list');
                    testCase.verifyTrue(contains(lower(input_error.message), ...
                        'enter') || contains(lower(input_error.message), 'separate'));
                end
            end
        end

        function directListModeBuildsReachableModel(testCase)
            answers = confirmed_list_answers('1, 1.1, 2.5, 4.1, 5.5');

            parsed = parse_run_inputs(answers);

            testCase.verifyEqual(parsed.cfg.reachable_model.mode, 'list');
            testCase.verifyEqual(parsed.cfg.reachable_model.gaps_mm, ...
                [1;1.1;2.5;4.1;5.5], 'AbsTol', 1e-12);
        end

        function confirmedListRejectsValuesThatCannotBeShownExactly(testCase)
            answers = confirmed_list_answers('1.002, 1.008');

            testCase.verifyError(@() parse_run_inputs(answers), ...
                'parse_confirmed_gap_list:tooManyDecimals');
        end

        function directListModeSetsFloorAndRestrictsRequests(testCase)
            parsed = parse_run_inputs(confirmed_list_answers( ...
                '1, 1.1, 2.5, 4.1, 5.5'));
            response = @(gap, testNumber) struct( ...
                'outcome', logical(mod(testNumber, 2)), 'measurements', gap);

            record = run_loop(struct('mu_min', parsed.params.avg_low, ...
                'mu_max', parsed.params.avg_high, ...
                'sigma_guess', parsed.params.spread_guess), 3, response, parsed.cfg);

            testCase.verifyEqual(parsed.cfg.usable_resolution, 0.1, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(parsed.cfg.level_increment, 0.1, ...
                'AbsTol', 1e-12);
            testCase.verifyTrue(all(ismembertol(record.requested_levels, ...
                parsed.cfg.reachable_model.gaps_mm, 1e-12)));
        end

        function namedRegularModeRetainsLegacyStepBehavior(testCase)
            answers = confirmed_list_answers('');
            answers.physical_mode = 'Regular gap step';
            answers.regular_step = '0.10';

            parsed = parse_run_inputs(answers);

            testCase.verifyEqual(parsed.cfg.reachable_model.mode, 'regular');
            testCase.verifyEqual(parsed.cfg.usable_resolution, 0.10, ...
                'AbsTol', 1e-12);
        end

        function namedPhysicalModeRejectsMalformedLabel(testCase)
            answers = confirmed_list_answers('');
            answers.physical_mode = 'not regular';

            testCase.verifyError(@() parse_run_inputs(answers), ...
                'parse_run_inputs:badPhysicalMode');
        end

        function directRunRejectsAUnitOtherThanMillimetres(testCase)
            answers = confirmed_list_answers('1.00, 1.10');
            answers.unit = 'in';

            testCase.verifyError(@() parse_run_inputs(answers), ...
                'parse_run_inputs:badUnit');
        end
    end
end

function answers = confirmed_list_answers(confirmed_gaps)
    answers = struct('low_guess','1','high_guess','10', ...
        'variation_guess','1','maximum_tests','62', ...
        'minimum_gap','1','maximum_gap','10','unit','mm', ...
        'physical_mode','Confirmed gap list', ...
        'regular_step','','confirmed_gaps',confirmed_gaps, ...
        'foil_thickness','0.015');
end
