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

        function tighterGapAccuracyNeverReducesArticleQuantity(testCase)
            broad = validatedPlanInput();
            tight = broad;
            broad.accuracy_mm = 0.20;
            tight.accuracy_mm = 0.05;
            model = reachable_gap_model(broad.physical_setup, 0, 10);

            broadPlan = estimate_study_plan(broad, model);
            tightPlan = estimate_study_plan(tight, model);

            testCase.verifyGreaterThanOrEqual(tightPlan.main_articles, ...
                broadPlan.main_articles);
            testCase.verifyGreaterThanOrEqual(tightPlan.total_articles, ...
                broadPlan.total_articles);
        end

        function higherCautiousConfidenceNeverReducesQuantity(testCase)
            lower = validatedPlanInput();
            higher = lower;
            lower.confidence = 0.80;
            higher.confidence = 0.95;
            model = reachable_gap_model(lower.physical_setup, 0, 10);

            lowerPlan = estimate_study_plan(lower, model);
            higherPlan = estimate_study_plan(higher, model);

            testCase.verifyGreaterThanOrEqual(higherPlan.main_articles, ...
                lowerPlan.main_articles);
        end

        function moreDemandingReliabilityNeverReducesQuantity(testCase)
            lower = validatedPlanInput();
            higher = lower;
            lower.reliability = 0.90;
            higher.reliability = 0.999;
            model = reachable_gap_model(lower.physical_setup, 0, 10);

            lowerPlan = estimate_study_plan(lower, model);
            higherPlan = estimate_study_plan(higher, model);

            testCase.verifyGreaterThanOrEqual(higherPlan.main_articles, ...
                lowerPlan.main_articles);
        end

        function physicalCapabilityCanMakeRequestUnsupported(testCase)
            input = validatedPlanInput();
            input.accuracy_mm = 0.05;
            coarseModel = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.50), 0, 10);

            plan = estimate_study_plan(input, coarseModel);

            testCase.verifyFalse(plan.feasible);
            testCase.verifyTrue(any(contains(lower(plan.suggestions), ...
                'physical')));
        end

        function firstStudyExplainsNinetyFivePercentAssumption(testCase)
            input = validatedPlanInput();
            model = reachable_gap_model(input.physical_setup, 0, 10);

            plan = estimate_study_plan(input, model);

            testCase.verifyTrue(any(contains(plan.assumptions, '95%')));
            testCase.verifyTrue(any(contains(lower(plan.assumptions), ...
                'first study')));
        end

        function veryBroadUnknownStudySuggestsDiscovery(testCase)
            input = validatedPlanInput();
            input.accuracy_mm = 0.01;
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.01), 0, 10);

            plan = estimate_study_plan(input, model);

            testCase.verifyFalse(plan.feasible);
            testCase.verifyEqual(plan.plan_kind, 'discovery');
            testCase.verifyTrue(any(contains(lower(plan.suggestions), ...
                'discovery')));
        end

        function explanationDoesNotHideHalfSigmaRule(testCase)
            input = validatedPlanInput();
            model = reachable_gap_model(input.physical_setup, 0, 10);
            plan = estimate_study_plan(input, model);
            combinedText = lower(strjoin([plan.assumptions; ...
                plan.suggestions; string(plan.validation_basis)], ' '));
            testCase.verifyFalse(contains(combinedText, '0.5 x sigma'));
            testCase.verifyFalse(contains(combinedText, '0.5 × sigma'));
        end

        function plannerSummarySeparatesMainAndReserveGroups(testCase)
            input = validatedPlanInput();
            model = reachable_gap_model(input.physical_setup, 0, 10);
            plan = plan_prep_numbers(input, model);
            message = plan_prep_message(plan, 'mm');

            testCase.verifySubstring(message, 'Main study');
            testCase.verifySubstring(message, 'Reserve group 1');
            testCase.verifySubstring(message, 'Reserve group 2');
            testCase.verifySubstring(message, 'Total to prepare');
            testCase.verifySubstring(lower(message), 'estimate');
            testCase.verifySubstring(message, sprintf('%.2f mm', ...
                plan.starting_gap_mm));
        end

        function moreAvailableArticlesDoNotReduceExpectedConfidence(testCase)
            smaller = inversePlanInput(300);
            larger = inversePlanInput(1200);
            model = reachable_gap_model(smaller.physical_setup, 0, 10);

            smallerAnswer = estimate_supported_targets(smaller, model, ...
                'reliability');
            largerAnswer = estimate_supported_targets(larger, model, ...
                'reliability');

            testCase.verifyGreaterThanOrEqual(largerAnswer.best_confidence, ...
                smallerAnswer.best_confidence);
        end

        function moreAvailableArticlesDoNotReduceExpectedReliability(testCase)
            smaller = inversePlanInput(300);
            larger = inversePlanInput(1200);
            smaller.confidence = 0.80;
            larger.confidence = 0.80;
            model = reachable_gap_model(smaller.physical_setup, 0, 10);

            smallerAnswer = estimate_supported_targets(smaller, model, ...
                'confidence');
            largerAnswer = estimate_supported_targets(larger, model, ...
                'confidence');

            testCase.verifyGreaterThanOrEqual(largerAnswer.best_reliability, ...
                smallerAnswer.best_reliability);
        end

        function availableArticleAnswerKeepsOneUserChoiceFixed(testCase)
            input = inversePlanInput(600);
            model = reachable_gap_model(input.physical_setup, 0, 10);
            answer = estimate_supported_targets(input, model, 'reliability');

            testCase.verifyEqual(answer.fixed_kind, 'reliability');
            testCase.verifyEqual(answer.fixed_value, input.reliability, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(answer.estimated_kind, 'confidence');
            testCase.verifySubstring(lower(answer.statement), ...
                'pre-test expectation');
            testCase.verifySubstring(lower(answer.statement), ...
                'not a final claim');
        end

        function inversePlannerReportsPhysicalLimitation(testCase)
            input = inversePlanInput(1000);
            input.accuracy_mm = 0.01;
            model = reachable_gap_model(struct('mode', 'regular', ...
                'increment_mm', 0.50), 0, 10);
            answer = estimate_supported_targets(input, model, 'reliability');

            testCase.verifyFalse(answer.physically_achievable);
            testCase.verifyTrue(any(contains(lower(answer.messages), 'physical')));
        end
    end
end

function input = validatedPlanInput()
    input = validate_plan_inputs(validPlanInput());
end

function input = inversePlanInput(articleCount)
    input = validPlanInput();
    input.mode = 'available_articles_first';
    input.available_articles = articleCount;
    input.reliability = 0.90;
    input.confidence = 0.80;
    input.accuracy_mm = 0.20;
    input.interaction_gap_mm = 4.00;
    input.no_interaction_gap_mm = 6.00;
    input = validate_plan_inputs(input);
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
