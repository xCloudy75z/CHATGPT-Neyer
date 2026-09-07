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
    measurements = cell(num_parts,1);
    nudged    = false;
    working_sigma = params.sigma_guess;
    part2_started = false;
    boundary_confirmation = '';
    status = 'complete';
    stop_reason = '';
    last_k = num_parts;

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
            x = cfg.min_level;
            clamped(k) = true;
        elseif strcmp(boundary_confirmation,'max')
            x = cfg.max_level;
            clamped(k) = true;
        end

        % Round to the resolution a physical test can actually be set to, so
        % the recorded history matches what was tested (no full-precision drift).
        if isfield(cfg,'level_increment') && ~isempty(cfg.level_increment)
            x = round(x / cfg.level_increment) * cfg.level_increment;
        else
            x = round(x * 10^cfg.level_decimals) / 10^cfg.level_decimals;
        end

        % Physical floor: keep the tested level runnable on the rig. With the
        % default min_level = -Inf this never triggers (pure Neyer). If the floor
        % is set and the pick falls below it, test AT the floor (boundary test)
        % and say so; if the floor is off but a pick goes negative, nudge once.
        % [addendum MINLEVEL]
        if x < cfg.min_level
            x = cfg.min_level;
            clamped(k) = true;
            fprintf(['  (The method requested a gap below the permitted minimum of %.4g %s;\n' ...
                     '   this test will use the minimum gap instead.)\n'], ...
                    cfg.min_level,cfg.unit);
        elseif x > cfg.max_level
            x = cfg.max_level;
            clamped(k) = true;
        elseif isinf(cfg.min_level) && x < 0
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

        boundary_tol = 10 * eps(max([abs(cfg.min_level),abs(cfg.max_level),1]));
        unexpected_at_min = abs(requested_x-cfg.min_level) <= boundary_tol && ...
                            ~result && ~any(successes(1:k));
        unexpected_at_max = abs(requested_x-cfg.max_level) <= boundary_tol && ...
                            result && all(successes(1:k));

        if unexpected_at_min
            if strcmp(boundary_confirmation,'min')
                status = 'paused';
                stop_reason = 'no_interaction_at_min_gap';
                last_k = k;
                fprintf(['  PAUSED - REVIEW REQUIRED: two tests at the minimum gap (%.4g %s)\n' ...
                         '  both gave no interaction. The study data are saved; the test has not failed.\n'], ...
                        cfg.min_level,cfg.unit);
                break;
            end
            boundary_confirmation = 'min';
            fprintf(['  Unexpected no-interaction result at the minimum gap (%.4g %s).\n' ...
                     '  Confirm once at the same gap before deciding whether to pause.\n'], ...
                    cfg.min_level,cfg.unit);
        elseif unexpected_at_max
            if strcmp(boundary_confirmation,'max')
                status = 'paused';
                stop_reason = 'interaction_at_max_gap';
                last_k = k;
                fprintf(['  PAUSED - REVIEW REQUIRED: two tests at the maximum gap (%.4g %s)\n' ...
                         '  both gave interaction. The study data are saved; the test has not failed.\n'], ...
                        cfg.max_level,cfg.unit);
                break;
            end
            boundary_confirmation = 'max';
            fprintf(['  Unexpected interaction result at the maximum gap (%.4g %s).\n' ...
                     '  Confirm once at the same gap before deciding whether to pause.\n'], ...
                    cfg.max_level,cfg.unit);
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
    end

    levels    = levels(1:last_k);
    successes = successes(1:last_k);
    est_mu    = est_mu(1:last_k);
    est_sigma = est_sigma(1:last_k);
    stage     = stage(1:last_k);
    clamped   = clamped(1:last_k);
    raw_requested_levels=raw_requested_levels(1:last_k);
    requested_levels=requested_levels(1:last_k);
    measurements=measurements(1:last_k);

    record = struct('levels', levels, 'successes', successes, ...
                    'est_mu', est_mu, 'est_sigma', est_sigma, ...
                    'stage', stage, 'clamped', clamped, 'params', params, ...
                    'raw_requested_levels',raw_requested_levels, ...
                    'requested_levels',requested_levels, ...
                    'measurements',{measurements}, ...
                    'N', numel(levels), 'requested_N', num_parts, ...
                    'status', status, 'stop_reason', stop_reason);
end
