classdef TestCombinedPhysicalStudy < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyAndEngine(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'simulation')));
        end
    end

    methods (Test)
        function savesEveryScenarioAndReportsProgress(testCase)
            folder=testCase.createTemporaryFolder();
            output=fullfile(folder,'checkpoint.csv');
            opts=tinyOptions(output);

            text=evalc('run_combined_physical_study(2,opts);');
            rows=readtable(output);

            testCase.verifyEqual(height(rows),2);
            testCase.verifyEqual(rows.repetitions,[2;2]);
            testCase.verifySubstring(text,'Scenario 1/2');
            testCase.verifySubstring(text,'Scenario 2/2');
        end

        function restartSkipsCompletedScenarios(testCase)
            folder=testCase.createTemporaryFolder();
            output=fullfile(folder,'checkpoint.csv');
            opts=tinyOptions(output);
            run_combined_physical_study(2,opts);
            before=readtable(output);

            text=evalc('run_combined_physical_study(2,opts);');
            after=readtable(output);

            testCase.verifyEqual(after,before);
            testCase.verifySubstring(text,'Skipping 2 completed scenarios');
        end

        function modelsNewSpacerBuildVariation(testCase)
            folder=testCase.createTemporaryFolder();
            output=fullfile(folder,'build-variation.csv');
            opts=tinyOptions(output);
            opts.increments=0.10;
            opts.build_sd_factors=[0 0.5];

            run_combined_physical_study(20,opts);
            rows=sortrows(readtable(output),'build_sd_factor');

            testCase.verifyEqual(height(rows),2);
            testCase.verifyEqual(rows.build_sd,[0;0.05],'AbsTol',1e-12);
            testCase.verifyEqual(rows.mean_abs_build_error(1),0,'AbsTol',1e-12);
            testCase.verifyGreaterThan(rows.mean_abs_build_error(2),0);
        end
    end
end

function opts=tinyOptions(output)
opts=struct('output_file',output,'budgets',3,'true_sigmas',0.2, ...
    'increments',[0.05 0.10],'floor_factors',2,'reading_sds',0.015, ...
    'reading_counts',4,'build_sd_factors',0,'grid_points',101,'seed',17);
end
