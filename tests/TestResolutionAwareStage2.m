classdef TestResolutionAwareStage2 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProposed(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'proposed','functions')));
        end
    end

    methods (Test)
        function everySelectedLevelIsReachable(testCase)
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1);
            cfg=neyer_settings();
            cfg.level_increment=0.1;
            record=run_loop(params,15,@(x,~)x>=5,cfg);
            gridUnits=record.levels/cfg.level_increment;
            testCase.verifyEqual(gridUnits,round(gridUnits),'AbsTol',1e-10);
        end

        function stageTwoWidthDoesNotShrinkBelowResolutionFloor(testCase)
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1);
            cfg=neyer_settings();
            cfg.level_increment=0.1;
            cfg.resolution_sigma_floor_factor=1;
            record=run_loop(params,50,@(x,~)x>=5,cfg);
            stageTwoSigma=record.est_sigma(record.stage==2);
            testCase.assertNotEmpty(stageTwoSigma);
            testCase.verifyGreaterThanOrEqual(stageTwoSigma, ...
                cfg.level_increment*cfg.resolution_sigma_floor_factor);
        end

        function partTwoChoosesReachableLevelOutsideCurrentBracket(testCase)
            params=struct('mu_min',4,'mu_max',6,'sigma_guess',1, ...
                'working_sigma',0.1,'part2_started',true);
            cfg=neyer_settings();
            cfg.level_increment=0.1;
            cfg.resolution_sigma_floor_factor=1;
            levels=[5;3;4;5.8;3.5;5.2;4;4.9;4.5;4.6;5.2;4.7;4.8;5.1;4.8;5.1;4.8;5.1];
            outcomes=logical([1;0;0;1;0;1;0;0;0;0;1;0;0;1;0;1;0;1]);
            [actual,est]=choose_stage(levels,outcomes,params,cfg);
            testCase.verifyEqual(est.stage,2);
            testCase.verifyEqual(actual/cfg.level_increment, ...
                round(actual/cfg.level_increment),'AbsTol',1e-10);
            testCase.verifyTrue(actual<4.9 || actual>5.0);
        end
    end
end
