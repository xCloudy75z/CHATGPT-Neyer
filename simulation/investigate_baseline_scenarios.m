function [summary, trajectories] = investigate_baseline_scenarios()
%INVESTIGATE_BASELINE_SCENARIOS Small deterministic examples for unchanged v1.8.

root = fileparts(fileparts(mfilename('fullpath')));
enginePath = fullfile(root, 'baseline', 'functions');
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

names = ["accurate_guess"; "middle_far_above"; "narrow_transition"; ...
         "wide_transition"; "coarse_rounding"];
trueMu = [5; 8; 5; 5; 5];
trueSigma = [1; 1; 0.2; 3; 1];
avgLow = [4; 4; 4; 4; 4];
avgHigh = [6; 6; 6; 6; 6];
sigmaGuess = [1; 1; 1; 1; 1];
decimals = [2; 2; 2; 2; 0];
seeds = [101; 102; 103; 104; 101];
budget = 20;

summaryRows = struct([]);
trajectoryRows = struct([]);
sr = 0;
tr = 0;
for scenario = 1:numel(names)
    rng(seeds(scenario), 'twister');
    thresholds = trueMu(scenario) + trueSigma(scenario) * randn(budget, 1);
    params = struct('mu_min', avgLow(scenario), 'mu_max', avgHigh(scenario), ...
                    'sigma_guess', sigmaGuess(scenario));
    cfg = neyer_settings();
    cfg.level_decimals = decimals(scenario);
    [~, record] = evalc('run_loop(params, budget, @(level, k) level >= thresholds(k), cfg)');

    overlapAt = NaN;
    for k = 2:budget
        if has_overlap(record.levels(1:k), record.successes(1:k))
            overlapAt = k;
            break;
        end
    end

    fitMu = NaN;
    fitSigma = NaN;
    if has_overlap(record.levels, record.successes)
        [rawMu, rawSigma] = best_fit(record.levels, record.successes, ...
            record.est_mu(end), record.est_sigma(end));
        [fitMu, fitSigma] = sanity_clamp(rawMu, rawSigma, record.levels, cfg);
    end

    sr = sr + 1;
    summaryRows(sr).scenario = names(scenario); %#ok<AGROW>
    summaryRows(sr).true_mu = trueMu(scenario);
    summaryRows(sr).true_sigma = trueSigma(scenario);
    summaryRows(sr).rounding_decimals = decimals(scenario);
    summaryRows(sr).overlap_test = overlapAt;
    summaryRows(sr).estimated_mu = fitMu;
    summaryRows(sr).estimated_sigma = fitSigma;
    summaryRows(sr).mu_error = fitMu - trueMu(scenario);
    summaryRows(sr).sigma_error = fitSigma - trueSigma(scenario);
    summaryRows(sr).duplicate_levels = budget - numel(unique(record.levels));
    summaryRows(sr).stage1_tests = sum(record.stage == 1);
    summaryRows(sr).stage2_tests = sum(record.stage == 2);
    summaryRows(sr).stage3_tests = sum(record.stage == 3);

    for k = 1:budget
        tr = tr + 1;
        trajectoryRows(tr).scenario = names(scenario); %#ok<AGROW>
        trajectoryRows(tr).test = k;
        trajectoryRows(tr).selected_level = record.levels(k);
        trajectoryRows(tr).latent_threshold = thresholds(k);
        trajectoryRows(tr).response_yes = record.successes(k);
        trajectoryRows(tr).recorded_stage = record.stage(k);
        trajectoryRows(tr).going_in_mu = record.est_mu(k);
        trajectoryRows(tr).going_in_sigma = record.est_sigma(k);
    end
end

summary = struct2table(summaryRows);
trajectories = struct2table(trajectoryRows);
writetable(summary, fullfile(root, 'simulation', 'baseline-scenario-summary.csv'));
writetable(trajectories, fullfile(root, 'simulation', 'baseline-scenario-trajectories.csv'));
disp(summary);
end
