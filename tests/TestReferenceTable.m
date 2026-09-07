classdef TestReferenceTable < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBaseline(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'baseline', 'functions')));
        end
    end

    methods (Test)
        function reproducesPublishedTableOneTrajectory(testCase)
            % Catches changes to search, D-optimal selection, or rounding that
            % move any of Neyer's independently published stimulus levels.
            outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            expectedLevels = [ ...
                1.00 1.20 1.40 1.80 2.60 4.20 3.40 3.80 4.00 4.10 ...
                4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);

            [result, record] = run_test(params, 20, @(~, k) outcomes(k));

            testCase.verifyEqual(record.successes, outcomes');
            testCase.verifyEqual(record.levels, expectedLevels, 'AbsTol', 0.005);
            testCase.verifyEqual(result.mu, 5.3922, 'AbsTol', 1e-3);
            testCase.verifyEqual(result.sigma, 1.0412, 'AbsTol', 1e-3);
        end
    end
end
