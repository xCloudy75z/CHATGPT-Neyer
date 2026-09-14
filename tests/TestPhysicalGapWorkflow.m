classdef TestPhysicalGapWorkflow < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function popupRequestIsRoundedToConfiguredIncrement(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',9.9,'sigma_guess',1);
            record=run_loop(params,1,@(~,~)true,cfg);

            testCase.verifyEqual(record.raw_requested_levels,4.95,'AbsTol',1e-12);
            testCase.verifyEqual(record.requested_levels,5.00,'AbsTol',1e-12);
            testCase.verifyEqual(record.levels,5.00,'AbsTol',1e-12);
        end

        function singleMeasurementIsUsedAsTheStatisticalGap(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',9.9,'sigma_guess',1);
            response=@(~,~)struct('outcome',true,'measurements',4.998);
            record=run_loop(params,1,response,cfg);

            testCase.verifyEqual(record.requested_levels,5.00,'AbsTol',1e-12);
            testCase.verifyEqual(record.levels,4.998,'AbsTol',1e-12);
            testCase.verifyEqual(record.measurements{1},4.998,'AbsTol',1e-12);
            testCase.verifyTrue(record.successes(1));
        end

        function repeatedReachableSettingMeasuresEachNewBuild(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            response=@(gap,k)struct('outcome',false, ...
                'measurements',gap+0.01*k);
            record=run_loop(params,20,response,cfg);

            atZero=find(record.requested_levels==0);
            testCase.assertNumElements(atZero,2);
            testCase.verifyNotEqual(record.levels(atZero(1)), ...
                                    record.levels(atZero(2)));
            testCase.verifyNotEqual(record.measurements{atZero(1)}, ...
                                    record.measurements{atZero(2)});
        end

        function measuredMeanCannotMakeAReachableSettingLookNew(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            measured=[5.002;5.098];
            reachable=[5.00;5.10];
            outcomes=logical([true;false]);
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1, ...
                'working_sigma',0.8,'part2_started',true);

            next=choose_stage(measured,outcomes,params,cfg,reachable);

            testCase.verifyGreaterThan(abs(next-5.00),1e-12);
            testCase.verifyGreaterThan(abs(next-5.10),1e-12);
            testCase.verifyEqual(next/cfg.level_increment, ...
                round(next/cfg.level_increment),'AbsTol',1e-12);
        end

        function irregularPhysicalModelRequestsOnlyListedGap(testCase)
            cfg = neyer_settings();
            cfg.min_level = 0;
            cfg.max_level = 1;
            cfg.reachable_model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', [0 0.49 0.52 1]), 0, 1);
            params = struct('mu_min', 0, 'mu_max', 0.99, 'sigma_guess', 0.1);

            record = run_loop(params, 1, @(~, ~) true, cfg);

            testCase.verifyTrue(any(abs(record.requested_levels(1) - ...
                cfg.reachable_model.gaps_mm) < 1e-12));
            testCase.verifyEqual(record.requested_levels(1), 0.49, ...
                'AbsTol', 1e-12);
        end

        function physicalCombinationModeAcceptsFifteenMicronResolution(testCase)
            setup = struct('mode', 'combinations', ...
                'component_names', {{'foil layer', '0.50 mm spacer'}}, ...
                'component_mm', [0.015 0.50], 'maximum_counts', [4 2]);
            model = reachable_gap_model(setup, 0, 1);
            cfg = neyer_settings();
            cfg.min_level = 0;
            cfg.max_level = 1;
            cfg.usable_resolution = 0.015;
            cfg.reachable_model = model;
            parameters = struct('avg_low', 0, 'avg_high', 1, ...
                'spread_guess', 0.1);
            response = @(gap, ~) struct('outcome', true, ...
                'measurements', gap);

            [~, record] = run_physical_test(parameters, 3, response, cfg);

            testCase.verifyTrue(any(abs(record.requested_levels(1) - ...
                model.gaps_mm) < 1e-12));
            testCase.verifyEqual(record.resolution_sigma_floor, 0.030, ...
                'AbsTol', 1e-12);
        end

        function stageTwoTreatsDecimalBoundaryAsEqual(testCase)
            for increment=[0.10 0.05]
                cfg=neyer_settings();
                cfg.level_increment=increment;
                cfg.min_level=0;
                measured=[3*increment+eps(3*increment);5*increment];
                reachable=[3*increment;5*increment];
                outcomes=logical([true;false]);
                params=struct('mu_min',2*increment,'mu_max',6*increment, ...
                    'sigma_guess',increment,'working_sigma',increment/10, ...
                    'part2_started',true);

                next=choose_stage(measured,outcomes,params,cfg,reachable);

                tolerance=1e-10;
                testCase.verifyTrue(next < reachable(1)-tolerance || ...
                    next > reachable(2)+tolerance, ...
                    'A decimal representation of a boundary is not strict overlap.');
            end
        end

        function reachableListExcludesCandidatesWithinBoundaryTolerance(testCase)
            model=struct('gaps_mm',[0.30;0.30+0.5e-10;0.50;0.60], ...
                'instructions',strings(4,1), ...
                'comparison_tolerance_mm',1e-10);

            gap=select_reachable_request(0.30,model,[],false,[0.30 0.50]);

            testCase.verifyEqual(gap,0.60,'AbsTol',1e-12);
        end

        function stageTwoUsesActualIrregularReachableCandidate(testCase)
            model=reachable_gap_model(struct('mode','list', ...
                'gaps_mm',[0.30 0.35 0.50]),0.30,0.50);
            cfg=neyer_settings();
            cfg.min_level=0.30;
            cfg.max_level=0.50;
            cfg.usable_resolution=0.05;
            cfg.stage2_bisect_width_sigmas=2;
            cfg.reachable_model=model;
            params=struct('avg_low',0.20,'avg_high',0.40,'spread_guess',0.03);
            outcomes=logical([true;false;false]);
            response=@(gap,k)struct('outcome',outcomes(k),'measurements',gap);

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.requested_levels,[0.30;0.35;0.50], ...
                'AbsTol',1e-12);
        end

        function stageTwoUsesActualCombinationCandidate(testCase)
            setup=struct('mode','combinations', ...
                'component_names',{{'0.15 mm part','0.20 mm part'}}, ...
                'component_mm',[0.15 0.20],'maximum_counts',[2 1]);
            model=reachable_gap_model(setup,0.30,0.50);
            cfg=neyer_settings();
            cfg.min_level=0.30;
            cfg.max_level=0.50;
            cfg.usable_resolution=0.05;
            cfg.stage2_bisect_width_sigmas=2;
            cfg.reachable_model=model;
            params=struct('avg_low',0.20,'avg_high',0.40,'spread_guess',0.03);
            outcomes=logical([true;false;false]);
            response=@(gap,k)struct('outcome',outcomes(k),'measurements',gap);

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.requested_levels,[0.30;0.35;0.50], ...
                'AbsTol',1e-12);
            testCase.verifySubstring(record.requested_instructions(3), ...
                '0.15 mm part');
        end

        function stageTwoPausesWhenNoStrictlyUsefulCandidateExists(testCase)
            model=reachable_gap_model(struct('mode','list', ...
                'gaps_mm',[0.30 0.35]),0.30,0.35);
            cfg=neyer_settings();
            cfg.min_level=0.30;
            cfg.max_level=0.35;
            cfg.usable_resolution=0.05;
            cfg.stage2_bisect_width_sigmas=2;
            cfg.reachable_model=model;
            params=struct('avg_low',0.20,'avg_high',0.40,'spread_guess',0.03);
            outcomes=logical([true;false]);
            response=@(gap,k)struct('outcome',outcomes(k),'measurements',gap);

            [result,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason,'no_different_reachable_gap');
            testCase.verifyEqual(numel(record.requested_levels),2);
            testCase.verifyEqual(result.status,'paused');
        end

        function crossedRequestedOutcomesPauseAndPreserveMeasuredData(testCase)
            model=reachable_gap_model(struct('mode','list', ...
                'gaps_mm',[0.30 0.35 0.50 0.60]),0.30,0.60);
            cfg=neyer_settings();
            cfg.min_level=0.30;
            cfg.max_level=0.60;
            cfg.usable_resolution=0.05;
            cfg.stage2_bisect_width_sigmas=10;
            cfg.reachable_model=model;
            params=struct('avg_low',0.20,'avg_high',0.40,'spread_guess',0.03);
            outcomes=logical([true;false;true]);
            measured=[0.20;0.40;0.25];
            response=@(~,k)struct('outcome',outcomes(k),'measurements',measured(k));

            [result,record]=run_physical_test(params,4,response,cfg);

            testCase.verifyEqual(record.status,'paused');
            testCase.verifyEqual(record.stop_reason, ...
                'requested_outcome_order_conflict');
            testCase.verifyEqual(record.requested_levels,[0.30;0.35;0.50], ...
                'AbsTol',1e-12);
            testCase.verifyEqual(record.levels,measured,'AbsTol',1e-12);
            testCase.verifyEqual(result.status,'paused');
        end
    end
end
