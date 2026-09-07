function outputFile=run_resolution_floor_study(repetitions)
%RUN_RESOLUTION_FLOOR_STUDY Compare equipment-aware Stage-2 sigma floors.
if nargin<1,repetitions=100;end
root=fileparts(fileparts(mfilename('fullpath')));
enginePath=fullfile(root,'proposed','functions');
addpath(enginePath,'-begin');
cleanup=onCleanup(@()rmpath(enginePath)); %#ok<NASGU>

rng(20260911,'twister');
increments=[0.05 0.10]; trueSigmas=[0.10 0.20 0.50];
floorFactors=[0 0.5 1 2]; budgets=[20 50];
params=struct('mu_min',4,'mu_max',6,'sigma_guess',1);
trueMu=5; cfg0=neyer_settings();cfg0.grid_points=1001;cfg0.min_level=-Inf;
rows=struct([]);row=0;

for budget=budgets
 for trueSigma=trueSigmas
  latentZ=randn(budget,repetitions);
  for increment=increments
   for factor=floorFactors
    overlap=false(repetitions,1); overlapAt=NaN(repetitions,1);
    muError=NaN(repetitions,1);sigmaError=NaN(repetitions,1);
    duplicates=zeros(repetitions,1);stage2Count=zeros(repetitions,1);
    cfg=cfg0;cfg.level_increment=increment;
    cfg.resolution_sigma_floor_factor=factor;
    for rep=1:repetitions
     thresholds=trueMu+trueSigma*latentZ(:,rep);
     record=run_loop(params,budget,@(x,k)x>=thresholds(k),cfg);
     overlap(rep)=has_overlap(record.levels,record.successes);
     duplicates(rep)=budget-numel(unique(record.levels));
     stage2Count(rep)=sum(record.stage==2);
     for k=2:budget
      if has_overlap(record.levels(1:k),record.successes(1:k))
       overlapAt(rep)=k;break
      end
     end
     if overlap(rep)
      [mu,sigma]=best_fit(record.levels,record.successes,record.est_mu(end),record.est_sigma(end));
      [mu,sigma]=sanity_clamp(mu,sigma,record.levels,cfg);
      if isfinite(mu)&&isfinite(sigma)
       muError(rep)=mu-trueMu;sigmaError(rep)=sigma-trueSigma;
      end
     end
    end
    valid=isfinite(muError)&isfinite(sigmaError);row=row+1;
    rows(row).budget=budget; %#ok<AGROW>
    rows(row).true_sigma=trueSigma;rows(row).increment=increment;
    rows(row).floor_factor=factor;rows(row).repetitions=repetitions;
    rows(row).overlap_rate=mean(overlap);
    rows(row).mean_overlap_test=mean(overlapAt,'omitnan');
    rows(row).mu_rmse=sqrt(mean(muError(valid).^2));
    rows(row).sigma_rmse=sqrt(mean(sigmaError(valid).^2));
    rows(row).sigma_bias=mean(sigmaError,'omitnan');
    rows(row).mean_duplicates=mean(duplicates);
    rows(row).mean_stage2_tests=mean(stage2Count);
   end
  end
 end
end
results=struct2table(rows);
outputFile=fullfile(root,'simulation','resolution-floor-results.csv');
writetable(results,outputFile);
fprintf('WROTE %s (%d scenarios x %d repetitions)\n',outputFile,height(results),repetitions);
end
