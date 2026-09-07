classdef TestGapReliability < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function interactionProbabilityFallsAsGapIncreases(testCase)
            result=reference_result();
            low=reliability_query(result,'interaction','probability_at',2,0.95);
            high=reliability_query(result,'interaction','probability_at',8,0.95);

            testCase.verifyGreaterThan(low.probability,0.99);
            testCase.verifyLessThan(high.probability,0.001);
            testCase.verifyGreaterThan(low.probability,high.probability);
        end

        function noInteractionProbabilityRisesAsGapIncreases(testCase)
            result=reference_result();
            low=reliability_query(result,'no_interaction','probability_at',2,0.95);
            high=reliability_query(result,'no_interaction','probability_at',8,0.95);

            testCase.verifyLessThan(low.probability,0.01);
            testCase.verifyGreaterThan(high.probability,0.999);
            testCase.verifyLessThan(low.probability,high.probability);
        end

        function targetInteractionGapUsesSmallGapSide(testCase)
            result=reference_result();
            q=reliability_query(result,'interaction','gap_for',0.999,0.95);

            testCase.verifyEqual(q.gap,1.3902,'AbsTol',0.002);
            testCase.verifyLessThan(q.raw_bound,q.gap);
        end

        function targetNoInteractionGapUsesLargeGapSide(testCase)
            result=reference_result();
            q=reliability_query(result,'no_interaction','gap_for',0.999,0.95);

            testCase.verifyEqual(q.gap,7.8254,'AbsTol',0.002);
            testCase.verifyGreaterThan(q.raw_bound,q.gap);
        end

        function outOfRangeInteractionBoundaryIsNotUsable(testCase)
            q=reliability_query(reference_result(),'interaction','gap_for',0.999,0.95);

            testCase.verifyEqual(q.raw_bound,-2.7455,'AbsTol',0.003);
            testCase.verifyTrue(isnan(q.bound));
            testCase.verifyFalse(q.bound_established);
            testCase.verifyEqual(q.permitted_range,[0 10]);
        end

        function outOfRangeNoInteractionBoundaryIsNotUsable(testCase)
            q=reliability_query(reference_result(),'no_interaction','gap_for',0.999,0.95);

            testCase.verifyEqual(q.raw_bound,11.4707,'AbsTol',0.003);
            testCase.verifyTrue(isnan(q.bound));
            testCase.verifyFalse(q.bound_established);
            testCase.verifyEqual(q.permitted_range,[0 10]);
        end

        function lowerConfidenceNeverCreatesStrongerInteractionClaim(testCase)
            result = reference_result();
            low = reliability_query(result, 'interaction', 'gap_for', 0.90, 0.10);
            middle = reliability_query(result, 'interaction', 'gap_for', 0.90, 0.50);
            high = reliability_query(result, 'interaction', 'gap_for', 0.90, 0.95);
            testCase.verifyGreaterThanOrEqual(low.raw_bound, middle.raw_bound);
            testCase.verifyGreaterThanOrEqual(middle.raw_bound, high.raw_bound);
        end

        function lowerConfidenceNeverCreatesStrongerNoInteractionClaim(testCase)
            result = reference_result();
            low = reliability_query(result, 'no_interaction', 'gap_for', 0.90, 0.10);
            middle = reliability_query(result, 'no_interaction', 'gap_for', 0.90, 0.50);
            high = reliability_query(result, 'no_interaction', 'gap_for', 0.90, 0.95);
            testCase.verifyLessThanOrEqual(low.raw_bound, middle.raw_bound);
            testCase.verifyLessThanOrEqual(middle.raw_bound, high.raw_bound);
        end
    end
end

function result=reference_result()
    outcomes=logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    params=struct('avg_low',8.6,'avg_high',9.4,'spread_guess',0.1);
    evalc('[result,~]=run_test(params,20,@(~,k)outcomes(k));');
end
