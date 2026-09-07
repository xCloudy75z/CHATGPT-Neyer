classdef TestReachableGapModel < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function regularModesCoverApprovedIncrementExamples(testCase)
            increments = [0.05 0.10 0.15 0.50];
            for incrementNumber = 1:numel(increments)
                increment = increments(incrementNumber);
                model = reachable_gap_model(struct('mode', 'regular', ...
                    'increment_mm', increment), 0, 1);
                testCase.verifyEqual(model.gaps_mm(1), 0, 'AbsTol', 1e-12);
                testCase.verifyEqual(model.gaps_mm(end), ...
                    floor(1 / increment) * increment, 'AbsTol', 1e-12);
                testCase.verifyEqual(diff(model.gaps_mm), ...
                    increment * ones(numel(model.gaps_mm) - 1, 1), ...
                    'AbsTol', 1e-12);
            end
        end

        function regularIncrementMustFitTwoDecimalRequest(testCase)
            setup = struct('mode', 'regular', 'increment_mm', 0.015);

            testCase.verifyError(@() reachable_gap_model(setup, 0, 1), ...
                'reachable_gap_model:badIncrementPrecision');
        end

        function confirmedListIsSortedDeduplicatedAndBounded(testCase)
            setup = struct('mode', 'list', ...
                'gaps_mm', [2.5 0.5 1.1 2.5 3.67 -1 11]);
            model = reachable_gap_model(setup, 0, 10);
            testCase.verifyEqual(model.gaps_mm, [0.5; 1.1; 2.5; 3.67], ...
                'AbsTol', 1e-12);
        end

        function combinationsPreserveBuildRecipe(testCase)
            setup = struct('mode', 'combinations', ...
                'component_names', {{'foil layer', '0.50 mm spacer'}}, ...
                'component_mm', [0.015 0.50], ...
                'maximum_counts', [2 1]);
            model = reachable_gap_model(setup, 0, 0.53);

            testCase.verifyEqual(model.gaps_mm, ...
                [0; 0.015; 0.030; 0.500; 0.515; 0.530], ...
                'AbsTol', 1e-12);
            recipeRow = find(abs(model.gaps_mm - 0.515) < 1e-12, 1);
            testCase.verifySubstring(model.instructions(recipeRow), ...
                '1 foil layer');
            testCase.verifySubstring(model.instructions(recipeRow), ...
                '1 0.50 mm spacer');
        end

        function interactionRoundsDownAndNoInteractionRoundsUp(testCase)
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.10), 0, 10);
            [interactionGap, interactionStatus] = round_reachable_gap( ...
                2.45, 'interaction', model, []);
            [noInteractionGap, noInteractionStatus] = round_reachable_gap( ...
                2.45, 'no_interaction', model, []);

            testCase.verifyEqual(interactionGap, 2.40, 'AbsTol', 1e-12);
            testCase.verifyEqual(noInteractionGap, 2.50, 'AbsTol', 1e-12);
            testCase.verifyEqual(interactionStatus.display_gap, "2.40 mm");
            testCase.verifyEqual(noInteractionStatus.display_gap, "2.50 mm");
        end

        function finalOperatingGapIsJudgedAgainstTheTrueBoundary(testCase)
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.10), 0, 10);
            interaction = operating_gap_coverage(2.46, 2.45, ...
                'interaction', model);
            noInteraction = operating_gap_coverage(2.44, 2.45, ...
                'no_interaction', model);
            testCase.verifyTrue(interaction.conservative);
            testCase.verifyEqual(interaction.safe_gap_mm, 2.30, 'AbsTol', 1e-12);
            testCase.verifyTrue(noInteraction.conservative);
            testCase.verifyEqual(noInteraction.safe_gap_mm, 2.60, 'AbsTol', 1e-12);
        end

        function operatingInstructionUsesOneExtraSafeSetting(testCase)
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.10), 0, 10);

            [interactionGap, interactionStatus] = select_operating_gap( ...
                2.46, 'interaction', model);
            [noInteractionGap, noInteractionStatus] = select_operating_gap( ...
                2.44, 'no_interaction', model);

            testCase.verifyEqual(interactionGap, 2.30, 'AbsTol', 1e-12);
            testCase.verifyEqual(noInteractionGap, 2.60, 'AbsTol', 1e-12);
            testCase.verifyEqual(interactionStatus.code, 'ok');
            testCase.verifyEqual(noInteractionStatus.code, 'ok');
            testCase.verifySubstring(lower(interactionStatus.message), ...
                'extra reachable');
        end

        function operatingInstructionIsWithheldWithoutExtraSafeSetting(testCase)
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', 2.40), 0, 10);

            [gap, status] = select_operating_gap(2.45, ...
                'interaction', model);

            testCase.verifyTrue(isnan(gap));
            testCase.verifyEqual(status.code, 'no_buffered_setting');
            testCase.verifySubstring(lower(status.message), ...
                'extra reachable');
        end

        function repeatedSettingMovesToNearestDifferentSafeGap(testCase)
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.10), 0, 10);
            interactionGap = round_reachable_gap(2.45, 'interaction', model, 2.40);
            noInteractionGap = round_reachable_gap(2.45, ...
                'no_interaction', model, 2.50);
            testCase.verifyEqual(interactionGap, 2.30, 'AbsTol', 1e-12);
            testCase.verifyEqual(noInteractionGap, 2.60, 'AbsTol', 1e-12);
        end

        function reportsWhenNoDifferentSafeSettingExists(testCase)
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', 2.40), 0, 10);
            [gap, status] = round_reachable_gap(2.45, ...
                'interaction', model, 2.40);
            testCase.verifyTrue(isnan(gap));
            testCase.verifyEqual(status.code, 'no_different_setting');
            testCase.verifySubstring(lower(status.message), 'different');
        end

        function sequentialSelectionReportsExhaustedCapability(testCase)
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', 0.5), 0, 1);
            [gap, status] = select_reachable_request(0.75, model, 0.5, false);
            testCase.verifyTrue(isnan(gap));
            testCase.verifyEqual(status.code, 'no_different_gap');
            testCase.verifySubstring(lower(status.message), 'review');
        end

        function sequentialSelectionCanRevisitAnOlderUsefulGap(testCase)
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', [0 0.5 1.0]), 0, 1);
            [gap, status] = select_reachable_request(0.5, model, ...
                [0.5 1.0], false);
            testCase.verifyEqual(gap, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(status.code, 'ok');
        end

        function finalBoundsCannotCreateAnUnreachableRequest(testCase)
            cfg = neyer_settings();
            cfg.min_level = 0.05;
            cfg.max_level = 0.10;
            cfg.reachable_model = reachable_gap_model(struct( ...
                'mode', 'list', 'gaps_mm', [0 0.10]), 0, 0.10);
            parameters = struct('mu_min', 0, 'mu_max', 0.10, ...
                'sigma_guess', 0.10);

            record = run_loop(parameters, 1, @(~, ~) true, cfg);

            testCase.verifyEqual(record.requested_levels, 0.10, ...
                'AbsTol', 1e-12);
            testCase.verifySubstring(record.requested_instructions, '0.10');
        end

        function rejectsEmptyPhysicalCapability(testCase)
            setup = struct('mode', 'list', 'gaps_mm', [11 12]);
            testCase.verifyError(@() reachable_gap_model(setup, 0, 10), ...
                'reachable_gap_model:noReachableGaps');
        end
    end
end
