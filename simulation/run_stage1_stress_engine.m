function outputFile = run_stage1_stress_engine(engineName, repetitions)
%RUN_STAGE1_STRESS_ENGINE Target cases where the two Stage-1 rules disagree.
if nargin < 1, engineName = 'baseline'; end
if nargin < 2, repetitions = 200; end

root = fileparts(fileparts(mfilename('fullpath')));
if strcmp(engineName, 'stage1-only')
    enginePath = fullfile(root, 'variants', 'stage1-only', 'functions');
else
    enginePath = fullfile(root, 'baseline', 'functions');
end
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

scenario = ["wide_centered"; "wide_upper_inside"; "wide_above_bound"; ...
            "asymmetric_inside"; "asymmetric_above"; "tight_centered"];
low =      [-10; -10; -10; 0; 0; -2];
high =     [ 10;  10;  10; 20; 20;  2];
trueMu =   [  0;   8;  15; 15; 25;  0];
trueSigma =[  1;   1;   1;  1;  1;  1];
budgets = [20 50];
seed = 20260906;
rng(seed, 'twister');

rows = struct([]); row = 0;
for budget = budgets
    for sc = 1:numel(scenario)
        bothAt = NaN(repetitions, 1);
        overlapAt = NaN(repetitions, 1);
        overlap = false(repetitions, 1);
        muError = NaN(repetitions, 1);
        sigmaError = NaN(repetitions, 1);
        firstAfterCenter = NaN(repetitions, 1);
        cfg = neyer_settings();
        cfg.grid_points = 2001;
        params = struct('mu_min', low(sc), 'mu_max', high(sc), 'sigma_guess', 1);

        for rep = 1:repetitions
            thresholds = trueMu(sc) + trueSigma(sc) * randn(budget, 1);
            [~, record] = evalc('run_loop(params, budget, @(level, k) level >= thresholds(k), cfg)');
            firstAfterCenter(rep) = record.levels(2);
            for k = 2:budget
                prefix = record.successes(1:k);
                if isnan(bothAt(rep)) && any(prefix) && any(~prefix), bothAt(rep) = k; end
                if isnan(overlapAt(rep)) && has_overlap(record.levels(1:k), prefix), overlapAt(rep) = k; end
            end
            overlap(rep) = has_overlap(record.levels, record.successes);
            if overlap(rep)
                [rawMu, rawSigma] = best_fit(record.levels, record.successes, ...
                    record.est_mu(end), record.est_sigma(end));
                [fitMu, fitSigma] = sanity_clamp(rawMu, rawSigma, record.levels, cfg);
                muError(rep) = fitMu - trueMu(sc);
                sigmaError(rep) = fitSigma - trueSigma(sc);
            end
        end

        row = row + 1;
        rows(row).engine = string(engineName); %#ok<AGROW>
        rows(row).scenario = scenario(sc);
        rows(row).budget = budget;
        rows(row).low = low(sc);
        rows(row).high = high(sc);
        rows(row).true_mu = trueMu(sc);
        rows(row).true_sigma = trueSigma(sc);
        rows(row).repetitions = repetitions;
        rows(row).mean_second_level = mean(firstAfterCenter);
        rows(row).mean_both_response_test = mean(bothAt, 'omitnan');
        rows(row).overlap_rate = mean(overlap);
        rows(row).mean_overlap_test = mean(overlapAt, 'omitnan');
        rows(row).mu_rmse = sqrt(mean(muError.^2, 'omitnan'));
        rows(row).sigma_rmse = sqrt(mean(sigmaError.^2, 'omitnan'));
        rows(row).seed = seed;
    end
end

results = struct2table(rows);
outputFile = fullfile(root, 'simulation', sprintf('stage1-stress-%s.csv', engineName));
writetable(results, outputFile);
fprintf('WROTE %s (%d scenarios x %d repetitions)\n', outputFile, height(results), repetitions);
end
