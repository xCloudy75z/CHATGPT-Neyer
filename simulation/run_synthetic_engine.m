function outputFile = run_synthetic_engine(engineName, repetitions)
%RUN_SYNTHETIC_ENGINE Compare one extracted Neyer engine on seeded probit data.
% Each item has a latent N(mu,sigma) threshold and responds iff level >= threshold.

if nargin < 1, engineName = 'baseline'; end
if nargin < 2, repetitions = 100; end

root = fileparts(fileparts(mfilename('fullpath')));
if any(strcmp(engineName, {'shrink-only', 'transition-only', 'stage1-only'}))
    enginePath = fullfile(root, 'variants', engineName, 'functions');
else
    enginePath = fullfile(root, engineName, 'functions');
end
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

rng(20260905, 'twister');
sigmaRatios = [0.1 0.2 0.5 1 2 5 10];
meanOffsets = [0 2 5];
budgets = [20 50];
guessMu = 0;
guessSigma = 1;
paramsPublic = struct('avg_low', -4, 'avg_high', 4, 'spread_guess', guessSigma);
paramsInternal = struct('mu_min', -4, 'mu_max', 4, 'sigma_guess', guessSigma);
cfg = neyer_settings();
cfg.grid_points = 2001; % recorded speed/accuracy compromise; selection is rounded to .01
cfg.min_level = -Inf;

rows = struct([]);
row = 0;
for budget = budgets
    for meanOffset = meanOffsets
        for sigmaRatio = sigmaRatios
            overlap = false(repetitions, 1);
            overlapAt = NaN(repetitions, 1);
            muError = NaN(repetitions, 1);
            sigmaError = NaN(repetitions, 1);
            duplicateCount = zeros(repetitions, 1);
            clipHit = false(repetitions, 1);
            nonfinite = false(repetitions, 1);
            stage2Count = zeros(repetitions, 1);

            trueMu = guessMu + meanOffset * guessSigma;
            trueSigma = sigmaRatio * guessSigma;
            for rep = 1:repetitions
                thresholds = trueMu + trueSigma * randn(budget, 1);
                [~, record] = evalc('run_loop(paramsInternal, budget, @(level, k) level >= thresholds(k), cfg)');
                overlap(rep) = has_overlap(record.levels, record.successes);
                duplicateCount(rep) = budget - numel(unique(record.levels));
                stage2Count(rep) = sum(record.stage == 2);

                for k = 2:budget
                    if has_overlap(record.levels(1:k), record.successes(1:k))
                        overlapAt(rep) = k;
                        break;
                    end
                end

                if overlap(rep)
                    try
                        [rawMu, rawSigma] = best_fit(record.levels, record.successes, ...
                            record.est_mu(end), record.est_sigma(end));
                        [fitMu, fitSigma] = sanity_clamp(rawMu, rawSigma, record.levels, cfg);
                        clipHit(rep) = rawMu ~= fitMu || rawSigma ~= fitSigma;
                        nonfinite(rep) = ~isfinite(fitMu) || ~isfinite(fitSigma);
                        if ~nonfinite(rep)
                            muError(rep) = fitMu - trueMu;
                            sigmaError(rep) = fitSigma - trueSigma;
                        end
                    catch
                        nonfinite(rep) = true;
                    end
                end
            end

            row = row + 1;
            valid = isfinite(muError) & isfinite(sigmaError);
            rows(row).engine = string(engineName); %#ok<AGROW>
            rows(row).budget = budget;
            rows(row).mean_offset_guess_sigma = meanOffset;
            rows(row).true_sigma_ratio = sigmaRatio;
            rows(row).repetitions = repetitions;
            rows(row).overlap_rate = mean(overlap);
            rows(row).overlap_rate_se = sqrt(mean(overlap) * (1 - mean(overlap)) / repetitions);
            rows(row).mean_overlap_test = mean(overlapAt, 'omitnan');
            rows(row).mu_bias = mean(muError, 'omitnan');
            rows(row).mu_rmse = sqrt(mean(muError(valid).^2));
            rows(row).sigma_bias = mean(sigmaError, 'omitnan');
            rows(row).sigma_rmse = sqrt(mean(sigmaError(valid).^2));
            rows(row).clip_rate = mean(clipHit);
            rows(row).nonfinite_rate = mean(nonfinite);
            rows(row).mean_duplicate_levels = mean(duplicateCount);
            rows(row).mean_stage2_tests = mean(stage2Count);
            rows(row).grid_points = cfg.grid_points;
            rows(row).seed = 20260905;
        end
    end
end

results = struct2table(rows);
outputFile = fullfile(root, 'simulation', sprintf('%s-results.csv', engineName));
writetable(results, outputFile);
fprintf('WROTE %s (%d scenarios x %d repetitions)\n', outputFile, height(results), repetitions);
end
