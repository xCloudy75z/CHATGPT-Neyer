classdef TestPhysicalUiInputs < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addGapCandidate(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'application','source')));
        end
    end

    methods (Test)
        function settingsRequirePhysicalIncrement(testCase)
            answers={'0','10','1','20','0','mm',''};
            testCase.verifyError(@()parse_run_inputs(answers), ...
                'parse_run_inputs:badLevelIncrement');
        end

        function settingsStoreConfirmedIncrement(testCase)
            for increment={'0.05','0.10'}
                answers={'0','10','1','20','0','mm',increment{1}};
                parsed=parse_run_inputs(answers);
                testCase.verifyEqual(parsed.cfg.level_increment, ...
                    str2double(increment{1}),'AbsTol',1e-12);
            end
        end

        function settingsSeparateFoilFromUsableResolution(testCase)
            answers={'0','10','1','20','0','mm','0.05','0.015'};

            parsed=parse_run_inputs(answers);

            testCase.verifyEqual(parsed.cfg.usable_resolution,0.05, ...
                'AbsTol',1e-12);
            testCase.verifyEqual(parsed.cfg.foil_thickness,0.015, ...
                'AbsTol',1e-12);
        end

        function usableResolutionMustSupportTwoDecimalRequests(testCase)
            answers={'0','10','1','20','0','mm','0.015','0.015'};

            testCase.verifyError(@()parse_run_inputs(answers), ...
                'parse_run_inputs:badUsableResolution');
        end

        function combinationPlanDoesNotTreatFoilAsUsableStep(testCase)
            plan = struct('physical_setup', struct( ...
                'mode', 'combinations', ...
                'component_names', {{'foil', '0.50 mm spacer'}}, ...
                'component_mm', [0.015 0.50], ...
                'maximum_counts', [10 2]));

            step = usable_resolution_for_plan(plan, 0.05);

            testCase.verifyEqual(step, 0.05, 'AbsTol', 1e-12);
        end

        function regularPlanCarriesItsConfirmedStep(testCase)
            plan = struct('physical_setup', struct( ...
                'mode', 'regular', 'increment_mm', 0.15));

            step = usable_resolution_for_plan(plan, 0.05);

            testCase.verifyEqual(step, 0.15, 'AbsTol', 1e-12);
        end

        function editedRegularPlanCannotSilentlyReplaceInvalidStep(testCase)
            plan = struct('physical_setup', struct( ...
                'mode', 'regular', 'increment_mm', 0.015));

            testCase.verifyError(@() usable_resolution_for_plan( ...
                plan, 0.05), 'usable_resolution_for_plan:badRegularStep');
        end

        function requestedGapInstructionUsesTwoDecimalPlaces(testCase)
            message=format_requested_gap(3.645,'mm');

            testCase.verifyEqual(message,'Build a gap of 3.65 mm.');
        end

        function responseParsesFourOrFiveMeasurements(testCase)
            four=parse_physical_response('2.50, 2.49, 2.52, 2.48',true);
            five=parse_physical_response('2.50 2.50 2.49 2.52 2.48',false);

            testCase.verifyEqual(four.measurements,[2.50 2.49 2.52 2.48]);
            testCase.verifyTrue(four.outcome);
            testCase.verifyEqual(five.measurements, ...
                [2.50 2.50 2.49 2.52 2.48]);
            testCase.verifyFalse(five.outcome);
        end

        function responseRejectsWrongCountOrInvalidReading(testCase)
            invalid={'2.50 2.49 2.52','2.50 2.49 2.52 2.48 2.51 2.50', ...
                     '2.50 2.49 bad 2.48'};
            for k=1:numel(invalid)
                testCase.verifyError( ...
                    @()parse_physical_response(invalid{k},true), ...
                    'parse_physical_response:badMeasurements');
            end
        end
    end
end
