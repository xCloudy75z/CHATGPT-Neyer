classdef TestV19IndependentReaudit < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addCandidateAndSimulation(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'simulation')));
        end
    end

    methods (Test)
        function interactionProbabilityDecreasesWithGap(testCase)
            model=shape_model([4;5;6],5,1);
            testCase.verifyEqual(model.p, ...
                [0.841344746068543;0.5;0.158655253931457], ...
                'AbsTol',1e-12);
        end

        function stageOneUsesDirectionAndPriorBounds(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            cfg=neyer_settings();
            [afterInteraction,yesEstimate]=choose_stage(5,true,params,cfg);
            [afterNoInteraction,noEstimate]=choose_stage(5,false,params,cfg);
            testCase.verifyEqual(afterInteraction,7.5,'AbsTol',1e-12);
            testCase.verifyEqual(afterNoInteraction,2.5,'AbsTol',1e-12);
            testCase.verifyEqual([yesEstimate.stage noEstimate.stage],[1 1]);
        end

        function stageTwoSwitchesAtOneGuessedSigma(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            cfg=neyer_settings();
            [wideChoice,wideEstimate]=choose_stage([4;5.1], ...
                logical([true;false]),params,cfg);
            [~,thresholdEstimate]=choose_stage([4;5], ...
                logical([true;false]),params,cfg);
            testCase.verifyEqual(wideChoice,4.55,'AbsTol',1e-12);
            testCase.verifyEqual(wideEstimate.stage,1);
            testCase.verifyEqual(thresholdEstimate.stage,2);
        end

        function partTwoNeverReturnsToBisection(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1, ...
                'working_sigma',0.64,'part2_started',true);
            [~,estimate]=choose_stage([4;5.4],logical([true;false]), ...
                params,neyer_settings());
            testCase.verifyEqual(estimate.stage,2);
            testCase.verifyEqual(estimate.sigma,0.64,'AbsTol',1e-12);
        end

        function repeatedPartTwoTestsApplyPointEightShrink(testCase)
            params=struct('avg_low',-2,'avg_high',2,'spread_guess',1);
            cfg=neyer_settings(); cfg.min_level=-10; cfg.max_level=10;
            [~,record]=run_test(params,15,@(gap,~)gap<=-0.5,cfg);
            stageTwoSigma=record.est_sigma(record.stage==2);
            testCase.assertGreaterThanOrEqual(numel(stageTwoSigma),3);
            testCase.verifyEqual(stageTwoSigma(1:3),[1;0.8;0.64], ...
                'AbsTol',1e-12);
        end

        function sigmaFloorEqualsTwoPhysicalIncrements(testCase)
            params=struct('avg_low',4,'avg_high',6,'spread_guess',1);
            for increment=[0.05 0.10]
                cfg=neyer_settings(); cfg.level_increment=increment;
                cfg.min_level=0; cfg.max_level=10;
                cfg.resolution_sigma_floor_factor=2;
                response=@(gap,~)struct('outcome',gap<=5, ...
                    'measurements',repmat(gap,1,4));
                [~,record]=run_physical_test(params,30,response,cfg);
                stageTwoSigma=record.est_sigma(record.stage==2);
                testCase.assertNotEmpty(stageTwoSigma);
                testCase.verifyGreaterThanOrEqual(stageTwoSigma+1e-12, ...
                    2*increment);
                testCase.verifyEqual(stageTwoSigma(end),2*increment, ...
                    'AbsTol',1e-12);
                testCase.verifyEqual(record.resolution_sigma_floor, ...
                    2*increment,'AbsTol',1e-12);
            end
        end

        function strictOverlapRejectsATie(testCase)
            testCase.verifyFalse(has_overlap([4;4],logical([true;false])));
            testCase.verifyTrue(has_overlap([4.1;4],logical([true;false])));
        end

        function demoEstimateMatchesPublishedValues(testCase)
            demo=run_demo();
            testCase.verifyTrue(demo.is_match);
            testCase.verifyEqual(demo.got_mu,5.3922,'AbsTol',1e-3);
            testCase.verifyEqual(demo.got_sigma,1.0412,'AbsTol',1e-3);
        end

        function maximumLikelihoodReturnsFinitePositiveWidth(testCase)
            levels=[3;4;4.5;5;5.5;6;7];
            outcomes=logical([1;1;0;1;0;0;0]);
            [middle,width,likelihood]=best_fit(levels,outcomes,5,1);
            testCase.verifyTrue(all(isfinite([middle width likelihood])));
            testCase.verifyGreaterThan(width,0);
            testCase.verifyGreaterThan(loglik(levels,outcomes,middle,width), ...
                loglik(levels,~outcomes,middle,width));
        end

        function dOptimalPointMatchesIndependentKnownCase(testCase)
            cfg=neyer_settings(); cfg.grid_points=20001;
            [nextGap,determinant]=pick_next_level([-1.138;1.138],0,1,cfg);
            testCase.verifyEqual(nextGap,-1.138,'AbsTol',5e-4);
            testCase.verifyEqual(determinant,1.58946982,'AbsTol',1e-7);
        end

        function partTwoSelectsDifferentReachableUsefulGap(testCase)
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1, ...
                'working_sigma',0.8,'part2_started',true);
            cfg=neyer_settings(); cfg.level_increment=0.10;
            measured=[5.002;5.098]; reachable=[5.00;5.10];
            nextGap=choose_stage(measured,logical([true;false]), ...
                params,cfg,reachable);
            testCase.verifyGreaterThan(abs(nextGap-5.00),1e-12);
            testCase.verifyGreaterThan(abs(nextGap-5.10),1e-12);
            testCase.verifyEqual(nextGap/0.10,round(nextGap/0.10), ...
                'AbsTol',1e-12);
        end

        function fourAndFiveReadingsUseTheirMean(testCase)
            four=parse_physical_response('2.50, 2.50, 2.49, 2.51',true);
            five=parse_physical_response('2.50 2.50 2.49 2.52 2.48',false);
            testCase.verifyEqual(mean(four.measurements),2.50,'AbsTol',1e-12);
            testCase.verifyEqual(mean(five.measurements),2.498,'AbsTol',1e-12);

            params=struct('mu_min',0,'mu_max',9.9,'sigma_guess',1);
            cfg=neyer_settings(); cfg.level_increment=0.10;
            record=run_loop(params,1,@(~,~)five,cfg);
            testCase.verifyEqual(record.requested_levels,5.00,'AbsTol',1e-12);
            testCase.verifyEqual(record.levels,2.498,'AbsTol',1e-12);
        end

        function bothConfirmedIncrementsProduceReachableRequests(testCase)
            params=struct('avg_low',0,'avg_high',9.9,'spread_guess',1);
            for increment=[0.05 0.10]
                cfg=neyer_settings(); cfg.level_increment=increment;
                response=@(gap,~)struct('outcome',gap<=5, ...
                    'measurements',repmat(gap,1,4));
                [~,record]=run_physical_test(params,12,response,cfg);
                units=record.requested_levels/increment;
                testCase.verifyEqual(units,round(units),'AbsTol',1e-10);
                testCase.verifyGreaterThanOrEqual(record.requested_levels,0);
                testCase.verifyLessThanOrEqual(record.requested_levels,10);
            end
        end

        function eachRepeatedSettingKeepsANewMeasurementRecord(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            response=@(gap,testNumber)struct('outcome',false, ...
                'measurements',gap+[0 0.001*testNumber 0 0]);
            record=run_loop(params,20,response,cfg);
            repeated=find(record.requested_levels==0);
            testCase.assertNumElements(repeated,2);
            testCase.verifyNotEqual(record.measurements{repeated(1)}, ...
                record.measurements{repeated(2)});
        end

        function contradictoryMinimumPausesAfterOneConfirmation(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            record=run_loop(params,20,@(~,~)false,neyer_settings());
            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason,'no_interaction_at_min_gap');
            testCase.verifyEqual(sum(record.requested_levels==0),2);
            testCase.verifyLessThan(record.N,20);
        end

        function contradictoryMaximumPausesAfterOneConfirmation(testCase)
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            record=run_loop(params,20,@(~,~)true,neyer_settings());
            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason,'interaction_at_max_gap');
            testCase.verifyEqual(sum(record.requested_levels==10),2);
            testCase.verifyLessThan(record.N,20);
        end

        function physicalOutcomeUsesActualBuiltGap(testCase)
            % Catches the old simulation defect where the response used the
            % requested setting even after build variation changed the gap.
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1);
            cfg=neyer_settings();
            cfg.min_level=0; cfg.max_level=10;
            cfg.level_increment=0.10;
            cfg.resolution_sigma_floor_factor=2;
            thresholds=[5.02;5.02;5.02];
            readingErrors=zeros(4,3);
            buildErrors=[0.05;0;0];

            record=simulate_v19_physical_run(params,3,thresholds, ...
                readingErrors,buildErrors,cfg);

            testCase.verifyEqual(record.reachable_levels(1),5.00,'AbsTol',1e-12);
            testCase.verifyEqual(record.actual_levels(1),5.05,'AbsTol',1e-12);
            testCase.verifyFalse(record.successes(1), ...
                'Interaction must be decided from the actual 5.05 mm gap.');
        end

        function processShardsEqualTheUnshardedStudy(testCase)
            folder=testCase.createTemporaryFolder();
            common=struct('budgets',6,'true_sigmas',0.2,'increments',[0.05 0.10], ...
                'floor_factors',2,'reading_sds',0.015,'reading_counts',4, ...
                'build_sd_factors',0.5,'grid_points',101,'seed',2468);

            fullOptions=common;
            fullOptions.output_file=fullfile(folder,'full.csv');
            fullOptions.scenario_shard_index=1;
            fullOptions.scenario_shard_count=1;
            run_combined_physical_study(4,fullOptions);

            shardOne=common; shardOne.output_file=fullfile(folder,'shard-1.csv');
            shardOne.scenario_shard_index=1; shardOne.scenario_shard_count=2;
            run_combined_physical_study(4,shardOne);
            shardTwo=common; shardTwo.output_file=fullfile(folder,'shard-2.csv');
            shardTwo.scenario_shard_index=2; shardTwo.scenario_shard_count=2;
            run_combined_physical_study(4,shardTwo);

            fullRows=sortrows(readtable(fullOptions.output_file),'increment');
            shardRows=sortrows([readtable(shardOne.output_file); ...
                readtable(shardTwo.output_file)],'increment');
            testCase.verifyEqual(height(fullRows),2);
            testCase.verifyEqual(height(shardRows),2);
            fullRows(:,{'execution_mode','scenario_shard_index', ...
                'scenario_shard_count'})=[];
            shardRows(:,{'execution_mode','scenario_shard_index', ...
                'scenario_shard_count'})=[];
            testCase.verifyEqual(shardRows,fullRows);
        end
    end
end
