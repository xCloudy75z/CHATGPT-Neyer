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
                'measurements',repmat(gap,1,4));

            testCase.verifyError( ...
                @()run_physical_test(params,1,response,cfg), ...
                'run_physical_test:badLevelIncrement');
        end

        function physicalRunRejectsNonpositiveOrNonfiniteIncrement(testCase)
            params=struct('avg_low',0,'avg_high',10,'spread_guess',1);
            response=@(gap,~)struct('outcome',true, ...
                'measurements',repmat(gap,1,4));
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
                'measurements',repmat(gap,1,4));

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
                'measurements',repmat(gap,1,4));

            [~,record]=run_physical_test(params,3,response,cfg);

            testCase.verifyEqual(record.resolution_sigma_floor_factor,2);
            testCase.verifyEqual(record.resolution_sigma_floor,0.20, ...
                'AbsTol',1e-12);
        end
    end
end
