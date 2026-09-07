project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
addpath(fullfile(project_root, 'application', 'source'));

outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
parameters = struct('avg_low', 8.6, 'avg_high', 9.4, 'spread_guess', 0.1);
[fitted_result, ~] = run_test(parameters, 20, @(~, test_number) outcomes(test_number));

gaps_mm = [2 3 4 4.61 5 6 7 8]';
interaction_best = zeros(size(gaps_mm));
interaction_claimed_minimum = zeros(size(gaps_mm));
no_interaction_best = zeros(size(gaps_mm));
no_interaction_claimed_minimum = zeros(size(gaps_mm));

for row_number = 1:numel(gaps_mm)
    gap_mm = gaps_mm(row_number);
    interaction = reliability_query(fitted_result, 'interaction', ...
        'probability_at', gap_mm, 0.95);
    no_interaction = reliability_query(fitted_result, 'no_interaction', ...
        'probability_at', gap_mm, 0.95);
    interaction_best(row_number) = interaction.probability;
    interaction_claimed_minimum(row_number) = interaction.bound_probability;
    no_interaction_best(row_number) = no_interaction.probability;
    no_interaction_claimed_minimum(row_number) = no_interaction.bound_probability;
end

evidence = table(gaps_mm, interaction_best, interaction_claimed_minimum, ...
    no_interaction_best, no_interaction_claimed_minimum);
output_path = fullfile(project_root, 'audit', 'overnight', ...
    'confirmed-fixed-gap-defect.csv');
writetable(evidence, output_path);
disp(evidence);
exit(0);
