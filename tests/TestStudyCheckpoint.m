classdef TestStudyCheckpoint < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function oneOutcomeOnlyAsksForDeclaredReserve(testCase)
            result = referenceResult();
            result.successes(:) = true;
            result.has_overlap = false;
            plan = checkpointPlan();

            decision = check_study_checkpoint(result, plan, 'main');

            testCase.verifyEqual(decision.status, 'ask_for_reserve');
            testCase.verifyEqual(decision.next_checkpoint, 'reserve_1');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'both outcomes')));
            testCase.verifySubstring(lower(decision.plain_explanation), ...
                'not a failed physical test');
        end

        function overlapMustExist(testCase)
            result = referenceResult();
            result.has_overlap = false;
            plan = checkpointPlan();
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'overlap')));
        end

        function fitMustBeFinite(testCase)
            result = referenceResult();
            result.mu = NaN;
            plan = checkpointPlan();
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'finite middle')));
        end

        function middleAccuracyMustBeMet(testCase)
            result = referenceResult();
            result.mu_lo = 0;
            result.mu_hi = 10;
            plan = checkpointPlan();
            plan.accuracy_mm = 0.10;
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'middle-gap accuracy')));
        end

        function reliabilityBoundaryMustBeInsidePermittedRange(testCase)
            result = referenceResult();
            plan = checkpointPlan();
            plan.reliability = 0.999;
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'permitted range')));
        end

        function aSafeReachableSettingMustExist(testCase)
            result = referenceResult();
            plan = checkpointPlan();
            plan.reachable_model = reachable_gap_model( ...
                struct('mode', 'list', 'gaps_mm', 10), 0, 10);
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyTrue(any(contains(lower(decision.missing_conditions), ...
                'reachable')));
        end

        function completeMainCheckpointStopsWithoutReserves(testCase)
            result = referenceResult();
            plan = checkpointPlan();
            decision = check_study_checkpoint(result, plan, 'main');
            testCase.verifyEqual(decision.status, 'complete');
            testCase.verifyEmpty(decision.next_checkpoint);
            testCase.verifyEmpty(decision.missing_conditions);
        end

        function exhaustedReserveTwoReportsUnsupported(testCase)
            result = referenceResult();
            result.has_overlap = false;
            plan = checkpointPlan();
            decision = check_study_checkpoint(result, plan, 'reserve_2');
            testCase.verifyEqual(decision.status, 'unsupported');
            testCase.verifyEmpty(decision.next_checkpoint);
            testCase.verifySubstring(lower(decision.plain_explanation), ...
                'not supported');
        end

        function runStopsAtMainWhenReserveIsNotApproved(testCase)
            plan = shortCheckpointPlan();
            cfg = neyer_settings();
            cfg.min_level = 0;
            cfg.max_level = 10;
            cfg.level_increment = 0.10;
            cfg.study_plan = plan;
            cfg.reserve_decision_fn = @(~) false;
            parameters = struct('mu_min', 0, 'mu_max', 10, 'sigma_guess', 1);
            outcomes = logical([true false true false true false]);

            record = run_loop(parameters, plan.total_articles, ...
                @(~, testNumber) outcomes(testNumber), cfg);

            testCase.verifyEqual(record.N, plan.main_articles);
            testCase.verifyEqual(record.status, 'paused');
            testCase.verifyEqual(record.stop_reason, 'reserve_not_authorized');
            testCase.verifyNumElements(record.checkpoint_decisions, 1);
        end

        function runUsesOnlyExplicitlyApprovedReserveGroup(testCase)
            plan = shortCheckpointPlan();
            cfg = neyer_settings();
            cfg.min_level = 0;
            cfg.max_level = 10;
            cfg.level_increment = 0.10;
            cfg.study_plan = plan;
            cfg.reserve_decision_fn = @(decision) ...
                strcmp(decision.next_checkpoint, 'reserve_1');
            parameters = struct('mu_min', 0, 'mu_max', 10, 'sigma_guess', 1);
            outcomes = logical([true false true false true false]);

            record = run_loop(parameters, plan.total_articles, ...
                @(~, testNumber) outcomes(testNumber), cfg);

            testCase.verifyEqual(record.N, ...
                plan.main_articles + plan.reserve_1_articles);
            testCase.verifyEqual(record.status, 'paused');
            testCase.verifyEqual(record.stop_reason, 'reserve_not_authorized');
            testCase.verifyNumElements(record.checkpoint_decisions, 2);
        end
    end
end

function plan = checkpointPlan()
plan = struct( ...
    'outcome', 'interaction', ...
    'reliability', 0.90, ...
    'confidence', 0.95, ...
    'accuracy_mm', 10, ...
    'minimum_gap_mm', 0, ...
    'maximum_gap_mm', 10, ...
    'main_articles', 20, ...
    'reserve_1_articles', 5, ...
    'reserve_2_articles', 5, ...
    'reachable_model', reachable_gap_model( ...
        struct('mode', 'regular', 'increment_mm', 0.10), 0, 10));
end

function plan = shortCheckpointPlan()
plan = checkpointPlan();
plan.main_articles = 3;
plan.reserve_1_articles = 2;
plan.reserve_2_articles = 1;
plan.total_articles = 6;
plan.accuracy_mm = 1e-6;
end

function result = referenceResult()
persistent savedResult
if isempty(savedResult)
    outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    parameters = struct('avg_low', 8.6, 'avg_high', 9.4, ...
        'spread_guess', 0.1);
    evalc('[savedResult,~]=run_test(parameters,20,@(~,testNumber)outcomes(testNumber));');
end
result = savedResult;
end
