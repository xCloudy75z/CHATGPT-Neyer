function run_v113_audit_simulations(shardIndex, shardCount)
%RUN_V113_AUDIT_SIMULATIONS Stress every agreed direct-test combination.
if nargin < 1, shardIndex = 1; end
if nargin < 2, shardCount = 1; end
assert(isscalar(shardIndex) && isscalar(shardCount) && ...
    shardIndex == floor(shardIndex) && shardCount == floor(shardCount) && ...
    shardCount >= 1 && shardIndex >= 1 && shardIndex <= shardCount, ...
    'Shard index must be a whole number from 1 through the shard count.');
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
outputFolder = fullfile(projectRoot, 'audit', 'v113-complete');
if ~isfolder(outputFolder), mkdir(outputFolder); end

middleGaps = [1.5 5.0 8.5];
trueVariations = [0.15 0.25 0.50 1.00 1.50];
usableSteps = [0.05 0.10 0.15 0.50];
startingVariations = [0.25 1.00 2.00];
articleCounts = [20 62];
repetitions = 5;
baseSeed = 202609140;

[middleGrid, trueVariationGrid, stepGrid, startingGrid, countGrid] = ...
    ndgrid(middleGaps, trueVariations, usableSteps, ...
    startingVariations, articleCounts);
scenarioCount = numel(middleGrid);
scenarioInputs = [middleGrid(:), trueVariationGrid(:), stepGrid(:), ...
    startingGrid(:), countGrid(:)];
selectedScenarios = find(mod((1:scenarioCount) - 1, shardCount) + 1 == shardIndex);
scenarioRows = repmat(empty_row(), numel(selectedScenarios), 1);

workerCount = 0;
executionMode = "serial";
useParallel = license('test', 'Distrib_Computing_Toolbox') && ...
    exist('gcp', 'file') == 2 && exist('parpool', 'file') == 2;
if useParallel
    try
        pool = gcp('nocreate');
        if isempty(pool)
            workerCount = min(8, feature('numcores'));
            pool = parpool('local', workerCount);
        end
        workerCount = pool.NumWorkers;
        executionMode = "parallel";
    catch problem
        warning('v113Audit:parallelUnavailable', ...
            'Parallel workers were unavailable; continuing serially. %s', ...
            problem.message);
        useParallel = false;
        workerCount = 0;
    end
end

auditStart = tic;
if useParallel
    parfor selectedPosition = 1:numel(selectedScenarios)
        scenarioNumber = selectedScenarios(selectedPosition);
        scenarioRows(selectedPosition) = evaluate_scenario(scenarioNumber, ...
            scenarioInputs(scenarioNumber, :), repetitions, ...
            baseSeed + 1000 * scenarioNumber, executionMode);
    end
else
    for selectedPosition = 1:numel(selectedScenarios)
        scenarioNumber = selectedScenarios(selectedPosition);
        scenarioRows(selectedPosition) = evaluate_scenario(scenarioNumber, ...
            scenarioInputs(scenarioNumber, :), repetitions, ...
            baseSeed + 1000 * scenarioNumber, executionMode);
    end
end
elapsedSeconds = toc(auditStart);

summary = struct2table(scenarioRows);
if shardCount == 1
    summaryName = 'simulation-summary.csv';
    performanceName = 'performance-summary.csv';
else
    summaryName = sprintf('simulation-shard-%d-of-%d.csv', shardIndex, shardCount);
    performanceName = sprintf('performance-shard-%d-of-%d.csv', shardIndex, shardCount);
end
writetable(summary, fullfile(outputFolder, summaryName));
performance = table(string(version('-release')), executionMode, workerCount, ...
    numel(selectedScenarios), repetitions, numel(selectedScenarios) * repetitions, elapsedSeconds, ...
    median(summary.median_run_seconds), max(summary.maximum_run_seconds), ...
    sum(summary.invariant_failures), sum(~summary.replay_matches), ...
    'VariableNames', {'matlab_release','execution_mode','workers', ...
    'scenario_count','repetitions_per_scenario','total_runs', ...
    'elapsed_seconds','median_scenario_run_seconds', ...
    'maximum_scenario_run_seconds','invariant_failures', ...
    'replay_mismatches'});
writetable(performance, fullfile(outputFolder, performanceName));

fprintf(['V1.13 SIMULATION AUDIT: %d scenarios, %d runs, ' ...
    '%d invariant failures, %d replay mismatches, %.1f seconds.\n'], ...
    numel(selectedScenarios), numel(selectedScenarios) * repetitions, ...
    sum(summary.invariant_failures), sum(~summary.replay_matches), ...
    elapsedSeconds);
assert(sum(summary.invariant_failures) == 0, ...
    'The simulation matrix found one or more invariant failures.');
assert(all(summary.replay_matches), ...
    'At least one fixed-seed replay produced a different result.');
end

function row = evaluate_scenario(scenarioNumber, input, repetitions, firstSeed, executionMode)
trueMiddle = input(1);
trueVariation = input(2);
usableStep = input(3);
startingVariation = input(4);
articleCount = input(5);

middleErrors = NaN(repetitions, 1);
variationErrors = NaN(repetitions, 1);
runSeconds = zeros(repetitions, 1);
overlaps = false(repetitions, 1);
pauses = false(repetitions, 1);
invariantFailures = 0;
failureCounts = zeros(1, 11);
firstRecord = [];
firstResult = [];

for repetition = 1:repetitions
    seed = firstSeed + repetition;
    runStart = tic;
    [result, record] = one_run(trueMiddle, trueVariation, usableStep, ...
        startingVariation, articleCount, seed);
    runSeconds(repetition) = toc(runStart);
    runFailureCounts = count_invariant_failures(result, record, usableStep);
    failureCounts = failureCounts + runFailureCounts;
    invariantFailures = invariantFailures + sum(runFailureCounts);
    overlaps(repetition) = result.has_overlap;
    pauses(repetition) = strcmp(record.status, 'paused');
    if result.has_overlap
        middleErrors(repetition) = result.mu - trueMiddle;
        variationErrors(repetition) = result.sigma - trueVariation;
    end
    if repetition == 1
        firstRecord = record;
        firstResult = result;
    end
end

[replayResult, replayRecord] = one_run(trueMiddle, trueVariation, ...
    usableStep, startingVariation, articleCount, firstSeed + 1);
replayMatches = isequaln(firstRecord.requested_levels, ...
    replayRecord.requested_levels) && ...
    isequaln(firstRecord.levels, replayRecord.levels) && ...
    isequaln(firstRecord.successes, replayRecord.successes) && ...
    isequaln(firstRecord.stage, replayRecord.stage) && ...
    isequaln([firstResult.mu firstResult.sigma], ...
    [replayResult.mu replayResult.sigma]);

row = empty_row();
row.scenario = scenarioNumber;
row.true_middle_mm = trueMiddle;
row.true_variation_mm = trueVariation;
row.usable_step_mm = usableStep;
row.starting_variation_mm = startingVariation;
row.article_count = articleCount;
row.first_seed = firstSeed + 1;
row.repetitions = repetitions;
row.overlap_runs = sum(overlaps);
row.paused_runs = sum(pauses);
row.invariant_failures = invariantFailures;
row.nonfinite_requests = failureCounts(1);
row.out_of_bounds_requests = failureCounts(2);
row.off_grid_requests = failureCounts(3);
row.immediate_duplicate_requests = failureCounts(4);
row.invalid_stage_values = failureCounts(5);
row.stage_reversals = failureCounts(6);
row.budget_overruns = failureCounts(7);
row.measurement_count_failures = failureCounts(8);
row.invalid_fits = failureCounts(9);
row.probability_direction_failures = failureCounts(10);
row.missing_pause_reasons = failureCounts(11);
row.replay_matches = replayMatches;
row.middle_bias_mm = mean(middleErrors, 'omitnan');
row.middle_rmse_mm = sqrt(mean(middleErrors.^2, 'omitnan'));
row.variation_bias_mm = mean(variationErrors, 'omitnan');
row.variation_rmse_mm = sqrt(mean(variationErrors.^2, 'omitnan'));
row.median_run_seconds = median(runSeconds);
row.maximum_run_seconds = max(runSeconds);
row.execution_mode = executionMode;
end

function [result, record] = one_run(trueMiddle, trueVariation, ...
        usableStep, startingVariation, articleCount, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
articleThresholds = trueMiddle + trueVariation * ...
    randn(stream, articleCount, 1);
params = struct('avg_low', 0, 'avg_high', 10, ...
    'spread_guess', startingVariation);
cfg = neyer_settings();
cfg.min_level = 0;
cfg.max_level = 10;
cfg.level_increment = usableStep;
cfg.resolution_sigma_floor_factor = 2;
setup = struct('mode', 'regular', 'increment_mm', usableStep);
cfg.reachable_model = reachable_gap_model(setup, 0, 10);
response = @(requestedGap, testNumber) struct( ...
    'outcome', requestedGap <= articleThresholds(testNumber), ...
    'measurements', requestedGap);
evalc('[result, record] = run_physical_test(params, articleCount, response, cfg);');
end

function failures = count_invariant_failures(result, record, usableStep)
tolerance = 1e-9;
requested = record.requested_levels(:);
failures = zeros(1, 11);
failures(1) = ~all(isfinite(requested));
failures(2) = ~all(requested >= -tolerance & requested <= 10 + tolerance);
failures(3) = ~all(abs(requested / usableStep - ...
    round(requested / usableStep)) <= 1e-8);
if numel(requested) > 1
    duplicateTests = find(abs(diff(requested)) <= tolerance) + 1;
    reachableMinimum = 0;
    reachableMaximum = floor((10 + tolerance) / usableStep) * usableStep;
    accidentalDuplicate = false;
    for duplicatePosition = 1:numel(duplicateTests)
        testNumber = duplicateTests(duplicatePosition);
        gap = requested(testNumber);
        priorOutcomes = record.successes(1:testNumber - 1);
        expectedMinimumConfirmation = ...
            abs(gap - reachableMinimum) <= tolerance && ...
            ~record.successes(testNumber - 1) && ~any(priorOutcomes);
        expectedMaximumConfirmation = ...
            abs(gap - reachableMaximum) <= tolerance && ...
            record.successes(testNumber - 1) && all(priorOutcomes);
        accidentalDuplicate = accidentalDuplicate || ...
            ~(expectedMinimumConfirmation || expectedMaximumConfirmation);
    end
    failures(4) = accidentalDuplicate;
end
stages = record.stage(:);
failures(5) = ~all(ismember(stages, [1 2 3]));
failures(6) = any(diff(stages) < 0);
failures(7) = record.N > record.requested_N;
failures(8) = ~all(cellfun(@numel, record.measurements) == 1);
if result.has_overlap
    failures(9) = ~(isfinite(result.mu) && isfinite(result.sigma) && ...
        result.sigma > 0);
    lowerGap = max(0, result.mu - result.sigma);
    upperGap = min(10, result.mu + result.sigma);
    lowerChance = shape_model(lowerGap, result.mu, result.sigma);
    upperChance = shape_model(upperGap, result.mu, result.sigma);
    failures(10) = ~(lowerChance.p >= upperChance.p);
end
if strcmp(record.status, 'paused')
    failures(11) = isempty(record.stop_reason);
end
end

function row = empty_row()
row = struct('scenario', NaN, 'true_middle_mm', NaN, 'true_variation_mm', NaN, ...
    'usable_step_mm', NaN, 'starting_variation_mm', NaN, ...
    'article_count', NaN, 'first_seed', NaN, 'repetitions', NaN, ...
    'overlap_runs', 0, 'paused_runs', 0, 'invariant_failures', 0, ...
    'nonfinite_requests', 0, 'out_of_bounds_requests', 0, ...
    'off_grid_requests', 0, 'immediate_duplicate_requests', 0, ...
    'invalid_stage_values', 0, 'stage_reversals', 0, ...
    'budget_overruns', 0, 'measurement_count_failures', 0, ...
    'invalid_fits', 0, 'probability_direction_failures', 0, ...
    'missing_pause_reasons', 0, ...
    'replay_matches', false, 'middle_bias_mm', NaN, ...
    'middle_rmse_mm', NaN, 'variation_bias_mm', NaN, ...
    'variation_rmse_mm', NaN, 'median_run_seconds', NaN, ...
    'maximum_run_seconds', NaN, 'execution_mode', "not run");
end
