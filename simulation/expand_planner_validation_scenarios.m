function scenarios = expand_planner_validation_scenarios(config)
%EXPAND_PLANNER_VALIDATION_SCENARIOS Expand a compact fixed-count grid.
% Normal validation configs pass through unchanged. A calibration config can
% declare one top-level list of candidate article counts, avoiding duplicated
% scenario definitions and accidental differences between candidates.
    if ~isstruct(config) || ~isfield(config, 'scenarios') || ...
            isempty(config.scenarios)
        error('expand_planner_validation_scenarios:noScenarios', ...
            'The validation configuration contains no scenarios.');
    end
    if ~isfield(config, 'fixed_validation_counts') || ...
            isempty(config.fixed_validation_counts)
        scenarios = config.scenarios;
        for scenario_index = 1:numel(scenarios)
            scenarios(scenario_index).seed_group_index = scenario_index;
            scenarios(scenario_index).base_scenario_id = ...
                char(string(scenarios(scenario_index).id));
        end
        return;
    end
    counts = config.fixed_validation_counts(:)';
    if any(~isfinite(counts)) || any(counts < 3) || any(counts ~= round(counts))
        error('expand_planner_validation_scenarios:badCounts', ...
            'Every fixed validation count must be a whole number of at least 3.');
    end
    base_scenarios = config.scenarios;
    output_index = 0;
    scenarios = struct([]);
    for base_index = 1:numel(base_scenarios)
        for count = counts
            one = base_scenarios(base_index);
            one.fixed_validation_count = count;
            one.seed_group_index = base_index;
            one.base_scenario_id = char(string(base_scenarios(base_index).id));
            one.id = sprintf('%s-n%d', char(string(one.id)), count);
            output_index = output_index + 1;
            if output_index == 1
                scenarios = one;
            else
                scenarios(output_index) = one; %#ok<AGROW>
            end
        end
    end
end
