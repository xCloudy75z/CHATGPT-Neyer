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

        function rejectsEmptyPhysicalCapability(testCase)
            setup = struct('mode', 'list', 'gaps_mm', [11 12]);
            testCase.verifyError(@() reachable_gap_model(setup, 0, 10), ...
                'reachable_gap_model:noReachableGaps');
        end
    end
end
