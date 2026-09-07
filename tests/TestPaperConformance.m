classdef TestPaperConformance < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addAuditedImplementation(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'application', 'source')));
        end
    end

    methods (Test)
        function stageOneUsesPriorMeanBoundWhenItReachesFarther(testCase)
            % Gap response decreases. After an initial no-interaction result,
            % choose the lower prior-bound midpoint when it reaches farthest.
            params = struct('mu_min', 0, 'mu_max', 100, 'sigma_guess', 1);
            [actual, ~] = choose_stage(50, false, params, neyer_settings());
            testCase.verifyEqual(actual, 25, 'AbsTol', eps(25));
        end

        function partOneBisectsWhileSeparationExceedsSigma(testCase)
            % Neyer Part 1 remains a binary search when Diff > SigmaG.
            params = struct('mu_min', -2, 'mu_max', 2, 'sigma_guess', 1);
            [actual, est] = choose_stage([0; 1.2], logical([1; 0]), ...
                params, neyer_settings());
            testCase.verifyEqual(actual, 0.6, 'AbsTol', 1e-12);
            testCase.verifyEqual(est.stage, 1);
        end

        function eachNoOverlapPartTwoTestShrinksWorkingSigma(testCase)
            % Neyer Part 2 multiplies SigmaG by .8 after every specimen while
            % outcomes remain separated; a threshold callback guarantees that.
            params = struct('avg_low', -2, 'avg_high', 2, 'spread_guess', 1);
            cfg = neyer_settings();
            cfg.min_level = -10;
            cfg.max_level = 10;
            [~, record] = run_test(params, 15, @(x, ~) x <= -0.5, cfg);
            partTwoSigma = record.est_sigma(record.stage == 2);
            testCase.verifyGreaterThanOrEqual(numel(partTwoSigma), 3);
            testCase.verifyEqual(partTwoSigma(1:3), [1; 0.8; 0.64], 'AbsTol', 1e-12);
        end
    end
end
