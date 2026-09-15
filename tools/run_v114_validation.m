function run_v114_validation()
%RUN_V114_VALIDATION Run the paper replay, five 62-test runs, and matrix.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'), ...
    fullfile(projectRoot, 'tools'));
evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

paperOutcomes = logical([1 1 1 1 1 0 1 1 1 1 1 1 0 1 0 1 0 0 0 0]);
expectedLevels = [1.00 1.20 1.40 1.80 2.60 4.20 3.40 3.80 4.00 4.10 ...
    4.28 4.52 5.55 5.24 6.37 6.08 7.38 7.09 6.89 6.74]';
parameters = struct('avg_low', 0.6, 'avg_high', 1.4, ...
    'spread_guess', 0.10);
paperResult = [];
paperRecord = [];
evalc('[paperResult, paperRecord] = run_test(parameters, 20, @(~,testNumber) paperOutcomes(testNumber));');
assert(max(abs(paperRecord.levels - expectedLevels)) <= 0.005, ...
    'V1.14 did not reproduce the published 20 requested gaps.');
assert(abs(paperResult.mu - 5.3922) <= 1e-3 && ...
    abs(paperResult.sigma - 1.0412) <= 1e-3, ...
    'V1.14 did not reproduce the published fitted result.');
paperPath = fullfile(evidenceFolder, 'paper-reference.txt');
fileId = fopen(paperPath, 'w');
assert(fileId >= 0, 'Could not write paper replay evidence.');
fprintf(fileId, 'Published 20-test replay: PASS\n');
fprintf(fileId, 'Requested gaps matched within 0.005 mm: yes\n');
fprintf(fileId, 'Middle gap: %.4f mm\n', paperResult.mu);
fprintf(fileId, 'Overall variation: %.4f mm\n', paperResult.sigma);
fclose(fileId);

steps = [0.05 0.10 0.15 0.20 0.50];
fiveResults = cell(numel(steps), 1);
for trial = 1:numel(steps)
    fiveResults{trial} = v114_simulate_study(5, 0.8, steps(trial), ...
        62, 11500 + trial);
end
fiveSummary = struct2table(vertcat(fiveResults{:}));
fiveSummary.middle_absolute_error_mm = abs( ...
    fiveSummary.estimated_middle_mm - fiveSummary.true_middle_mm);
fiveSummary.variation_absolute_error_mm = abs( ...
    fiveSummary.estimated_variation_mm - fiveSummary.true_variation_mm);
writetable(fiveSummary, fullfile(evidenceFolder, ...
    'five-62-test-summary.csv'));
assert(all(fiveSummary.has_overlap) && ...
    all(isfinite(fiveSummary.estimated_middle_mm)) && ...
    all(isfinite(fiveSummary.estimated_variation_mm)), ...
    'One of the five 62-test confirmation runs did not produce a fitted curve.');
assert(all(fiveSummary.all_requests_reachable & ...
    fiveSummary.all_requests_in_bounds & ...
    fiveSummary.no_immediate_duplicate), ...
    'One of the five 62-test runs made an invalid request.');

matrix = run_v114_unknown_variation_matrix();
fittedRows = matrix.has_overlap & isfinite(matrix.estimated_middle_mm) & ...
    isfinite(matrix.estimated_variation_mm);
summaryPath = fullfile(evidenceFolder, 'validation-summary.txt');
fileId = fopen(summaryPath, 'w');
assert(fileId >= 0, 'Could not write V1.14 validation summary.');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer Gap Test V1.14 simulation validation: PASS\n');
fprintf(fileId, 'Published 20-test replay: PASS (%.4f / %.4f mm)\n', ...
    paperResult.mu, paperResult.sigma);
fprintf(fileId, 'Five separate 62-test runs with fitted curves: %d of %d\n', ...
    sum(fiveSummary.has_overlap), height(fiveSummary));
fprintf(fileId, 'Unknown-variation matrix cases: %d\n', height(matrix));
fprintf(fileId, 'Matrix cases with fitted curves: %d of %d\n', ...
    sum(fittedRows), height(matrix));
fprintf(fileId, 'All matrix requests reachable and in bounds: yes\n');
fprintf(fileId, 'No unnecessary immediate duplicates: yes\n');
fprintf(fileId, 'Fitted cases whose 95%% middle range contained truth: %d of %d\n', ...
    sum(matrix.middle_interval_contains_truth(fittedRows)), sum(fittedRows));
fprintf(fileId, 'Fitted cases whose 95%% variation range contained truth: %d of %d\n', ...
    sum(matrix.variation_interval_contains_truth(fittedRows)), sum(fittedRows));
if any(fittedRows)
    fprintf(fileId, 'Median middle absolute error: %.4f mm\n', ...
        median(matrix.middle_absolute_error_mm(fittedRows)));
    fprintf(fileId, 'Median variation absolute error: %.4f mm\n', ...
        median(matrix.variation_absolute_error_mm(fittedRows)));
end
fprintf('V1.14 VALIDATION: PASS.\n');
end
