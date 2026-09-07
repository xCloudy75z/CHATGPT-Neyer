function record=simulate_v19_physical_run(params,budget,thresholds, ...
    readingErrors,buildErrors,cfg)
%SIMULATE_V19_PHYSICAL_RUN Simulate one destructive physical gap study.
%   The reachable setting is what the equipment is asked to build. Build
%   variation creates the actual physical gap. Interaction is determined by
%   that actual gap, while repeated measurement errors create the measured
%   mean supplied to the Neyer calculation.

levels=zeros(budget,1);
actual=zeros(budget,1);
reachable=zeros(budget,1);
interaction=false(budget,1);
estimatedMiddle=zeros(budget,1);
estimatedSigma=zeros(budget,1);
stage=zeros(budget,1);
workingSigma=params.sigma_guess;
partTwoStarted=false;

if numel(thresholds)~=budget || numel(buildErrors)~=budget || ...
        size(readingErrors,2)~=budget
    error('simulate_v19_physical_run:sizeMismatch', ...
        'Thresholds, build errors, and reading-error columns must match the test budget.');
end

for testNumber=1:budget
    stepParams=params;
    stepParams.working_sigma=workingSigma;
    stepParams.part2_started=partTwoStarted;
    [rawSetting,estimate]=choose_stage(levels(1:testNumber-1), ...
        interaction(1:testNumber-1),stepParams,cfg, ...
        reachable(1:testNumber-1));

    reachableSetting=round(rawSetting/cfg.level_increment)*cfg.level_increment;
    reachableSetting=min(max(reachableSetting,cfg.min_level),cfg.max_level);
    actualGap=min(max(reachableSetting+buildErrors(testNumber), ...
        cfg.min_level),cfg.max_level);
    measuredMean=mean(actualGap+readingErrors(:,testNumber));

    reachable(testNumber)=reachableSetting;
    actual(testNumber)=actualGap;
    levels(testNumber)=measuredMean;
    interaction(testNumber)=actualGap<=thresholds(testNumber);
    estimatedMiddle(testNumber)=estimate.mu;
    estimatedSigma(testNumber)=estimate.sigma;
    stage(testNumber)=estimate.stage;

    if estimate.stage==2
        partTwoStarted=true;
        workingSigma=max(cfg.stage2_shrink*workingSigma, ...
            cfg.level_increment*cfg.resolution_sigma_floor_factor);
    end
end

record=struct('levels',levels,'actual_levels',actual, ...
    'reachable_levels',reachable,'successes',interaction, ...
    'est_mu',estimatedMiddle,'est_sigma',estimatedSigma,'stage',stage);
end
