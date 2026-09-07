classdef TestPlannerSimulation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'simulation')));
        end
    end

    methods (Test)
        function deterministicShardsMatchSingleRun(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 4, 41);
            shard1 = fullfile(folder, 'shard-1.csv');
            shard2 = fullfile(folder, 'shard-2.csv');
            single = fullfile(folder, 'single.csv');
            run_planner_validation_shard(configPath, 1, 2, shard1);
            run_planner_validation_shard(configPath, 2, 2, shard2);
            run_planner_validation_shard(configPath, 1, 1, single);
            splitRows = sortrows([readtable(shard1, 'TextType', 'string'); ...
                readtable(shard2, 'TextType', 'string')], 'row_key');
            singleRows = sortrows(readtable(single, 'TextType', 'string'), 'row_key');
            testCase.verifyEqual(splitRows.row_key, singleRows.row_key);
            testCase.verifyEqual(splitRows.fitted_middle_mm, ...
                singleRows.fitted_middle_mm, 'AbsTol', 1e-12);
            testCase.verifyEqual(splitRows.fitted_sigma_mm, ...
                singleRows.fitted_sigma_mm, 'AbsTol', 1e-12);
            testCase.verifyEqual(splitRows.run_status, singleRows.run_status);
            testCase.verifyTrue(all(singleRows.run_status == "simulated"), ...
                'The repeatability check must contain completed scientific runs.');
        end

        function mergeRejectsMissingShard(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 2, 42);
            shard1 = fullfile(folder, 'shard-1.csv');
            run_planner_validation_shard(configPath, 1, 2, shard1);
            testCase.verifyError(@() merge_planner_validation(configPath, ...
                {shard1}, fullfile(folder, 'summary.csv')), ...
                'merge_planner_validation:missingShard');
        end

        function mergeRejectsDuplicateRows(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 4, 43);
            shard1 = fullfile(folder, 'shard-1.csv');
            shard2 = fullfile(folder, 'shard-2.csv');
            run_planner_validation_shard(configPath, 1, 2, shard1);
            run_planner_validation_shard(configPath, 2, 2, shard2);
            testCase.verifyError(@() merge_planner_validation(configPath, ...
                {shard1, shard1, shard2}, fullfile(folder, 'summary.csv')), ...
                'merge_planner_validation:duplicateRows');
        end

        function mergeRejectsConfigurationMismatch(testCase)
            folder = testCase.createTemporaryFolder();
            configA = writeTinyConfig(folder, 2, 44, 'a.json');
            configB = writeTinyConfig(folder, 2, 99, 'b.json');
            shardA = fullfile(folder, 'a.csv');
            shardB = fullfile(folder, 'b.csv');
            run_planner_validation_shard(configA, 1, 2, shardA);
            run_planner_validation_shard(configB, 2, 2, shardB);
            testCase.verifyError(@() merge_planner_validation(configA, ...
                {shardA, shardB}, fullfile(folder, 'summary.csv')), ...
                'merge_planner_validation:configurationMismatch');
        end

        function completeMergeWritesOneScenarioSummary(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 4, 45);
            shard1 = fullfile(folder, 'shard-1.csv');
            shard2 = fullfile(folder, 'shard-2.csv');
            summaryPath = fullfile(folder, 'summary.csv');
            run_planner_validation_shard(configPath, 1, 2, shard1);
            run_planner_validation_shard(configPath, 2, 2, shard2);
            summary = merge_planner_validation(configPath, ...
                {shard1, shard2}, summaryPath);
            testCase.verifyTrue(isfile(summaryPath));
            testCase.verifyEqual(height(summary), 1);
            testCase.verifyEqual(summary.scenario_id, "tiny-regular");
            testCase.verifyEqual(summary.repetitions, 4);
        end

        function calibrationCanDeclareAFixedCandidateQuantity(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 1, 46);
            config = jsondecode(fileread(configPath));
            config.scenarios.fixed_validation_count = 24;
            writeJson(configPath, config);
            outputPath = fullfile(folder, 'fixed.csv');
            rows = run_planner_validation_shard(configPath, 1, 1, outputPath);
            testCase.verifyEqual(rows.planned_main, 24);
            testCase.verifyEqual(rows.planned_total, 24);
            testCase.verifyEqual(rows.actual_articles, 24);
        end

        function compactCalibrationConfigExpandsCandidateQuantities(testCase)
            folder = testCase.createTemporaryFolder();
            configPath = writeTinyConfig(folder, 2, 47);
            config = jsondecode(fileread(configPath));
            config.fixed_validation_counts = [40 60 80 100];
            scenarios = expand_planner_validation_scenarios(config);
            testCase.verifyEqual(numel(scenarios), 4);
            testCase.verifyEqual([scenarios.fixed_validation_count], ...
                [40 60 80 100]);
            testCase.verifyEqual([scenarios.seed_group_index], [1 1 1 1]);
            testCase.verifyEqual(string({scenarios.id}), ...
                ["tiny-regular-n40" "tiny-regular-n60" ...
                 "tiny-regular-n80" "tiny-regular-n100"]);
        end
    end
end

function configPath = writeTinyConfig(folder, repetitions, baseSeed, fileName)
if nargin < 4, fileName = 'config.json'; end
scenario = struct( ...
    'id', 'tiny-regular', ...
    'true_middle_mm', 5, 'true_sigma_mm', 1, ...
    'outcome', 'interaction', 'reliability', 0.90, ...
    'confidence', 0.95, 'accuracy_mm', 100, ...
    'minimum_gap_mm', 0, 'maximum_gap_mm', 10, ...
    'interaction_endpoint_mm', 3, 'no_interaction_endpoint_mm', 7, ...
    'capability', 'regular', 'increment_mm', 0.10, ...
    'gaps_mm', [], 'measurement_sd_mm', 0, 'build_sd_mm', 0, ...
    'reading_count', 4, 'repetitions', repetitions, ...
    'fixed_validation_count', 24);
config = struct('schema_version', '1.0-test', ...
    'rule_version', 'absolute-gap-n-minus-15-provisional-1', ...
    'base_seed', baseSeed, 'max_simulated_articles', 30, ...
    'grid_points', 101, 'scenarios', scenario);
configPath = fullfile(folder, fileName);
fileId = fopen(configPath, 'w');
assert(fileId >= 0, 'Could not create the tiny simulation config.');
cleanupFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fwrite(fileId, jsonencode(config), 'char');
end


function writeJson(path, value)
fileId = fopen(path, 'w');
assert(fileId >= 0, 'Could not update the simulation config.');
cleanupFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fwrite(fileId, jsonencode(value), 'char');
end
