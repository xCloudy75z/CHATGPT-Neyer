function diagnose_v113_duplicate_requests()
%DIAGNOSE_V113_DUPLICATE_REQUESTS Explain every repeated adjacent request.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
summary = readtable(fullfile(projectRoot, 'audit', 'v113-complete', ...
    'simulation-summary.csv'));
failed = summary(summary.immediate_duplicate_requests > 0, :);
rows = repmat(empty_row(), 0, 1);
baseSeed = 202609140;
for scenarioRow = 1:height(failed)
    scenario = failed.scenario(scenarioRow);
    for repetition = 1:5
        seed = baseSeed + 1000 * scenario + repetition;
        record = one_run(failed.true_middle_mm(scenarioRow), ...
            failed.true_variation_mm(scenarioRow), ...
            failed.usable_step_mm(scenarioRow), ...
            failed.starting_variation_mm(scenarioRow), ...
            failed.article_count(scenarioRow), seed);
        duplicateTests = find(abs(diff(record.requested_levels)) <= 1e-9) + 1;
        for position = 1:numel(duplicateTests)
            testNumber = duplicateTests(position);
            newRow = empty_row();
            newRow.scenario = scenario;
            newRow.repetition = repetition;
            newRow.seed = seed;
            newRow.test_number = testNumber;
            newRow.requested_gap_mm = record.requested_levels(testNumber);
            newRow.stage = record.stage(testNumber);
            newRow.previous_outcome = outcome_name( ...
                record.successes(testNumber - 1));
            newRow.current_outcome = outcome_name( ...
                record.successes(testNumber));
            reachableMaximum = floor((10 + 1e-9) / ...
                failed.usable_step_mm(scenarioRow)) * ...
                failed.usable_step_mm(scenarioRow);
            newRow.at_boundary = abs(newRow.requested_gap_mm) <= 1e-9 || ...
                abs(newRow.requested_gap_mm - reachableMaximum) <= 1e-9;
            newRow.final_status = string(record.status);
            newRow.stop_reason = string(record.stop_reason);
            rows(end + 1, 1) = newRow; %#ok<AGROW>
        end
    end
end
details = struct2table(rows);
writetable(details, fullfile(projectRoot, 'audit', 'v113-complete', ...
    'duplicate-request-details.csv'));
fprintf(['V1.13 duplicate diagnosis: %d repeated adjacent requests; ' ...
    '%d at a permitted boundary.\n'], height(details), sum(details.at_boundary));
end

function record = one_run(trueMiddle, trueVariation, usableStep, ...
        startingVariation, articleCount, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
thresholds = trueMiddle + trueVariation * randn(stream, articleCount, 1);
params = struct('avg_low', 0, 'avg_high', 10, ...
    'spread_guess', startingVariation);
cfg = neyer_settings();
cfg.min_level = 0;
cfg.max_level = 10;
cfg.level_increment = usableStep;
cfg.resolution_sigma_floor_factor = 2;
cfg.reachable_model = reachable_gap_model( ...
    struct('mode', 'regular', 'increment_mm', usableStep), 0, 10);
response = @(gap, number) struct('outcome', gap <= thresholds(number), ...
    'measurements', gap);
evalc('[~, record] = run_physical_test(params, articleCount, response, cfg);');
end

function name = outcome_name(interaction)
if interaction, name = "Interaction"; else, name = "No interaction"; end
end

function row = empty_row()
row = struct('scenario', NaN, 'repetition', NaN, 'seed', NaN, ...
    'test_number', NaN, 'requested_gap_mm', NaN, 'stage', NaN, ...
    'previous_outcome', "", 'current_outcome', "", ...
    'at_boundary', false, 'final_status', "", 'stop_reason', "");
end
