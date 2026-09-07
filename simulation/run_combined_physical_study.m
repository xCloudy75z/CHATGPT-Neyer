function outputFile=run_combined_physical_study(repetitions,opts)
%RUN_COMBINED_PHYSICAL_STUDY Resolution, measurement noise, and sigma floor.
%   Saves after every scenario. Re-running with the same output file,
%   repetitions, and seed skips completed scenarios and resumes safely.

if nargin<1 || isempty(repetitions), repetitions=300; end
if nargin<2, opts=struct(); end
root=fileparts(fileparts(mfilename('fullpath')));
enginePath=fullfile(root,'application','source');
addpath(enginePath,'-begin');
engineCleanup=onCleanup(@()rmpath(enginePath));
defaults=struct( ...
    'output_file',fullfile(root,'simulation','combined-physical-study-results.csv'), ...
    'budgets',[20 50], 'true_sigmas',[0.10 0.20 0.50], ...
    'increments',[0.05 0.10], 'floor_factors',[0 1 2], ...
    'reading_sds',[0.015 0.030], 'reading_counts',[4 5], ...
    'build_sd_factors',[0 0.25 0.50], ...
    'grid_points',1001, 'seed',20260912);
names=fieldnames(defaults);
for k=1:numel(names)
    if ~isfield(opts,names{k}), opts.(names{k})=defaults.(names{k}); end
end
outputFile=opts.output_file;

if isfile(outputFile)
    saved=readtable(outputFile);
else
    saved=table();
end
total=numel(opts.budgets)*numel(opts.true_sigmas)*numel(opts.increments)* ...
    numel(opts.floor_factors)*numel(opts.reading_sds)*numel(opts.reading_counts)* ...
    numel(opts.build_sd_factors);
completed=count_completed(saved,repetitions,opts.seed);
if completed>0
    fprintf('Skipping %d completed scenarios from %s.\n',completed,outputFile);
end

params=struct('mu_min',4,'mu_max',6,'sigma_guess',1);
trueMu=5; cfg0=neyer_settings(); cfg0.grid_points=opts.grid_points;
cfg0.min_level=0; cfg0.max_level=10;
scenario=0; group=0;
for budget=opts.budgets
 for trueSigma=opts.true_sigmas
  for increment=opts.increments
   for readingSD=opts.reading_sds
    for readingCount=opts.reading_counts
     group=group+1;
     for buildFactor=opts.build_sd_factors
      buildSD=increment*buildFactor;
      for factor=opts.floor_factors
       scenario=scenario+1;
       if scenario_done(saved,budget,trueSigma,increment,factor,readingSD, ...
               readingCount,buildFactor,repetitions,opts.seed)
           continue
       end
       fprintf(['Scenario %d/%d (%.1f%%): N=%d, sigma=%.3g, increment=%.3g, ' ...
           'floor=%.3g, readings=%d, reading SD=%.3g, build SD=%.3g\n'], ...
           scenario,total,100*scenario/total,budget,trueSigma,increment, ...
           factor,readingCount,readingSD,buildSD);
       row=run_scenario(params,trueMu,budget,trueSigma,increment,factor, ...
           readingSD,readingCount,buildFactor,buildSD,repetitions,cfg0, ...
           opts.seed+group);
       row.seed=opts.seed;
       if isempty(saved), saved=struct2table(row); else, saved=[saved;struct2table(row)]; end %#ok<AGROW>
       writetable(saved,outputFile);
       fprintf('  Saved %d/%d scenarios.\n',height(saved),total);
      end
     end
    end
   end
  end
 end
end
fprintf('COMPLETE: %s (%d scenarios x %d repetitions)\n', ...
    outputFile,height(saved),repetitions);
end

function row=run_scenario(params,trueMu,budget,trueSigma,increment,factor, ...
    readingSD,readingCount,buildFactor,buildSD,repetitions,cfg,scenarioSeed)
rng(scenarioSeed,'twister');
latentZ=randn(budget,repetitions);
readingZ=randn(readingCount,budget,repetitions);
buildZ=randn(budget,repetitions);
recorded=false(repetitions,1); actual=false(repetitions,1);
muError=NaN(repetitions,1); sigmaError=NaN(repetitions,1);
recordError=zeros(repetitions,1); duplicates=zeros(repetitions,1);
buildError=zeros(repetitions,1);
stage2Count=zeros(repetitions,1);
cfg.level_increment=increment; cfg.resolution_sigma_floor_factor=factor;
for rep=1:repetitions
    thresholds=trueMu+trueSigma*latentZ(:,rep);
    errors=readingSD*readingZ(:,:,rep);
    run=measured_gap_loop(params,budget,thresholds,errors, ...
        buildSD*buildZ(:,rep),cfg);
    recorded(rep)=has_overlap(run.levels,run.successes);
    actual(rep)=has_overlap(run.actual_levels,run.successes);
    recordError(rep)=mean(abs(run.levels-run.actual_levels));
    buildError(rep)=mean(abs(run.actual_levels-run.reachable_levels));
    duplicates(rep)=budget-numel(unique(run.reachable_levels));
    stage2Count(rep)=sum(run.stage==2);
    if recorded(rep)
        [mu,sigma]=best_fit(run.levels,run.successes, ...
            run.est_mu(end),run.est_sigma(end));
        [mu,sigma]=sanity_clamp(mu,sigma,run.levels,cfg);
        if isfinite(mu)&&isfinite(sigma)
            muError(rep)=mu-trueMu; sigmaError(rep)=sigma-trueSigma;
        end
    end
end
valid=isfinite(muError)&isfinite(sigmaError);
row=struct('budget',budget,'true_sigma',trueSigma,'increment',increment, ...
    'floor_factor',factor,'single_reading_sd',readingSD, ...
    'reading_count',readingCount,'expected_average_sd',readingSD/sqrt(readingCount), ...
    'build_sd_factor',buildFactor,'build_sd',buildSD, ...
    'repetitions',repetitions,'recorded_overlap_rate',mean(recorded), ...
    'actual_overlap_rate',mean(actual), ...
    'false_overlap_rate',mean(recorded & ~actual), ...
    'mu_bias',mean(muError,'omitnan'),'mu_rmse',sqrt(mean(muError(valid).^2)), ...
    'sigma_bias',mean(sigmaError,'omitnan'), ...
    'sigma_rmse',sqrt(mean(sigmaError(valid).^2)), ...
    'mean_abs_record_error',mean(recordError), ...
    'mean_abs_build_error',mean(buildError), ...
    'mean_duplicates',mean(duplicates),'mean_stage2_tests',mean(stage2Count));
end

function record=measured_gap_loop(params,budget,thresholds,errors,buildErrors,cfg)
levels=zeros(budget,1); actual=zeros(budget,1); reachable=zeros(budget,1);
yes=false(budget,1);
estMu=zeros(budget,1); estSigma=zeros(budget,1); stage=zeros(budget,1);
working=params.sigma_guess;
part2=false;
for k=1:budget
    sp=params; sp.working_sigma=working; sp.part2_started=part2;
    [raw,est]=choose_stage(levels(1:k-1),yes(1:k-1),sp,cfg,reachable(1:k-1));
    setting=round(raw/cfg.level_increment)*cfg.level_increment;
    setting=min(max(setting,cfg.min_level),cfg.max_level);
    reachable(k)=setting;
    actual(k)=min(max(setting+buildErrors(k),cfg.min_level),cfg.max_level);
    measured=mean(actual(k)+errors(:,k));
    levels(k)=measured;
    yes(k)=setting<=thresholds(k);
    estMu(k)=est.mu; estSigma(k)=est.sigma; stage(k)=est.stage;
    if est.stage==2
        part2=true;
        working=max(cfg.stage2_shrink*working, ...
            cfg.level_increment*cfg.resolution_sigma_floor_factor);
    end
end
record=struct('levels',levels,'actual_levels',actual, ...
    'reachable_levels',reachable,'successes',yes, ...
    'est_mu',estMu,'est_sigma',estSigma,'stage',stage);
end

function n=count_completed(saved,repetitions,seed)
if isempty(saved), n=0; return; end
n=sum(saved.repetitions==repetitions & saved.seed==seed);
end

function tf=scenario_done(saved,budget,trueSigma,increment,factor,readingSD, ...
    readingCount,buildFactor,repetitions,seed)
if isempty(saved), tf=false; return; end
tf=any(saved.budget==budget & saved.true_sigma==trueSigma & ...
    saved.increment==increment & saved.floor_factor==factor & ...
    saved.single_reading_sd==readingSD & saved.reading_count==readingCount & ...
    saved.build_sd_factor==buildFactor & ...
    saved.repetitions==repetitions & saved.seed==seed);
end
