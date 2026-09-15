classdef TestV114EmbeddedProbability < matlab.unittest.TestCase
    methods (TestClassSetup)
        function useReviewedApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function interactionChanceFallsWhenGapIncreases(testCase)
            [levels, outcomes] = fittedHistory();
            lowGap = reliability_at_height(levels, outcomes, ...
                'break', 2, 0.95);
            highGap = reliability_at_height(levels, outcomes, ...
                'break', 8, 0.95);

            testCase.verifyGreaterThan(lowGap.reliability, ...
                highGap.reliability, ...
                ['Interaction must become less likely as the physical gap ' ...
                 'increases.']);
        end

        function outcomeChancesAreComplements(testCase)
            [levels, outcomes] = fittedHistory();
            interaction = reliability_at_height(levels, outcomes, ...
                'break', 5, 0.95);
            noInteraction = reliability_at_height(levels, outcomes, ...
                'survive', 5, 0.95);

            testCase.verifyEqual(interaction.reliability + ...
                noInteraction.reliability, 1, 'AbsTol', 1e-12);
        end
    end
end

function [levels, outcomes] = fittedHistory()
paperOutcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
decreasingGapOutcomes = ~paperOutcomes;
parameters = struct('avg_low', 0.6, 'avg_high', 1.4, ...
    'spread_guess', 0.1);
evalc('[result,~] = run_test(parameters, 20, @(~,testNumber) decreasingGapOutcomes(testNumber));');
levels = result.levels;
outcomes = result.successes;
end
