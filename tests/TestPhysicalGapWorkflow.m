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

        function measuredAverageIsUsedAsTheStatisticalGap(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',9.9,'sigma_guess',1);
            response=@(~,~)struct('outcome',true, ...
                'measurements',[4.98 5.00 5.01 5.00 5.00]);
            record=run_loop(params,1,response,cfg);

            testCase.verifyEqual(record.requested_levels,5.00,'AbsTol',1e-12);
            testCase.verifyEqual(record.levels,4.998,'AbsTol',1e-12);
            testCase.verifyEqual(record.measurements{1}, ...
                [4.98 5.00 5.01 5.00 5.00],'AbsTol',1e-12);
            testCase.verifyTrue(record.successes(1));
        end

        function repeatedReachableSettingMeasuresEachNewBuild(testCase)
            cfg=neyer_settings(); cfg.level_increment=0.10;
            params=struct('mu_min',0,'mu_max',10,'sigma_guess',1);
            response=@(gap,k)struct('outcome',false, ...
                'measurements',gap+[0 0.01*k 0 0 0]);
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
                'measurements', [gap gap gap gap]);

            [~, record] = run_physical_test(parameters, 3, response, cfg);

            testCase.verifyTrue(any(abs(record.requested_levels(1) - ...
                model.gaps_mm) < 1e-12));
            testCase.verifyEqual(record.resolution_sigma_floor, 0.030, ...
                'AbsTol', 1e-12);
        end
    end
end
