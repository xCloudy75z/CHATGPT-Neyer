classdef TestPhysicalRunEntryPoint < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function physicalRunRequiresAnExplicitIncrement(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings();
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);

            testCase.verifyError( ...
                @()run_physical_test(params,1,response,cfg), ...
                'run_physical_test:badLevelIncrement');
        end

        function physicalRunRejectsNonpositiveOrNonfiniteIncrement(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);
            invalid={0,-0.1,NaN,Inf};

            for k=1:numel(invalid)
                cfg=neyer_settings(); cfg.level_increment=invalid{k};
                testCase.verifyError( ...
                    @()run_physical_test(params,1,response,cfg), ...
                    'run_physical_test:badLevelIncrement');
            end
        end

        function physicalRunAcceptsSupportedEquipmentIncrements(testCase)
            params=struct('avg_low',0,'avg_high',9.9,'spread_guess',1);
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);

            for increment=[0.05 0.10]
                cfg=neyer_settings(); cfg.level_increment=increment;
                [~,record]=run_physical_test(params,3,response,cfg);
                testCase.verifyEqual( ...
                    record.requested_levels/increment, ...
                    round(record.requested_levels/increment), ...
                    'AbsTol',1e-10);
                testCase.verifyGreaterThanOrEqual(record.requested_levels,0);
                testCase.verifyLessThanOrEqual(record.requested_levels,10);
            end
        end

        function physicalRunDoesNotAcceptBooleanOnlyResponse(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings(); cfg.level_increment=0.10;

            testCase.verifyError( ...
                @()run_physical_test(params,3,@(~,~)true,cfg), ...
                'run_physical_test:measurementsRequired');
        end

        function physicalRunDefaultsToTwoIncrementSigmaFloor(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings(); cfg.level_increment=0.10;
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.resolution_sigma_floor_factor,2);
            testCase.verifyEqual(record.resolution_sigma_floor,0.20, ...
                'AbsTol',1e-12);
        end

        function foilThicknessDoesNotControlSigmaFloor(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings();
            cfg.usable_resolution=0.05;
            cfg.foil_thickness=0.015;
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.usable_resolution,0.05, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(record.foil_thickness,0.015, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(record.resolution_sigma_floor,0.10, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(record.requested_levels/0.05, ...
                round(record.requested_levels/0.05),'AbsTol',1e-10);
        end

        function physicalModeAlwaysEnforcesTwoResolutionFloor(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings();
            cfg.usable_resolution=0.05;
            cfg.resolution_sigma_floor_factor=1;
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap);

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.resolution_sigma_floor_factor,2);
            testCase.verifyEqual(record.resolution_sigma_floor,0.10, ...
                'AbsTol',1e-12);
        end

        function physicalResultCarriesTheCompleteMeasurementRecord(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings(); cfg.usable_resolution=0.05;
            cfg.foil_thickness=0.015;
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap+0.01);

            [result,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(result.requested_levels,record.requested_levels);
            testCase.verifyEqual(result.measurements,record.measurements);
            testCase.verifyEqual(result.usable_resolution,0.05,'AbsTol',1e-12);
            testCase.verifyEqual(result.foil_thickness,0.015,'AbsTol',1e-12);
        end

        function physicalResultKeepsOneReadingWithoutRedundantUncertaintyField(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            cfg=neyer_settings(); cfg.usable_resolution=0.05;
            response=@(gap,~)struct('outcome',true, ...
                'measurements',gap+0.02);

            [result,~]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(result.measurement_count,ones(3,1));
            testCase.verifyFalse(isfield(result,'measurement_uncertainty'));
        end

        function stageTwoKeepsTheNearestUsefulReachableRequest(testCase)
            % Regression: the physical Stage-2 safeguard must not replace an
            % already useful D-optimal request with the first grid point past
            % the current bracket.
            levels=[1.00;1.20;1.40;1.80;2.60;4.20;3.40;3.80;4.00;4.10];
            outcomes=logical([1;1;1;1;1;0;1;1;1;1]);
            params=struct('mu_min',0.6,'mu_max',1.4,'sigma_guess',0.10, ...
                'working_sigma',0.10,'part2_started',false);

            cfg=neyer_settings();
            cfg.level_increment=0.01;
            [nextAtOneHundredth,estimate]=choose_stage( ...
                levels,outcomes,params,cfg,levels);
            testCase.verifyEqual(estimate.stage,2);
            testCase.verifyEqual(nextAtOneHundredth,4.28,'AbsTol',0.005);

            cfg.level_increment=0.05;
            nextAtFiveHundredths=choose_stage( ...
                levels,outcomes,params,cfg,levels);
            testCase.verifyEqual(nextAtFiveHundredths,4.30,'AbsTol',1e-12);
        end

        function physicalPaperReplayExercisesTheNormalRunPath(testCase)
            % The reference values are a known-answer calculator check. The
            % production route must calculate them; it must not contain a
            % table lookup or a test-number exception.
            expectedLevels=[ ...
                1.00 1.20 1.40 1.80 2.60 4.20 3.40 3.80 4.00 4.10 ...
                4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
            outcomes=logical([ ...
                1 1 1 1 1 0 1 1 1 1 1 1 0 1 0 1 0 0 0 0]);
            parsed=parse_run_inputs({ ...
                '0.6','1.4','0.1','20','0','10','mm','0.01','0.015'});
            response=@(gap,testNumber)struct( ...
                'outcome',outcomes(testNumber),'measurements',gap);

            [result,record]=run_physical_test(parsed.params,20,response,parsed.cfg);

            testCase.verifyEqual(record.requested_levels,expectedLevels, ...
                'AbsTol',0.005);
            testCase.verifyEqual(result.mu,5.3922,'AbsTol',1e-3);
            testCase.verifyEqual(result.sigma,1.0412,'AbsTol',1e-3);
        end
    end
end
