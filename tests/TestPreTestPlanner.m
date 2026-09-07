classdef TestPreTestPlanner < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function acceptsPercentOrFractionInputs(testCase)
            input = validPlanInput();
            input.reliability = 99;
            input.confidence = 0.95;

            [clean, messages] = validate_plan_inputs(input);

            testCase.verifyEqual(clean.reliability, 0.99, 'AbsTol', 1e-12);
            testCase.verifyEqual(clean.confidence, 0.95, 'AbsTol', 1e-12);
            testCase.verifyNotEmpty(messages);
        end

        function acceptsApprovedPercentageEdges(testCase)
            input = validPlanInput();
            input.reliability = 10;
            input.confidence = 99.9;
            clean = validate_plan_inputs(input);
            testCase.verifyEqual(clean.reliability, 0.10, 'AbsTol', 1e-12);
            testCase.verifyEqual(clean.confidence, 0.999, 'AbsTol', 1e-12);
        end

        function labelsConfidenceBelowFiftyAsExploratory(testCase)
            input = validPlanInput();
            input.confidence = 49.9;
            [~, messages] = validate_plan_inputs(input);
            testCase.verifyTrue(any(contains(lower(messages), 'exploratory')));
            testCase.verifyTrue(any(contains(messages, '50%')));
        end

        function labelsFiftyAsNoSafetyMargin(testCase)
            input = validPlanInput();
            input.confidence = 50;
            [~, messages] = validate_plan_inputs(input);
            testCase.verifyTrue(any(contains(lower(messages), 'no safety margin')));
        end

        function labelsAboveFiftyAsConservativeProtection(testCase)
            input = validPlanInput();
            input.confidence = 95;
            [~, messages] = validate_plan_inputs(input);
            testCase.verifyTrue(any(contains(lower(messages), 'cautious')));
        end

        function requiresAnExplicitOutcome(testCase)
            input = validPlanInput();
            input.outcome = '';
            testCase.verifyError(@() validate_plan_inputs(input), ...
                'validate_plan_inputs:missingOutcome');
        end

        function rejectsPercentagesOutsideApprovedRange(testCase)
            lowReliability = validPlanInput();
            lowReliability.reliability = 9.9;
            highConfidence = validPlanInput();
            highConfidence.confidence = 100;
            testCase.verifyError(@() validate_plan_inputs(lowReliability), ...
                'validate_plan_inputs:badReliability');
            testCase.verifyError(@() validate_plan_inputs(highConfidence), ...
                'validate_plan_inputs:badConfidence');
        end

        function rejectsReversedPhysicalExpectations(testCase)
            input = validPlanInput();
            input.interaction_gap_mm = 8;
            input.no_interaction_gap_mm = 2;
            testCase.verifyError(@() validate_plan_inputs(input), ...
                'validate_plan_inputs:reversedExpectations');
        end

        function rejectsInvalidPermittedRange(testCase)
            input = validPlanInput();
            input.minimum_gap_mm = 10;
            input.maximum_gap_mm = 10;
            testCase.verifyError(@() validate_plan_inputs(input), ...
                'validate_plan_inputs:badPermittedRange');
        end

        function availableModeNeedsAWholePositiveArticleCount(testCase)
            input = validPlanInput();
            input.mode = 'available_articles_first';
            input.available_articles = 12.5;
            testCase.verifyError(@() validate_plan_inputs(input), ...
                'validate_plan_inputs:badAvailableArticles');
        end

        function accuracyMustFitInsidePermittedRange(testCase)
            input = validPlanInput();
            input.accuracy_mm = 11;
            testCase.verifyError(@() validate_plan_inputs(input), ...
                'validate_plan_inputs:badAccuracy');
        end
    end
end

function input = validPlanInput()
input = struct( ...
    'mode', 'requirements_first', ...
    'outcome', 'interaction', ...
    'reliability', 99, ...
    'confidence', 95, ...
    'accuracy_mm', 0.10, ...
    'interaction_gap_mm', 1.00, ...
    'no_interaction_gap_mm', 10.00, ...
    'minimum_gap_mm', 0.00, ...
    'maximum_gap_mm', 10.00, ...
    'previous_information', 'first_study', ...
    'available_articles', [], ...
    'physical_setup', struct('mode', 'regular', 'increment_mm', 0.10));
end
