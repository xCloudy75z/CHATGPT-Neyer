function summary = summarize_results()
root = fileparts(fileparts(mfilename('fullpath')));
baseline = readtable(fullfile(root, 'simulation', 'baseline-results.csv'), 'TextType', 'string');
proposed = readtable(fullfile(root, 'simulation', 'proposed-results.csv'), 'TextType', 'string');
keys = {'budget', 'mean_offset_guess_sigma', 'true_sigma_ratio'};
metrics = {'overlap_rate', 'mean_overlap_test', 'mu_rmse', 'sigma_rmse', ...
           'clip_rate', 'nonfinite_rate', 'mean_duplicate_levels', 'mean_stage2_tests'};
summary = outerjoin(baseline, proposed, 'Keys', keys, 'MergeKeys', true, ...
    'LeftVariables', metrics, 'RightVariables', metrics);
writetable(summary, fullfile(root, 'simulation', 'comparison-results.csv'));
disp(summary);
end
