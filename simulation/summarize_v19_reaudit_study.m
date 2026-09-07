function [scenarioFile,summaryFile]=summarize_v19_reaudit_study(shardCount,repetitions)
%SUMMARIZE_V19_REAUDIT_STUDY Merge shards and create checked headline tables.

if nargin<1 || isempty(shardCount), shardCount=4; end
if nargin<2 || isempty(repetitions), repetitions=300; end
root=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(root,'audit','v19-reaudit');

rows=table();
for shardIndex=1:shardCount
    shardFile=fullfile(folder,sprintf( ...
        'v19-reaudit-shard-%d-of-%d.csv',shardIndex,shardCount));
    if ~isfile(shardFile)
        error('summarize_v19_reaudit_study:missingShard', ...
            'Missing simulation shard: %s',shardFile);
    end
    part=readtable(shardFile);
    rows=[rows;part]; %#ok<AGROW>
end

keyNames={'budget','true_sigma','increment','floor_factor', ...
    'single_reading_sd','reading_count','build_sd_factor'};
rows=sortrows(rows,keyNames);
expectedScenarios=2*3*2*3*2*2*3;
if height(rows)~=expectedScenarios
    error('summarize_v19_reaudit_study:wrongCount', ...
        'Expected %d scenarios but found %d.',expectedScenarios,height(rows));
end
if any(rows.repetitions~=repetitions)
    error('summarize_v19_reaudit_study:wrongRepetitions', ...
        'Every scenario must contain %d repetitions.',repetitions);
end
if height(unique(rows(:,keyNames)))~=height(rows)
    error('summarize_v19_reaudit_study:duplicateScenario', ...
        'A scenario appears more than once in the merged evidence.');
end

rows.repeated_setting_rate=rows.mean_duplicates./rows.budget;
rows.nonfinite_fit_rate=1-rows.recorded_overlap_rate;
scenarioFile=fullfile(folder,'v19-reaudit-simulation.csv');
writetable(rows,scenarioFile);

groups=findgroups(rows.budget,rows.increment,rows.floor_factor);
summary=table();
summary.budget=splitapply(@(x)x(1),rows.budget,groups);
summary.increment=splitapply(@(x)x(1),rows.increment,groups);
summary.floor_factor=splitapply(@(x)x(1),rows.floor_factor,groups);
summary.scenarios=splitapply(@numel,rows.budget,groups);
summary.total_runs=summary.scenarios*repetitions;
summary.actual_strict_overlap_percent=100*splitapply(@mean, ...
    rows.actual_overlap_rate,groups);
summary.false_overlap_percent=100*splitapply(@mean, ...
    rows.false_overlap_rate,groups);
summary.middle_gap_rmse=splitapply(@(x)sqrt(mean(x.^2,'omitnan')), ...
    rows.mu_rmse,groups);
summary.transition_width_rmse=splitapply(@(x)sqrt(mean(x.^2,'omitnan')), ...
    rows.sigma_rmse,groups);
summary.mean_repeated_setting_percent=100*splitapply(@mean, ...
    rows.repeated_setting_rate,groups);
summary.no_finite_fit_percent=100*splitapply(@mean, ...
    rows.nonfinite_fit_rate,groups);
summaryFile=fullfile(folder,'v19-reaudit-simulation-summary.csv');
writetable(summary,summaryFile);

fprintf('Merged %d scenarios and %d synthetic runs.\n', ...
    height(rows),height(rows)*repetitions);
fprintf('Scenario evidence: %s\n',scenarioFile);
fprintf('Summary evidence: %s\n',summaryFile);
end
