classdef TestFixedGapConfidence < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function interactionMinimumDoesNotExceedBestEstimate(testCase)
            fittedResult = referenceResult();
            answer = reliability_query(fittedResult, 'interaction', ...
                'probability_at', 3.00, 0.95);

            testCase.verifyLessThanOrEqual(answer.bound_probability, ...
                answer.probability, ...
                ['A cautious minimum Interaction probability cannot be ' ...
                 'higher than the best estimate.']);
        end

        function noInteractionMinimumDoesNotExceedBestEstimate(testCase)
            fittedResult = referenceResult();
            answer = reliability_query(fittedResult, 'no_interaction', ...
                'probability_at', 6.00, 0.95);

            testCase.verifyLessThanOrEqual(answer.bound_probability, ...
                answer.probability, ...
                ['A cautious minimum No-interaction probability cannot be ' ...
                 'higher than the best estimate.']);
        end

        function representativeMinimumsAreFiniteAndNotArtificialFloors(testCase)
            fittedResult = referenceResult();
            checks = {
                'interaction', 2.00
                'interaction', 4.61
                'no_interaction', 4.61
                'no_interaction', 8.00
            };

            for rowNumber = 1:size(checks, 1)
                answer = reliability_query(fittedResult, checks{rowNumber, 1}, ...
                    'probability_at', checks{rowNumber, 2}, 0.95);
                testCase.verifyTrue(isfinite(answer.bound_probability));
                testCase.verifyGreaterThan(answer.bound_probability, 1e-6);
                testCase.verifyFalse(answer.bound_floored);
            end
        end

        function bestProbabilitiesStillMoveInPhysicalDirection(testCase)
            fittedResult = referenceResult();
            interactionLow = reliability_query(fittedResult, 'interaction', ...
                'probability_at', 3.00, 0.95);
            interactionHigh = reliability_query(fittedResult, 'interaction', ...
                'probability_at', 6.00, 0.95);
            noInteractionLow = reliability_query(fittedResult, 'no_interaction', ...
                'probability_at', 3.00, 0.95);
            noInteractionHigh = reliability_query(fittedResult, 'no_interaction', ...
                'probability_at', 6.00, 0.95);

            testCase.verifyGreaterThan(interactionLow.probability, ...
                interactionHigh.probability);
            testCase.verifyLessThan(noInteractionLow.probability, ...
                noInteractionHigh.probability);
        end
    end
end

function fittedResult = referenceResult()
    outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    parameters = struct('avg_low', 8.6, 'avg_high', 9.4, ...
        'spread_guess', 0.1);
    evalc('[fittedResult,~]=run_test(parameters,20,@(~,testNumber)outcomes(testNumber));');
end
