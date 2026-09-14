classdef TestSpacerBatchSample < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot,'physical-capability','source')));
        end
    end

    methods (Test)
        function summarizesTenSpacerSamplesWithoutIndividualInventoryIds(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            csv_path = fullfile(root,'audit','v112', ...
                'spacer-sample-readings.csv');
            [labelled_sizes,readings] = read_spacer_sample_csv(csv_path);

            summary = summarize_spacer_batches(labelled_sizes, readings);

            testCase.verifyEqual([summary.sampled_spacer_count],[10 10 10]);
            testCase.verifyEqual([summary.readings_per_spacer],[3 3 3]);
            testCase.verifyEqual([summary.typical_thickness_mm], ...
                [0.486 1.118333333333333 2.070333333333333], ...
                'AbsTol',1e-12);
            testCase.verifyEqual([summary.lowest_spacer_average_mm], ...
                [0.443333333333333 1.106666666666667 2.06], ...
                'AbsTol',1e-12);
            testCase.verifyEqual([summary.highest_spacer_average_mm], ...
                [0.51 1.13 2.09], 'AbsTol',1e-12);
            testCase.verifyEqual([summary.lowest_reading_mm],[0.42 1.07 2.03], ...
                'AbsTol',1e-12);
            testCase.verifyEqual([summary.highest_reading_mm],[0.54 1.17 2.13], ...
                'AbsTol',1e-12);
            testCase.verifyEqual(sum([summary.typical_thickness_mm]), ...
                3.6746666666666665,'AbsTol',1e-12);
        end

        function rejectsUnequalReadingCountsInsideAGroup(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            csv_path = fullfile(root,'audit','v112', ...
                'spacer-sample-readings.csv');
            [labelled_sizes,readings] = read_spacer_sample_csv(csv_path);
            readings{2}(10,3) = NaN;

            testCase.verifyError(@()summarize_spacer_batches( ...
                labelled_sizes,readings), ...
                'summarize_spacer_batches:badReadings');
        end

        function rejectsAReleasedCsvWithMissingReadings(testCase)
            temporary_folder = testCase.createTemporaryFolder();
            csv_path = fullfile(temporary_folder,'incomplete.csv');
            file_id = fopen(csv_path,'w');
            fprintf(file_id,['labelled size (mm),sample number,reading 1 (mm),' ...
                'reading 2 (mm),reading 3 (mm),sample average (mm)\n']);
            fprintf(file_id,'0.50,1,0.50,0.47,,0.485000\n');
            fclose(file_id);

            testCase.verifyError(@()read_spacer_sample_csv(csv_path), ...
                'read_spacer_sample_csv:badData');
        end
    end
end
