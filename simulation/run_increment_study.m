function outputFile = run_increment_study(repetitions)
%RUN_INCREMENT_STUDY Fair paired study of fixed level increments.
% Uses abstract normal thresholds and the corrected proposed algorithm. The
% same latent specimens are replayed for every increment in each scenario.

if nargin < 1, repetitions = 200; end

root = fileparts(fileparts(mfilename('fullpath')));
enginePath = fullfile(root, 'proposed', 'functions');
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

seed = 20260908;
rng(seed, 'twister');
increments = [0.01 0.05 0.10 0.25];
trueSigmas = [0.10 0.20 0.50 1.00];
budgets = [20 50];
trueMu = 5;
params = struct('mu_min', 4, 'mu_max', 6, 'sigma_guess', 1);
cfg = neyer_settings();
cfg.grid_points = 2001;
cfg.min_level = -Inf;

rows = struct([]); row = 0;
for budget = budgets
    for trueSigma = trueSigmas
        % Pair the equipment settings by using the same virtual specimens.
        latentZ = randn(budget, repetitions);
        for increment = increments
            overlap = false(repetitions, 1);
            overlapAt = NaN(repetitions, 1);
            muError = NaN(repetitions, 1);
            sigmaError = NaN(repetitions, 1);
            duplicateCount = zeros(repetitions, 1);

            for rep = 1:repetitions
                thresholds = trueMu + trueSigma * latentZ(:, rep);
                record = run_quantized_loop(params, budget, thresholds, cfg, increment);
                overlap(rep) = has_overlap(record.levels, record.successes);
                duplicateCount(rep) = budget - numel(unique(record.levels));

                for k = 2:budget
                    if has_overlap(record.levels(1:k), record.successes(1:k))
                        overlapAt(rep) = k;
                        break;
                    end
                end

                if overlap(rep)
                    [mu, sigma] = best_fit(record.levels, record.successes, ...
                        record.est_mu(end), record.est_sigma(end));
                    [mu, sigma] = sanity_clamp(mu, sigma, record.levels, cfg);
                    if isfinite(mu) && isfinite(sigma)
                        muError(rep) = mu - trueMu;
                        sigmaError(rep) = sigma - trueSigma;
                    end
                end
            end

            valid = isfinite(muError) & isfinite(sigmaError);
            row = row + 1;
            rows(row).budget = budget; %#ok<AGROW>
            rows(row).true_sigma = trueSigma;
            rows(row).increment = increment;
            rows(row).increment_over_sigma = increment / trueSigma;
            rows(row).repetitions = repetitions;
            rows(row).overlap_rate = mean(overlap);
            rows(row).mean_overlap_test = mean(overlapAt, 'omitnan');
            rows(row).mu_bias = mean(muError, 'omitnan');
            rows(row).mu_rmse = sqrt(mean(muError(valid).^2));
            rows(row).sigma_bias = mean(sigmaError, 'omitnan');
            rows(row).sigma_rmse = sqrt(mean(sigmaError(valid).^2));
            rows(row).mean_duplicate_levels = mean(duplicateCount);
            rows(row).seed = seed;
        end
    end
end

results = struct2table(rows);
outputFile = fullfile(root, 'simulation', 'increment-study-results.csv');
writetable(results, outputFile);
fprintf('WROTE %s (%d scenarios x %d repetitions)\n', ...
    outputFile, height(results), repetitions);
end

function record = run_quantized_loop(params, budget, thresholds, cfg, increment)
levels = zeros(budget, 1);
successes = false(budget, 1);
estMu = zeros(budget, 1);
estSigma = zeros(budget, 1);
stage = zeros(budget, 1);
workingSigma = params.sigma_guess;
part2Started = false;

for k = 1:budget
    stepParams = params;
    stepParams.working_sigma = workingSigma;
    stepParams.part2_started = part2Started;
    [x, est] = choose_stage(levels(1:k-1), successes(1:k-1), stepParams, cfg);
    x = round(x / increment) * increment;
    levels(k) = x;
    successes(k) = x >= thresholds(k);
    estMu(k) = est.mu;
    estSigma(k) = est.sigma;
    stage(k) = est.stage;
    if est.stage == 2
        part2Started = true;
        workingSigma = cfg.stage2_shrink * workingSigma;
    end
end

record = struct('levels', levels, 'successes', successes, ...
    'est_mu', estMu, 'est_sigma', estSigma, 'stage', stage);
end
