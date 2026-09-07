classdef TestProposedNeyer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProposed(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'proposed', 'functions')));
        end
    end

    methods (Test)
        function stageOneUsesPriorMeanBoundWhenItReachesFarther(testCase)
            params = struct('mu_min', 0, 'mu_max', 100, 'sigma_guess', 1);
            [actual, ~] = choose_stage(50, false, params, neyer_settings());
            testCase.verifyEqual(actual, 75, 'AbsTol', eps(75));
        end

        function partOneBisectsWhileSeparationExceedsSigma(testCase)
            params = struct('mu_min', -2, 'mu_max', 2, 'sigma_guess', 1);
            [actual, est] = choose_stage([0; 1.2], logical([0; 1]), ...
                params, neyer_settings());
            testCase.verifyEqual(actual, 0.6, 'AbsTol', 1e-12);
            testCase.verifyEqual(est.stage, 1);
        end

        function successivePartTwoVisitsShrinkWorkingSigma(testCase)
            params = struct('avg_low', -2, 'avg_high', 2, 'spread_guess', 1);
            [~, record] = run_test(params, 15, @(x, ~) x >= 0.5, neyer_settings());
            partTwoSigma = record.est_sigma(record.stage == 2);
            testCase.verifyGreaterThanOrEqual(numel(partTwoSigma), 3);
            testCase.verifyEqual(partTwoSigma(1:3), [1; 0.8; 0.64], 'AbsTol', 1e-12);
        end

        function partTwoNeverReturnsToPartOneBisection(testCase)
            params = struct('avg_low', -2, 'avg_high', 2, 'spread_guess', 1);
            [~, record] = run_test(params, 15, @(x, ~) x >= 0.5, neyer_settings());
            firstPartTwo = find(record.stage == 2, 1, 'first');
            testCase.assertNotEmpty(firstPartTwo);
            testCase.verifyEqual(record.stage(firstPartTwo:end), ...
                2 * ones(numel(record.stage(firstPartTwo:end)), 1));
        end

        function preservesPublishedTableOne(testCase)
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            expectedLevels = [ ...
                1.00 1.20 1.40 1.80 2.60 4.20 3.40 3.80 4.00 4.10 ...
                4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
            [result, record] = run_test(params, 20, @(~, k) outcomes(k));
            testCase.verifyEqual(record.levels, expectedLevels, 'AbsTol', 0.005);
            testCase.verifyEqual(result.mu, 5.3922, 'AbsTol', 1e-3);
            testCase.verifyEqual(result.sigma, 1.0412, 'AbsTol', 1e-3);
        end
    end
end
