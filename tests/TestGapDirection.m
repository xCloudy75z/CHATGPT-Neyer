classdef TestGapDirection < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function publishedDemoUsesDecreasingGapOutcomes(testCase)
            demo=run_demo();
            testCase.verifyTrue(demo.result.has_overlap);
            testCase.verifyTrue(demo.is_match);
            testCase.verifyEqual(demo.got_mu,5.3922,'AbsTol',1e-3);
            testCase.verifyEqual(demo.got_sigma,1.0412,'AbsTol',1e-3);
        end
        function interactionProbabilityFallsAsGapIncreases(testCase)
            model=shape_model([3;4;5],4,1);
            expected=[0.841344746068543;0.5;0.158655253931457];
            testCase.verifyEqual(model.p,expected,'AbsTol',1e-12);
        end


        function stageOneMovesToLargerGapAfterInteraction(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            [next,~]=choose_stage(5,true,params,neyer_settings());
            testCase.verifyGreaterThan(next,5);
        end

        function stageOneMovesToSmallerGapAfterNoInteraction(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            [next,~]=choose_stage(5,false,params,neyer_settings());
            testCase.verifyLessThan(next,5);
        end


        function ordinaryDecreasingOrderIsNotOverlap(testCase)
            testCase.verifyFalse(has_overlap([3;5],logical([1;0])));
        end

        function largeGapInteractionBeyondSmallGapNoIsOverlap(testCase)
            testCase.verifyTrue(has_overlap([3;5],logical([0;1])));
        end


        function stageTwoBisectsDecreasingGapBracket(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            [next,est]=choose_stage([3;5],logical([1;0]),params,neyer_settings());
            testCase.verifyEqual(next,4,'AbsTol',1e-12);
            testCase.verifyEqual(est.stage,1);
        end


        function mirroredPublishedSequenceMatchesDecreasingGap(testCase)
            outcomes=logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            original=[1 1.2 1.4 1.8 2.6 4.2 3.4 3.8 4 4.1 4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            expectedLevels=10-original;
            params=struct('avg_low',8.6,'avg_high',9.4,'spread_guess',0.1);
            [result,record]=run_test(params,20,@(~,k)outcomes(k));
            testCase.verifyEqual(record.levels,expectedLevels,'AbsTol',0.005);
            testCase.verifyEqual(result.mu,10-5.3922,'AbsTol',1e-3);
            testCase.verifyEqual(result.sigma,1.0412,'AbsTol',1e-3);
        end


        function reportProvidesGapSpecificTailFields(testCase)
            outcomes=logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            params=struct('avg_low',8.6,'avg_high',9.4,'spread_guess',0.1);
            [result,~]=run_test(params,20,@(~,k)outcomes(k));
            testCase.verifyTrue(isfield(result,'high_interaction_gap'));
            testCase.verifyTrue(isfield(result,'negligible_interaction_gap'));
        end


        function reportUsesGapSpecificLanguage(testCase)
            outcomes=logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            params=struct('avg_low',8.6,'avg_high',9.4,'spread_guess',0.1);
            text=evalc('run_test(params,20,@(~,k)outcomes(k));');
            testCase.verifySubstring(text,'HIGH-INTERACTION gap');
            testCase.verifySubstring(text,'NEGLIGIBLE-INTERACTION gap');
            testCase.verifyFalse(contains(text,'ALL-FIRE'));
            testCase.verifyFalse(contains(text,'NO-FIRE'));
        end


        function recommendationsStayInsidePermittedGapRange(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            cfg=neyer_settings();
            lowSearch=run_loop(params,12,@(~,~)false,cfg);
            highSearch=run_loop(params,12,@(~,~)true,cfg);
            testCase.verifyGreaterThanOrEqual(lowSearch.levels,0);
            testCase.verifyLessThanOrEqual(highSearch.levels,10);
        end


        function impossibleConfidenceEdgesAreReportedAsNotEstablished(testCase)
            outcomes=logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
            params=struct('avg_low',8.6,'avg_high',9.4,'spread_guess',0.1);
            text=evalc('run_test(params,20,@(~,k)outcomes(k));');
            testCase.verifySubstring(text,'not established within the permitted 0.00-10.00 mm range');
            testCase.verifyFalse(contains(text,'gaps at or below -'));
            testCase.verifyFalse(contains(text,'gaps at or above 11.'));
        end
    end
end
