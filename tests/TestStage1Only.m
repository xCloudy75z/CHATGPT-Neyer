classdef TestStage1Only < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addVariant(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'variants', 'stage1-only', 'functions')));
        end
    end
    methods (Test)
        function usesUpperPriorBoundWhenItReachesFarther(testCase)
            p = struct('mu_min', 0, 'mu_max', 100, 'sigma_guess', 1);
            [x, ~] = choose_stage(50, false, p, neyer_settings());
            testCase.verifyEqual(x, 75, 'AbsTol', eps(75));
        end
        function usesLowerPriorBoundWhenItReachesFarther(testCase)
            p = struct('mu_min', -100, 'mu_max', 0, 'sigma_guess', 1);
            [x, ~] = choose_stage(-50, true, p, neyer_settings());
            testCase.verifyEqual(x, -75, 'AbsTol', eps(75));
        end
        function preservesPublishedTableOne(testCase)
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            expected = [1 1.2 1.4 1.8 2.6 4.2 3.4 3.8 4 4.1 4.28 4.52 ...
                        5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            p = struct('avg_low', .6, 'avg_high', 1.4, 'spread_guess', .1);
            [result, record] = run_test(p, 20, @(~, k) outcomes(k));
            testCase.verifyEqual(record.levels, expected, 'AbsTol', .005);
            testCase.verifyEqual([result.mu result.sigma], [5.3922 1.0412], 'AbsTol', 1e-3);
        end
    end
end
