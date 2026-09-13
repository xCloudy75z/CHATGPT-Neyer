classdef TestMeasurementRecord < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addRecorderSource(testCase)
            recorderRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(recorderRoot, 'source')));
        end
    end

    methods (Test)
        function acceptsOneFiniteNonnegativeMeasurement(testCase)
            record = General_Measurement_Recorder('newrecord', ...
                'part-01', 2.00, 2.07, 'mm', 'first check', ...
                datetime(2026, 9, 13, 8, 30, 0));

            testCase.verifyEqual(record.sample_id, 'part-01');
            testCase.verifyEqual(record.nominal_size, 2.00, 'AbsTol', 1e-12);
            testCase.verifyEqual(record.measured_size, 2.07, 'AbsTol', 1e-12);
            testCase.verifyEqual(record.measurement_count, 1);
            testCase.verifyEqual(record.measurement_uncertainty, 'not assessed');
        end

        function rejectsMoreThanOneMeasurement(testCase)
            testCase.verifyError(@() General_Measurement_Recorder('newrecord', ...
                'part-01', 2.00, [2.06 2.07], 'mm', '', datetime('now')), ...
                'General_Measurement_Recorder:oneMeasurementRequired');
        end

        function rejectsInvalidMeasurement(testCase)
            invalidMeasurements = {NaN, Inf, -0.01, '2.07'};
            for invalidIndex = 1:numel(invalidMeasurements)
                testCase.verifyError(@() General_Measurement_Recorder('newrecord', ...
                    'part-01', 2.00, invalidMeasurements{invalidIndex}, ...
                    'mm', '', datetime('now')), ...
                    'General_Measurement_Recorder:badMeasuredSize');
            end
        end

        function csvContainsOneReadingAndClearUncertainty(testCase)
            record = General_Measurement_Recorder('newrecord', ...
                'part-01', 2.00, 2.07, 'mm', 'first check', ...
                datetime(2026, 9, 13, 8, 30, 0));

            csvText = General_Measurement_Recorder('tocsv', record);

            expected = sprintf([ ...
                'sample ID,nominal size,measured size,unit,date and time,note,' ...
                'measurement count,measurement uncertainty\n' ...
                'part-01,2,2.07,mm,2026-09-13 08:30:00,first check,1,not assessed']);
            testCase.verifyEqual(csvText, expected);
        end

        function saveRefusesToReplaceExistingFile(testCase)
            temporaryFolder = tempname;
            mkdir(temporaryFolder);
            cleanup = onCleanup(@() rmdir(temporaryFolder, 's')); %#ok<NASGU>
            outputPath = fullfile(temporaryFolder, 'measurements.csv');
            fileId = fopen(outputPath, 'w');
            fwrite(fileId, 'existing');
            fclose(fileId);

            testCase.verifyError(@() General_Measurement_Recorder('save', ...
                outputPath, 'new content'), ...
                'General_Measurement_Recorder:alreadyExists');
            testCase.verifyEqual(fileread(outputPath), 'existing');
        end
    end
end
