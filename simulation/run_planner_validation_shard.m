function rows = run_planner_validation_shard(config_path, shard_index, ...
        shard_count, output_path, options)
%RUN_PLANNER_VALIDATION_SHARD Run one deterministic piece of the virtual study.
% Every article is a new build. Its real physical gap can vary, and 4 or 5
% repeated readings are averaged before the Neyer calculation sees that gap.

    if nargin < 5, options = struct(); end
    validate_shard_inputs(shard_index, shard_count, output_path);
    config = jsondecode(fileread(config_path));
    config_hash = planner_validation_hash(config_path);
    if ~isfield(config, 'scenarios') || isempty(config.scenarios)
        error('run_planner_validation_shard:noScenarios', ...
            'The validation configuration contains no scenarios.');
    end
    if ~isfield(config, 'base_seed'), config.base_seed = 2026090700; end
    if ~isfield(config, 'max_simulated_articles'), ...
            config.max_simulated_articles = 200; end
    if ~isfield(config, 'grid_points'), config.grid_points = 401; end
    if isfield(options, 'repetition_limit')
        repetition_limit = options.repetition_limit;
    else
        repetition_limit = Inf;
    end

    scenario_list = expand_planner_validation_scenarios(config);
    output_rows = struct([]);
    output_count = 0;
    global_row_number = 0;
    for scenario_index = 1:numel(scenario_list)
        scenario = scenario_list(scenario_index);
        repetitions = min(scenario.repetitions, repetition_limit);
        for repetition = 1:repetitions
            global_row_number = global_row_number + 1;
            assigned_shard = mod(global_row_number - 1, shard_count) + 1;
            if assigned_shard ~= shard_index, continue; end
            seed = config.base_seed + ...
                100000 * scenario.seed_group_index + repetition;
            fprintf('Shard %d/%d: %s, repetition %d/%d\n', ...
                shard_index, shard_count, scenario.id, repetition, repetitions);
            one_row = simulate_one(scenario, seed, config, config_hash, ...
                shard_index, shard_count);
            output_count = output_count + 1;
            if output_count == 1
                output_rows = one_row;
            else
                output_rows(output_count) = one_row; %#ok<AGROW>
            end
        end
    end
    if isempty(output_rows)
        rows = empty_output_table();
    else
        rows = struct2table(output_rows);
    end
    writetable(rows, output_path);
end

function row = simulate_one(scenario, seed, config, config_hash, ...
        shard_index, shard_count)
    model = scenario_reachable_model(scenario);
    clean = scenario_plan_answers(scenario);
    plan = estimate_study_plan(clean, model);
    if isfield(scenario, 'fixed_validation_count') && ...
            isfinite(scenario.fixed_validation_count) && ...
            scenario.fixed_validation_count >= 3
        fixed_count = round(scenario.fixed_validation_count);
        plan.main_articles = fixed_count;
        plan.reserve_1_articles = 0;
        plan.reserve_2_articles = 0;
        plan.total_articles = fixed_count;
    end
    planned_total = plan.total_articles;
    base = base_row(scenario, seed, config_hash, shard_index, shard_count, plan);
    if isfield(plan, 'reliability_instruction_supported') && ...
            ~plan.reliability_instruction_supported
        row = finish_withheld(base, 'withheld_outside_validation_envelope');
        return;
    end
    if ~plan.feasible
        row = finish_withheld(base, 'withheld_by_pretest_plan');
        return;
    end
    if planned_total > config.max_simulated_articles
        row = finish_withheld(base, 'withheld_above_simulation_limit');
        return;
    end

    rng(seed, 'twister');
    article_thresholds = scenario.true_middle_mm + ...
        scenario.true_sigma_mm * randn(planned_total, 1);
    rng(seed + 10000000, 'twister');
    build_errors = scenario.build_sd_mm * randn(planned_total, 1);
    rng(seed + 20000000, 'twister');
    reading_errors = scenario.measurement_sd_mm * ...
        randn(scenario.reading_count, planned_total);
    actual_gaps = NaN(planned_total, 1);

    settings = neyer_settings();
    settings.min_level = scenario.minimum_gap_mm;
    settings.max_level = scenario.maximum_gap_mm;
    settings.grid_points = config.grid_points;
    settings.confidence_level = scenario.confidence;
    settings.reachable_model = model;
    settings.resolution_sigma_floor_factor = 2;
    if strcmp(model.mode, 'regular')
        settings.level_increment = scenario.increment_mm;
    elseif isfield(settings, 'level_increment')
        settings = rmfield(settings, 'level_increment');
    end
    parameters = struct('mu_min', scenario.interaction_endpoint_mm, ...
        'mu_max', scenario.no_interaction_endpoint_mm, ...
        'sigma_guess', scenario.true_sigma_mm);
    record = struct();

    try
        evalc('record = run_loop(parameters, planned_total, @physical_response, settings);');
        [final_result, final_decision, checkpoint_name] = ...
            evaluate_checkpoints(record, settings, plan);
        row = complete_row(base, final_result, final_decision, ...
            checkpoint_name, scenario, plan, record, actual_gaps);
    catch simulation_error
        row = finish_withheld(base, 'simulation_error');
        row.error_identifier = string(simulation_error.identifier);
    end

    function response = physical_response(requested_gap_mm, article_number)
        actual_gap_mm = requested_gap_mm + build_errors(article_number);
        actual_gap_mm = min(max(actual_gap_mm, scenario.minimum_gap_mm), ...
            scenario.maximum_gap_mm);
        actual_gaps(article_number) = actual_gap_mm;
        readings = actual_gap_mm + reading_errors(:, article_number);
        response = struct('outcome', ...
            actual_gap_mm <= article_thresholds(article_number), ...
            'measurements', readings(:)');
    end
end

function [result, decision, checkpoint_name] = evaluate_checkpoints(record, settings, plan)
    names = {'main', 'reserve_1', 'reserve_2'};
    counts = [plan.main_articles, ...
        plan.main_articles + plan.reserve_1_articles, ...
        plan.total_articles];
    keep = [true, plan.reserve_1_articles > 0, plan.reserve_2_articles > 0];
    names = names(keep);
    counts = counts(keep);
    result = struct();
    decision = struct('status', 'unsupported');
    checkpoint_name = names{end};
    for checkpoint_index = 1:numel(names)
        count = min(counts(checkpoint_index), numel(record.levels));
        prefix = prefix_record(record, count);
        evalc('result = report(prefix, settings);');
        decision = check_study_checkpoint(result, plan, names{checkpoint_index});
        checkpoint_name = names{checkpoint_index};
        if strcmp(decision.status, 'complete') || ...
                strcmp(decision.status, 'unsupported')
            return;
        end
    end
end

function prefix = prefix_record(record, count)
    vector_fields = {'levels', 'successes', 'est_mu', 'est_sigma', 'stage', ...
        'clamped', 'raw_requested_levels', 'requested_levels', ...
        'requested_instructions'};
    prefix = record;
    for field_index = 1:numel(vector_fields)
        field_name = vector_fields{field_index};
        prefix.(field_name) = record.(field_name)(1:count);
    end
    prefix.measurements = record.measurements(1:count);
    prefix.N = count;
    prefix.requested_N = count;
end

function row = complete_row(row, result, decision, checkpoint_name, ...
        scenario, plan, record, actual_gaps)
    row.run_status = "simulated";
    row.actual_articles = result.n;
    row.checkpoint = string(checkpoint_name);
    row.checkpoint_status = string(decision.status);
    row.usable_fit = double(result.has_overlap && isfinite(result.mu) && ...
        isfinite(result.sigma) && result.sigma > 0);
    row.fitted_middle_mm = result.mu;
    row.fitted_sigma_mm = result.sigma;
    row.middle_low_mm = result.mu_lo;
    row.middle_high_mm = result.mu_hi;
    row.middle_covered = double(row.usable_fit && ...
        result.mu_lo <= scenario.true_middle_mm && ...
        result.mu_hi >= scenario.true_middle_mm);
    row.accuracy_reached = double(row.usable_fit && ...
        0.5 * (result.mu_hi - result.mu_lo) <= plan.accuracy_mm);

    if row.usable_fit
        boundary = reliability_query(result, plan.outcome, 'gap_for', ...
            plan.reliability, plan.confidence);
        raw_boundary = boundary.raw_bound;
    else
        raw_boundary = NaN;
    end
    row.raw_boundary_mm = raw_boundary;
    reliability_distance = shape_model(plan.reliability, 'quantile');
    if strcmp(plan.outcome, 'interaction')
        true_boundary = scenario.true_middle_mm - ...
            reliability_distance * scenario.true_sigma_mm;
        boundary_conservative = isfinite(raw_boundary) && ...
            raw_boundary <= true_boundary;
    else
        true_boundary = scenario.true_middle_mm + ...
            reliability_distance * scenario.true_sigma_mm;
        boundary_conservative = isfinite(raw_boundary) && ...
            raw_boundary >= true_boundary;
    end
    row.true_boundary_mm = true_boundary;
    if strcmp(plan.outcome, 'interaction')
        row.boundary_safety_margin_mm = true_boundary - raw_boundary;
    else
        row.boundary_safety_margin_mm = raw_boundary - true_boundary;
    end
    row.boundary_conservative = double(boundary_conservative);

    inside = isfinite(raw_boundary) && ...
        raw_boundary >= plan.minimum_gap_mm && ...
        raw_boundary <= plan.maximum_gap_mm;
    reachable_safe = false;
    if inside
        [safe_gap, safe_status] = select_operating_gap(raw_boundary, ...
            plan.outcome, plan.reachable_model);
        if strcmp(plan.outcome, 'interaction')
            reachable_safe = strcmp(safe_status.code, 'ok') && ...
                safe_gap <= raw_boundary + plan.reachable_model.comparison_tolerance_mm;
        else
            reachable_safe = strcmp(safe_status.code, 'ok') && ...
                safe_gap >= raw_boundary - plan.reachable_model.comparison_tolerance_mm;
        end
    end
    row.reachable_safe = double(reachable_safe);
    final_coverage = operating_gap_coverage(raw_boundary, true_boundary, ...
        plan.outcome, plan.reachable_model);
    row.safe_operating_gap_mm = final_coverage.safe_gap_mm;
    row.operating_gap_conservative = double(final_coverage.conservative);
    reliability_floor_reached = true;
    if isfield(plan, 'reliability_validation_floor_articles')
        reliability_floor_reached = result.n >= ...
            plan.reliability_validation_floor_articles;
    end
    reliability_instruction_supported = true;
    if isfield(plan, 'reliability_instruction_supported')
        reliability_instruction_supported = ...
            plan.reliability_instruction_supported;
    end
    row.checkpoint_correct = double( ...
        strcmp(decision.status, 'complete') == ...
        logical(row.usable_fit && row.accuracy_reached && inside && ...
        reachable_safe && reliability_floor_reached && ...
        reliability_instruction_supported));
    used_actual = actual_gaps(1:min(numel(actual_gaps), numel(record.levels)));
    row.mean_absolute_build_error_mm = mean(abs( ...
        used_actual - record.requested_levels(1:numel(used_actual))), 'omitnan');
    row.error_identifier = "";
end

function row = base_row(scenario, seed, config_hash, shard_index, shard_count, plan)
    row = struct( ...
        'config_hash', string(config_hash), ...
        'shard_index', shard_index, 'shard_count', shard_count, ...
        'scenario_id', string(scenario.id), ...
        'row_key', string(sprintf('%s|%d', scenario.id, seed)), ...
        'seed', seed, 'outcome', string(scenario.outcome), ...
        'reliability', scenario.reliability, ...
        'confidence', scenario.confidence, ...
        'accuracy_mm', scenario.accuracy_mm, ...
        'capability', string(scenario.capability), ...
        'planned_main', plan.main_articles, ...
        'planned_reserve_1', plan.reserve_1_articles, ...
        'planned_reserve_2', plan.reserve_2_articles, ...
        'planned_total', plan.total_articles, ...
        'run_status', "not_run", 'actual_articles', 0, ...
        'checkpoint', "", 'checkpoint_status', "", ...
        'usable_fit', NaN, 'fitted_middle_mm', NaN, ...
        'fitted_sigma_mm', NaN, 'middle_low_mm', NaN, ...
        'middle_high_mm', NaN, 'middle_covered', NaN, ...
        'accuracy_reached', NaN, 'raw_boundary_mm', NaN, ...
        'true_boundary_mm', NaN, 'boundary_safety_margin_mm', NaN, ...
        'boundary_conservative', NaN, ...
        'reachable_safe', NaN, 'safe_operating_gap_mm', NaN, ...
        'operating_gap_conservative', NaN, 'checkpoint_correct', NaN, ...
        'mean_absolute_build_error_mm', NaN, 'error_identifier', "");
end

function row = finish_withheld(row, reason)
    row.run_status = string(reason);
    row.checkpoint_status = "withheld";
    row.error_identifier = "";
end

function clean = scenario_plan_answers(scenario)
    clean = struct( ...
        'mode', 'requirements_first', ...
        'outcome', char(string(scenario.outcome)), ...
        'reliability', scenario.reliability, ...
        'confidence', scenario.confidence, ...
        'accuracy_mm', scenario.accuracy_mm, ...
        'interaction_gap_mm', scenario.interaction_endpoint_mm, ...
        'no_interaction_gap_mm', scenario.no_interaction_endpoint_mm, ...
        'minimum_gap_mm', scenario.minimum_gap_mm, ...
        'maximum_gap_mm', scenario.maximum_gap_mm, ...
        'previous_information', 'advanced_value', ...
        'previous_sigma_mm', scenario.true_sigma_mm, ...
        'physical_setup', char(string(scenario.capability)));
end

function model = scenario_reachable_model(scenario)
    capability = lower(char(string(scenario.capability)));
    if strcmp(capability, 'regular')
        setup = struct('mode', 'regular', 'increment_mm', scenario.increment_mm);
    elseif strcmp(capability, 'irregular')
        setup = struct('mode', 'list', 'gaps_mm', scenario.gaps_mm);
    else
        error('run_planner_validation_shard:badCapability', ...
            'Scenario capability must be regular or irregular.');
    end
    model = reachable_gap_model(setup, scenario.minimum_gap_mm, ...
        scenario.maximum_gap_mm);
end

function validate_shard_inputs(shard_index, shard_count, output_path)
    if ~(isscalar(shard_count) && shard_count == floor(shard_count) && shard_count >= 1)
        error('run_planner_validation_shard:badShardCount', ...
            'Shard count must be a positive whole number.');
    end
    if ~(isscalar(shard_index) && shard_index == floor(shard_index) && ...
            shard_index >= 1 && shard_index <= shard_count)
        error('run_planner_validation_shard:badShardIndex', ...
            'Shard index must be between 1 and the shard count.');
    end
    if isfile(output_path)
        error('run_planner_validation_shard:outputExists', ...
            'The shard output already exists; it will not be overwritten.');
    end
end

function table_value = empty_output_table()
    table_value = table();
end
