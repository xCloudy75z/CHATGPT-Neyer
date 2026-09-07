classdef TestBaselineCharacterization < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBaseline(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'baseline', 'functions')));
        end
    end

    methods (Test)
        function locksCurrentStageSequenceAndStageTwoSigma(testCase)
            % Catches relabeling or activation of sigma shrink in the preserved baseline.
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);

            [~, record] = run_test(params, 20, @(~, k) outcomes(k));

            testCase.verifyEqual(record.stage', [ones(1, 6), 2*ones(1, 5), 3*ones(1, 9)]);
            testCase.verifyEqual(record.est_sigma(record.stage == 2), 0.10*ones(5, 1), ...
                'AbsTol', eps);
        end

        function roundsEveryFeedbackLevelToTwoDecimals(testCase)
            % Catches full-precision levels leaking into the sequential history.
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);

            [~, record] = run_test(params, 20, @(~, k) outcomes(k));

            testCase.verifyEqual(record.levels * 100, round(record.levels * 100), ...
                'AbsTol', 100*eps(max(record.levels)));
        end

        function boundaryTieIsNotOverlap(testCase)
            % Catches treating equal-level opposite outcomes as finite-MLE overlap.
            testCase.verifyFalse(has_overlap([1; 1], logical([0; 1])));
            testCase.verifyTrue(has_overlap([1; 0.99], logical([0; 1])));
        end

        function runConsumesExactlyTheRequestedBudget(testCase)
            % Catches accidental early stopping after overlap or an off-by-one run.
            calls = 0;
            params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
            [~, record] = run_test(params, 7, @outcome);
            testCase.verifyEqual(calls, 7);
            testCase.verifyNumElements(record.levels, 7);

            function value = outcome(~, k)
                calls = calls + 1;
                value = mod(k, 2) == 0;
            end
        end
    end
end
