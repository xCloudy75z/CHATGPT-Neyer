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
