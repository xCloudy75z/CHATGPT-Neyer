function outputFile = run_measurement_uncertainty_study(repetitions)
%RUN_MEASUREMENT_UNCERTAINTY_STUDY Effect of repeated reading noise.
% The physical setting is unchanged. Outcomes use that setting; the adaptive
% algorithm receives the mean of 1 or 5 noisy measurements of it.

if nargin < 1, repetitions = 100; end
root = fileparts(fileparts(mfilename('fullpath')));
enginePath = fullfile(root, 'proposed', 'functions');
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

seed = 20260910;
rng(seed, 'twister');
increments = [0.05 0.10];
trueSigmas = [0.10 0.20 0.50];
readingSDs = [0 0.015 0.030];
readingCounts = [1 5];
budgets = [20 50];
trueMu = 5;
params = struct('mu_min', 4, 'mu_max', 6, 'sigma_guess', 1);
cfg = neyer_settings(); cfg.grid_points = 1001; cfg.min_level = -Inf;

rows = struct([]); row = 0;
for budget = budgets
    for trueSigma = trueSigmas
        latentZ = randn(budget, repetitions);
        for readingSD = readingSDs
            readingZ = randn(5, budget, repetitions);
            for increment = increments
                for readingCount = readingCounts
                    overlap = false(repetitions,1);
                    actualOverlap = false(repetitions,1);
                    muError = NaN(repetitions,1);
                    sigmaError = NaN(repetitions,1);
                    meanAbsRecordError = zeros(repetitions,1);

                    for rep=1:repetitions
                        thresholds = trueMu + trueSigma * latentZ(:,rep);
                        errors = readingSD * readingZ(1:readingCount,:,rep);
                        record = measured_loop(params,budget,thresholds,cfg, ...
                            increment,errors);
                        overlap(rep)=has_overlap(record.levels,record.successes);
                        actualOverlap(rep)=has_overlap(record.actual_levels,record.successes);
                        meanAbsRecordError(rep)=mean(abs(record.levels-record.actual_levels));
                        if overlap(rep)
                            [mu,sigma]=best_fit(record.levels,record.successes, ...
                                record.est_mu(end),record.est_sigma(end));
                            [mu,sigma]=sanity_clamp(mu,sigma,record.levels,cfg);
                            if isfinite(mu)&&isfinite(sigma)
                                muError(rep)=mu-trueMu;
                                sigmaError(rep)=sigma-trueSigma;
                            end
                        end
                    end

                    valid=isfinite(muError)&isfinite(sigmaError);
                    row=row+1;
                    rows(row).budget=budget; %#ok<AGROW>
                    rows(row).true_sigma=trueSigma;
                    rows(row).increment=increment;
                    rows(row).single_reading_sd=readingSD;
                    rows(row).reading_count=readingCount;
                    rows(row).expected_average_sd=readingSD/sqrt(readingCount);
                    rows(row).repetitions=repetitions;
                    rows(row).overlap_rate=mean(overlap);
                    rows(row).actual_overlap_rate=mean(actualOverlap);
                    rows(row).measurement_only_overlap_rate=mean(overlap & ~actualOverlap);
                    rows(row).mu_bias=mean(muError,'omitnan');
                    rows(row).mu_rmse=sqrt(mean(muError(valid).^2));
                    rows(row).sigma_bias=mean(sigmaError,'omitnan');
                    rows(row).sigma_rmse=sqrt(mean(sigmaError(valid).^2));
                    rows(row).mean_abs_record_error=mean(meanAbsRecordError);
                    rows(row).seed=seed;
                end
            end
        end
    end
end

results=struct2table(rows);
outputFile=fullfile(root,'simulation','measurement-uncertainty-results.csv');
writetable(results,outputFile);
fprintf('WROTE %s (%d scenarios x %d repetitions)\n',outputFile,height(results),repetitions);
end

function record=measured_loop(params,budget,thresholds,cfg,increment,errors)
levels=zeros(budget,1); actual=zeros(budget,1); yes=false(budget,1);
estMu=zeros(budget,1); estSigma=zeros(budget,1);
working=params.sigma_guess; part2=false;
for k=1:budget
    sp=params; sp.working_sigma=working; sp.part2_started=part2;
    [raw,est]=choose_stage(levels(1:k-1),yes(1:k-1),sp,cfg);
    actual(k)=round(raw/increment)*increment;
    readings=actual(k)+errors(:,k);
    levels(k)=mean(readings);
    yes(k)=actual(k)>=thresholds(k);
    estMu(k)=est.mu; estSigma(k)=est.sigma;
    if est.stage==2
        part2=true; working=cfg.stage2_shrink*working;
    end
end
record=struct('levels',levels,'actual_levels',actual,'successes',yes, ...
    'est_mu',estMu,'est_sigma',estSigma);
end
