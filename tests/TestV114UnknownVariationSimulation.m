classdef TestV114UnknownVariationSimulation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectCode(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'application', 'source')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'tools')));
        end
    end

    methods (Test)
        function deterministicStudyUsesUnknownRouteAndReachableRequests(testCase)
            summary = v114_simulate_study(5, 0.8, 0.10, 62, 11401);
            testCase.verifyEqual(summary.tests_requested, 62);
            testCase.verifyEqual(summary.search_scale_source, 'automatic');
            testCase.verifyTrue(summary.all_requests_reachable);
            testCase.verifyTrue(summary.all_requests_in_bounds);
            testCase.verifyTrue(summary.no_immediate_duplicate);
            testCase.verifyTrue(summary.has_overlap);
            testCase.verifyTrue(isfinite(summary.estimated_middle_mm));
            testCase.verifyTrue(isfinite(summary.estimated_variation_mm));
        end

        function sameSeedProducesSameStudy(testCase)
            first = v114_simulate_study(5, 0.8, 0.20, 20, 11402);
            second = v114_simulate_study(5, 0.8, 0.20, 20, 11402);
            testCase.verifyEqual(first, second);
        end
    end
end
