function T = trace_increment_trap()
%TRACE_INCREMENT_TRAP Reproduce one narrow-spread, coarse-increment stall.
root = fileparts(fileparts(mfilename('fullpath')));
enginePath = fullfile(root, 'proposed', 'functions');
addpath(enginePath, '-begin');
cleanup = onCleanup(@() rmpath(enginePath)); %#ok<NASGU>

rng(20260909, 'twister');
params = struct('mu_min', 4, 'mu_max', 6, 'sigma_guess', 1);
cfg = neyer_settings(); cfg.grid_points = 2001;
budget = 50; trueMu = 5; trueSigma = 0.1; increment = 0.1;

for rep = 1:1000
    thresholds = trueMu + trueSigma * randn(budget, 1);
    levels = zeros(budget,1); yes = false(budget,1); stages=zeros(budget,1);
    workSigma=zeros(budget,1); rawPick=zeros(budget,1);
    working = params.sigma_guess; part2 = false;
    for k=1:budget
        sp=params; sp.working_sigma=working; sp.part2_started=part2;
        [raw,est]=choose_stage(levels(1:k-1),yes(1:k-1),sp,cfg);
        x=round(raw/increment)*increment;
        levels(k)=x; yes(k)=x>=thresholds(k); stages(k)=est.stage;
        workSigma(k)=working; rawPick(k)=raw;
        if est.stage==2
            part2=true; working=cfg.stage2_shrink*working;
        end
    end
    if ~has_overlap(levels,yes)
        T=table((1:budget)',rawPick,levels,yes,stages,workSigma,thresholds, ...
            'VariableNames',{'Test','RawPick','EquipmentLevel','Yes','Stage','WorkingSigma','Threshold'});
        fprintf('First failed repetition: %d; unique levels: %d\n',rep,numel(unique(levels)));
        disp(T(max(1,budget-14):budget,:));
        return;
    end
end
error('trace_increment_trap:noFailure','No failed run found.');
end
