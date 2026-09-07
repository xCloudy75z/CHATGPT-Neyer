classdef TestShrinkOnly < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addVariant(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'variants', 'shrink-only', 'functions')));
        end
    end

    methods (Test)
        function preservesPublishedTableOne(testCase)
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            expected = [1 1.2 1.4 1.8 2.6 4.2 3.4 3.8 4 4.1 4.28 4.52 ...
                        5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            params = struct('avg_low', .6, 'avg_high', 1.4, 'spread_guess', .1);
            [result, record] = run_test(params, 20, @(~, k) outcomes(k));
            testCase.verifyEqual(record.levels, expected, 'AbsTol', .005);
            testCase.verifyEqual([result.mu result.sigma], [5.3922 1.0412], 'AbsTol', 1e-3);
        end

        function contractsSigmaAcrossSeparatedProbeVisits(testCase)
            params = struct('avg_low', -2, 'avg_high', 2, 'spread_guess', 1);
            [~, record] = run_test(params, 20, @(x, ~) x >= .5, neyer_settings());
            sigmas = record.est_sigma(record.stage == 2);
            testCase.verifyTrue(any(abs(sigmas - .8) < 1e-12));
            testCase.verifyTrue(any(abs(sigmas - .64) < 1e-12));
        end
    end
end
