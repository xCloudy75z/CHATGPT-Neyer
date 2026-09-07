function outputFile=run_combined_physical_study(repetitions,opts)
%RUN_COMBINED_PHYSICAL_STUDY Resolution, measurement noise, and sigma floor.
%   Saves after every scenario. Re-running with the same output file,
%   repetitions, and seed skips completed scenarios and resumes safely.
%   The physical outcome is generated from the actual built gap after build
%   variation, while the Neyer engine receives the repeated-reading mean.
%   Scenario shards allow separate MATLAB processes to share the work when
%   Parallel Computing Toolbox is not installed.

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
    'grid_points',1001, 'seed',20260912, ...
    'use_parallel',false,'parallel_workers',8, ...
    'scenario_shard_index',1,'scenario_shard_count',1);
names=fieldnames(defaults);
for k=1:numel(names)
    if ~isfield(opts,names{k}), opts.(names{k})=defaults.(names{k}); end
end
outputFile=opts.output_file;

if ~(isscalar(opts.scenario_shard_count) && opts.scenario_shard_count>=1 && ...
        opts.scenario_shard_count==floor(opts.scenario_shard_count) && ...
        isscalar(opts.scenario_shard_index) && opts.scenario_shard_index>=1 && ...
        opts.scenario_shard_index<=opts.scenario_shard_count && ...
        opts.scenario_shard_index==floor(opts.scenario_shard_index))
    error('run_combined_physical_study:badShard', ...
        'Scenario shard index must be an integer from 1 through the shard count.');
end

useParallel=logical(opts.use_parallel);
executionMode='serial';
if opts.scenario_shard_count>1
    executionMode='process-shard';
end
if useParallel
    try
        if ~license('test','Distrib_Computing_Toolbox')
            error('Parallel Computing Toolbox is unavailable.');
        end
        pool=gcp('nocreate');
        if isempty(pool)
            parpool('local',opts.parallel_workers);
        end
        executionMode='parallel';
    catch parallelError
        warning('run_combined_physical_study:parallelUnavailable', ...
            'Parallel execution was unavailable; using serial execution. %s', ...
            parallelError.message);
        useParallel=false;
    end
end

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
       if mod(scenario-1,opts.scenario_shard_count)+1 ~= ...
               opts.scenario_shard_index
           continue
       end
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
           opts.seed+group,useParallel,executionMode, ...
           opts.scenario_shard_index,opts.scenario_shard_count);
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
    readingSD,readingCount,buildFactor,buildSD,repetitions,cfg,scenarioSeed, ...
    useParallel,executionMode,scenarioShardIndex,scenarioShardCount)
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
if useParallel
    parfor rep=1:repetitions
        [recorded(rep),actual(rep),muError(rep),sigmaError(rep), ...
            recordError(rep),buildError(rep),duplicates(rep),stage2Count(rep)]= ...
            evaluate_physical_repetition(params,trueMu,trueSigma,budget, ...
            latentZ(:,rep),readingSD*readingZ(:,:,rep), ...
            buildSD*buildZ(:,rep),cfg);
    end
else
    for rep=1:repetitions
        [recorded(rep),actual(rep),muError(rep),sigmaError(rep), ...
            recordError(rep),buildError(rep),duplicates(rep),stage2Count(rep)]= ...
            evaluate_physical_repetition(params,trueMu,trueSigma,budget, ...
            latentZ(:,rep),readingSD*readingZ(:,:,rep), ...
            buildSD*buildZ(:,rep),cfg);
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
    'mean_duplicates',mean(duplicates),'mean_stage2_tests',mean(stage2Count), ...
    'execution_mode',executionMode, ...
    'scenario_shard_index',scenarioShardIndex, ...
    'scenario_shard_count',scenarioShardCount);
end

function [recordedOverlap,actualOverlap,middleError,widthError, ...
    recordError,buildError,duplicateCount,stageTwoCount]= ...
    evaluate_physical_repetition(params,trueMu,trueSigma,budget,latentZ, ...
    readingErrors,buildErrors,cfg)
thresholds=trueMu+trueSigma*latentZ;
run=simulate_v19_physical_run(params,budget,thresholds,readingErrors, ...
    buildErrors,cfg);
recordedOverlap=has_overlap(run.levels,run.successes);
actualOverlap=has_overlap(run.actual_levels,run.successes);
recordError=mean(abs(run.levels-run.actual_levels));
buildError=mean(abs(run.actual_levels-run.reachable_levels));
duplicateCount=budget-numel(unique(run.reachable_levels));
stageTwoCount=sum(run.stage==2);
middleError=NaN;
widthError=NaN;
if recordedOverlap
    [middle,width]=best_fit(run.levels,run.successes, ...
        run.est_mu(end),run.est_sigma(end));
    [middle,width]=sanity_clamp(middle,width,run.levels,cfg);
    if isfinite(middle)&&isfinite(width)
        middleError=middle-trueMu;
        widthError=width-trueSigma;
    end
end
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
