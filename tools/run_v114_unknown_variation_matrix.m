function summary = run_v114_unknown_variation_matrix()
%RUN_V114_UNKNOWN_VARIATION_MATRIX Exercise first-study mode across conditions.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'), ...
    fullfile(projectRoot, 'tools'));
evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

trueMiddles = [2.5 5.0 7.5];
trueVariations = [0.15 0.8 2.0];
usableSteps = [0.05 0.15 0.50];
seeds = [11411 11412];
cases = zeros(numel(trueMiddles) * numel(trueVariations) * ...
    numel(usableSteps) * numel(seeds), 5);
row = 0;
for middle = trueMiddles
    for variation = trueVariations
        for step = usableSteps
            for seed = seeds
                row = row + 1;
                cases(row, :) = [middle variation step 62 seed + row];
            end
        end
    end
end

results(size(cases, 1), 1) = empty_summary();
usedParallel = false;
try
    if license('test', 'Distrib_Computing_Toolbox') && ...
            exist('gcp', 'file') == 2 && exist('parpool', 'file') == 2
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('local', 4); end %#ok<NASGU>
        parfor caseNumber = 1:size(cases, 1)
            values = cases(caseNumber, :);
            results(caseNumber) = v114_simulate_study(values(1), values(2), ...
                values(3), values(4), values(5));
        end
        usedParallel = true;
    end
catch
    usedParallel = false;
end
if ~usedParallel
    for caseNumber = 1:size(cases, 1)
        values = cases(caseNumber, :);
        results(caseNumber) = v114_simulate_study(values(1), values(2), ...
            values(3), values(4), values(5));
    end
end

summary = struct2table(results);
summary.middle_absolute_error_mm = abs(summary.estimated_middle_mm - ...
    summary.true_middle_mm);
summary.variation_absolute_error_mm = abs(summary.estimated_variation_mm - ...
    summary.true_variation_mm);
writetable(summary, fullfile(evidenceFolder, ...
    'unknown-variation-summary.csv'));

assert(all(summary.all_requests_reachable), ...
    'At least one simulation requested an unreachable gap.');
assert(all(summary.all_requests_in_bounds), ...
    'At least one simulation requested a gap outside the permitted range.');
assert(all(summary.no_immediate_duplicate), ...
    'At least one simulation repeated a gap immediately without need.');
end

function value = empty_summary()
value = struct('true_middle_mm', NaN, 'true_variation_mm', NaN, ...
    'usable_step_mm', NaN, 'maximum_tests', NaN, 'random_seed', NaN, ...
    'tests_requested', NaN, 'search_scale_mm', NaN, ...
    'search_scale_source', '', 'all_requests_reachable', false, ...
    'all_requests_in_bounds', false, 'no_immediate_duplicate', false, ...
    'has_overlap', false, 'estimated_middle_mm', NaN, ...
    'estimated_variation_mm', NaN, 'middle_lower_mm', NaN, ...
    'middle_upper_mm', NaN, 'variation_lower_mm', NaN, ...
    'variation_upper_mm', NaN, 'middle_interval_contains_truth', false, ...
    'variation_interval_contains_truth', false, 'status', '');
end
