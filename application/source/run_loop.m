function record = run_loop(params, num_parts, outcome_fn, cfg)
%RUN_LOOP  Worker #8 — the conductor of the test.
%
%   record = RUN_LOOP(params, num_parts, outcome_fn, cfg) runs the sensitivity
%   test for num_parts items: at each step it asks choose_stage (worker #6) for
%   the next level,
%   obtains the interaction/no-interaction outcome, records it, and stops when the budget is
%   spent.  [brief sec.4 worker #8]
%
%   Inputs
%     params      starting guess: .mu_min, .mu_max, .sigma_guess.
%     num_parts   item budget (number of destructive tests).
%     outcome_fn  function handle giving the result of testing at a level:
%                     result = outcome_fn(level, k)
%                 where level is the chosen stimulus, k is the 1-based test
%                 index, and result is true for interaction / false for no
%                 interaction. A real operator ignores k and tests the
%                 item at `level`; the acceptance test uses k to replay Neyer's
%                 fixed Table 1 outcomes (feeding fixed outcomes isolates the
%                 logic from physical chance -- brief sec.7).
%     cfg         settings struct (optional; defaults to settings()).
%
%   Output: record struct with one row per test (column vectors of length num_parts):
%     .levels      level tested at each step.
%     .successes   logical outcome at each step (true = interaction).
%     .est_mu      average the method held going in to each step.
%     .est_sigma   spread the method held going in to each step.
%     .stage       which stage (1/2/3) chose each step.
%     .clamped     true at steps whose level was tested at the physical floor
%                  (cfg.min_level) instead of the method's raw pick.
%     .params, .N  echoed back for report / reproducibility (.N = num_parts).

    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if ~isa(outcome_fn, 'function_handle')
        error('run_loop:badOutcomeFn', 'outcome_fn must be a function handle.');
    end
    % Physical floor must be -Inf (off) or a finite real scalar; reject +Inf/NaN.
    if ~(isscalar(cfg.min_level) && isreal(cfg.min_level) && ~isnan(cfg.min_level) && cfg.min_level < Inf)
        error('run_loop:badMinLevel', ...
              'cfg.min_level must be -Inf (no floor) or a finite real scalar.');
    end
    if ~(isfield(cfg,'max_level') && isscalar(cfg.max_level) && ...
            isreal(cfg.max_level) && isfinite(cfg.max_level) && ...
            cfg.max_level > cfg.min_level)
        error('run_loop:badMaxLevel', ...
              'cfg.max_level must be finite and greater than cfg.min_level.');
    end

    levels    = zeros(num_parts, 1);
    successes = false(num_parts, 1);
    est_mu    = zeros(num_parts, 1);
    est_sigma = zeros(num_parts, 1);
    stage     = zeros(num_parts, 1);
    clamped   = false(num_parts, 1);
    raw_requested_levels = zeros(num_parts,1);
    requested_levels = zeros(num_parts,1);
    requested_instructions = strings(num_parts,1);
    measurements = cell(num_parts,1);
    nudged    = false;
    working_sigma = params.sigma_guess;
    part2_started = false;
    boundary_confirmation = '';
    status = 'complete';
    stop_reason = '';
    checkpoint_decisions = cell(0, 1);
    last_k = num_parts;

    has_reachable_model = isfield(cfg, 'reachable_model') && ...
        ~isempty(cfg.reachable_model);
    if has_reachable_model
        if ~isstruct(cfg.reachable_model) || ...
                ~isfield(cfg.reachable_model, 'gaps_mm') || ...
                isempty(cfg.reachable_model.gaps_mm)
            error('run_loop:badReachableModel', ...
                'The reachable physical-gap list is empty or invalid.');
        end
        tolerance = cfg.reachable_model.comparison_tolerance_mm;
        inside_bounds = cfg.reachable_model.gaps_mm >= cfg.min_level - tolerance & ...
            cfg.reachable_model.gaps_mm <= cfg.max_level + tolerance;
        if ~any(inside_bounds)
            error('run_loop:noReachableGapInsideBounds', ...
                'No reachable physical gap remains inside the permitted range.');
        end
        cfg.reachable_model.gaps_mm = ...
            cfg.reachable_model.gaps_mm(inside_bounds);
        cfg.reachable_model.instructions = ...
            cfg.reachable_model.instructions(inside_bounds);
        reachable_minimum = cfg.reachable_model.gaps_mm(1);
        reachable_maximum = cfg.reachable_model.gaps_mm(end);
    else
        reachable_minimum = cfg.min_level;
        reachable_maximum = cfg.max_level;
    end

    for k = 1:num_parts
        % Estimate held going in, and the level it implies.
        step_params = params;
        step_params.working_sigma = working_sigma;
        step_params.part2_started = part2_started;
        [x, est] = choose_stage(levels(1:k-1), successes(1:k-1), ...
            step_params, cfg, requested_levels(1:k-1));
        raw_x = x;

        % After one contradictory boundary result, repeat that same boundary
        % once as a confirmation instead of allowing the search to wander or
        % repeatedly clamp there without a decision.
        if strcmp(boundary_confirmation,'min')
            x = reachable_minimum;
            clamped(k) = true;
        elseif strcmp(boundary_confirmation,'max')
            x = reachable_maximum;
            clamped(k) = true;
        end

        % Round to the resolution a physical test can actually be set to, so
        % the recorded history matches what was tested (no full-precision drift).
        if has_reachable_model
            allow_repeat = ~isempty(boundary_confirmation);
            [x, reachable_status] = select_reachable_request(x, ...
                cfg.reachable_model, requested_levels(1:k-1), allow_repeat);
            if ~strcmp(reachable_status.code, 'ok')
                status = 'paused';
                stop_reason = 'no_different_reachable_gap';
                last_k = k - 1;
                fprintf([ ...
                    '  PAUSED - REVIEW REQUIRED: no different reachable gap remains.\n' ...
                    '  The completed study data are kept; this is not a failed physical test.\n']);
                break;
            end
            requested_instructions(k) = reachable_status.instruction;
        elseif isfield(cfg,'level_increment') && ~isempty(cfg.level_increment)
            x = round(x / cfg.level_increment) * cfg.level_increment;
        else
            x = round(x * 10^cfg.level_decimals) / 10^cfg.level_decimals;
        end

        % Physical floor: keep the tested level runnable on the rig. With the
        % default min_level = -Inf this never triggers (pure Neyer). If the floor
        % is set and the pick falls below it, test AT the floor (boundary test)
        % and say so; if the floor is off but a pick goes negative, nudge once.
        % [addendum MINLEVEL]
        if ~has_reachable_model && x < cfg.min_level
            x = cfg.min_level;
            clamped(k) = true;
            fprintf(['  (The method requested a gap below the permitted minimum of %.4g %s;\n' ...
                     '   this test will use the minimum gap instead.)\n'], ...
                    cfg.min_level,cfg.unit);
        elseif ~has_reachable_model && x > cfg.max_level
            x = cfg.max_level;
            clamped(k) = true;
        elseif ~has_reachable_model && isinf(cfg.min_level) && x < 0
            if ~nudged
                fprintf(['  (Heads up: the method suggested a level below 0. If your rig has a\n' ...
                         '   minimum height, set cfg.min_level to it, e.g. 0.)\n']);
                nudged = true;
            end
        end

        requested_x = x;

        % Obtain the binary outcome. A physical operator path may also return
        % 4-5 repeated measurements of the unchanged setup. Their average is
        % the level used by the statistics; the reachable requested setting is
        % retained separately for traceability.
        response = outcome_fn(requested_x,k);
        if isstruct(response)
            if ~isfield(response,'outcome')
                error('run_loop:badPhysicalResponse', ...
                    'Physical response must contain an outcome.');
            end
            if ~isfield(response,'measurements')
                error('run_loop:badPhysicalResponse', ...
                    'Every new spacer build requires measurements.');
            end
            readings=response.measurements(:)';
            if ~(isnumeric(readings) && any(numel(readings)==[4 5]) && ...
                    isreal(readings) && all(isfinite(readings)))
                error('run_loop:badMeasurements', ...
                    'Provide 4 or 5 finite repeated gap measurements.');
            end
            measured_x=mean(readings);
            result=logical(response.outcome);
            measurements{k}=readings;
        else
            result=logical(response);
            measured_x=requested_x;
            measurements{k}=[];
        end

        raw_requested_levels(k)=raw_x;
        requested_levels(k)=requested_x;
        levels(k)    = measured_x;
        successes(k) = result;
        est_mu(k)    = est.mu;
        est_sigma(k) = est.sigma;
        stage(k)     = est.stage;

        boundary_tol = 10 * eps(max([abs(reachable_minimum),abs(reachable_maximum),1]));
        unexpected_at_min = abs(requested_x-reachable_minimum) <= boundary_tol && ...
                            ~result && ~any(successes(1:k));
        unexpected_at_max = abs(requested_x-reachable_maximum) <= boundary_tol && ...
                            result && all(successes(1:k));

        if unexpected_at_min
            if strcmp(boundary_confirmation,'min')
                status = 'paused';
                stop_reason = 'no_interaction_at_min_gap';
                last_k = k;
                fprintf(['  PAUSED - REVIEW REQUIRED: two tests at the minimum gap (%.4g %s)\n' ...
                         '  both gave no interaction. The study data are saved; the test has not failed.\n'], ...
                        reachable_minimum,cfg.unit);
                break;
            end
            boundary_confirmation = 'min';
            fprintf(['  Unexpected no-interaction result at the minimum gap (%.4g %s).\n' ...
                     '  Confirm once at the same gap before deciding whether to pause.\n'], ...
                    reachable_minimum,cfg.unit);
        elseif unexpected_at_max
            if strcmp(boundary_confirmation,'max')
                status = 'paused';
                stop_reason = 'interaction_at_max_gap';
                last_k = k;
                fprintf(['  PAUSED - REVIEW REQUIRED: two tests at the maximum gap (%.4g %s)\n' ...
                         '  both gave interaction. The study data are saved; the test has not failed.\n'], ...
                        reachable_maximum,cfg.unit);
                break;
            end
            boundary_confirmation = 'max';
            fprintf(['  Unexpected interaction result at the maximum gap (%.4g %s).\n' ...
                     '  Confirm once at the same gap before deciding whether to pause.\n'], ...
                    reachable_maximum,cfg.unit);
        else
            boundary_confirmation = '';
        end

        % Neyer Part 2 is a one-way transition: after entry, every specimen
        % is D-optimal until overlap. Reduce its surrogate sigma each time.
        if est.stage == 2
            part2_started = true;
            working_sigma = cfg.stage2_shrink * working_sigma;
            if isfield(cfg,'level_increment') && ...
                    isfield(cfg,'resolution_sigma_floor_factor')
                sigma_floor = cfg.level_increment * ...
                    cfg.resolution_sigma_floor_factor;
                working_sigma = max(working_sigma,sigma_floor);
            end
        end

        % A saved plan declares exactly when the evidence is checked. The
        % remaining articles are reserves, not an automatic continuation.
        if isfield(cfg, 'study_plan') && ~isempty(cfg.study_plan)
            checkpoint_name = checkpoint_at_test(k, cfg.study_plan);
            if ~isempty(checkpoint_name)
                snapshot = make_snapshot(levels, successes, est_mu, est_sigma, ...
                    stage, clamped, raw_requested_levels, requested_levels, ...
                    requested_instructions, measurements, params, k, status, ...
                    stop_reason);
                interim_result = report(snapshot, cfg);
                checkpoint_decision = check_study_checkpoint(interim_result, ...
                    cfg.study_plan, checkpoint_name);
                checkpoint_decisions{end + 1, 1} = checkpoint_decision; %#ok<AGROW>
                if strcmp(checkpoint_decision.status, 'complete')
                    status = 'complete';
                    stop_reason = 'planned_requirements_met';
                    last_k = k;
                    break;
                elseif strcmp(checkpoint_decision.status, 'ask_for_reserve')
                    approved = false;
                    if isfield(cfg, 'reserve_decision_fn') && ...
                            isa(cfg.reserve_decision_fn, 'function_handle')
                        approved = logical(cfg.reserve_decision_fn(checkpoint_decision));
                    end
                    if ~approved
                        status = 'paused';
                        stop_reason = 'reserve_not_authorized';
                        last_k = k;
                        break;
                    end
                else
                    status = 'unsupported';
                    stop_reason = 'planned_evidence_not_supported';
                    last_k = k;
                    break;
                end
            end
        end
    end

    levels    = levels(1:last_k);
    successes = successes(1:last_k);
    est_mu    = est_mu(1:last_k);
    est_sigma = est_sigma(1:last_k);
    stage     = stage(1:last_k);
    clamped   = clamped(1:last_k);
    raw_requested_levels=raw_requested_levels(1:last_k);
    requested_levels=requested_levels(1:last_k);
    requested_instructions=requested_instructions(1:last_k);
    measurements=measurements(1:last_k);

    record = struct('levels', levels, 'successes', successes, ...
                    'est_mu', est_mu, 'est_sigma', est_sigma, ...
                    'stage', stage, 'clamped', clamped, 'params', params, ...
                    'raw_requested_levels',raw_requested_levels, ...
                    'requested_levels',requested_levels, ...
                    'requested_instructions',requested_instructions, ...
                    'measurements',{measurements}, ...
                    'checkpoint_decisions',{checkpoint_decisions}, ...
                    'N', numel(levels), 'requested_N', num_parts, ...
                    'status', status, 'stop_reason', stop_reason);
end

function name = checkpoint_at_test(test_number, plan)
    name = '';
    main_end = plan.main_articles;
    reserve_1_end = main_end + plan.reserve_1_articles;
    reserve_2_end = reserve_1_end + plan.reserve_2_articles;
    if test_number == main_end
        name = 'main';
    elseif plan.reserve_1_articles > 0 && test_number == reserve_1_end
        name = 'reserve_1';
    elseif plan.reserve_2_articles > 0 && test_number == reserve_2_end
        name = 'reserve_2';
    end
end

function snapshot = make_snapshot(levels, successes, est_mu, est_sigma, ...
        stage, clamped, raw_requested_levels, requested_levels, ...
        requested_instructions, measurements, params, count, status, stop_reason)
    snapshot = struct('levels', levels(1:count), ...
        'successes', successes(1:count), ...
        'est_mu', est_mu(1:count), 'est_sigma', est_sigma(1:count), ...
        'stage', stage(1:count), 'clamped', clamped(1:count), ...
        'params', params, ...
        'raw_requested_levels', raw_requested_levels(1:count), ...
        'requested_levels', requested_levels(1:count), ...
        'requested_instructions', requested_instructions(1:count), ...
        'measurements', {measurements(1:count)}, ...
        'N', count, 'requested_N', count, ...
        'status', status, 'stop_reason', stop_reason);
end
