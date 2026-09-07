function record = run_loop(params, num_parts, outcome_fn, cfg)
%RUN_LOOP  Worker #8 — the conductor of the test.
%
%   record = RUN_LOOP(params, num_parts, outcome_fn, cfg) runs the sensitivity
%   test for num_parts items: at each step it asks choose_stage (worker #6) for
%   the next level,
%   obtains the break/survive outcome, records it, and stops when the budget is
%   spent.  [brief sec.4 worker #8]
%
%   Inputs
%     params      starting guess: .mu_min, .mu_max, .sigma_guess.
%     num_parts   item budget (number of destructive tests).
%     outcome_fn  function handle giving the result of testing at a level:
%                     result = outcome_fn(level, k)
%                 where level is the chosen stimulus, k is the 1-based test
%                 index, and result is true for a break (success) / false for a
%                 survive (failure). A real operator ignores k and tests the
%                 item at `level`; the acceptance test uses k to replay Neyer's
%                 fixed Table 1 outcomes (feeding fixed outcomes isolates the
%                 logic from physical chance -- brief sec.7).
%     cfg         settings struct (optional; defaults to settings()).
%
%   Output: record struct with one row per test (column vectors of length num_parts):
%     .levels      level tested at each step.
%     .successes   logical outcome at each step (true = break).
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

    levels    = zeros(num_parts, 1);
    successes = false(num_parts, 1);
    est_mu    = zeros(num_parts, 1);
    est_sigma = zeros(num_parts, 1);
    stage     = zeros(num_parts, 1);
    clamped   = false(num_parts, 1);
    nudged    = false;
    working_sigma = params.sigma_guess;

    for k = 1:num_parts
        % Estimate held going in, and the level it implies.
        step_params = params;
        step_params.working_sigma = working_sigma;
        [x, est] = choose_stage(levels(1:k-1), successes(1:k-1), step_params, cfg);

        % Round to the resolution a physical test can actually be set to, so
        % the recorded history matches what was tested (no full-precision drift).
        x = round(x * 10^cfg.level_decimals) / 10^cfg.level_decimals;

        % Physical floor: keep the tested level runnable on the rig. With the
        % default min_level = -Inf this never triggers (pure Neyer). If the floor
        % is set and the pick falls below it, test AT the floor (boundary test)
        % and say so; if the floor is off but a pick goes negative, nudge once.
        % [addendum MINLEVEL]
        if x < cfg.min_level
            x = cfg.min_level;
            clamped(k) = true;
            fprintf(['  (The method wanted a level below your minimum of %.4g mm; testing at\n' ...
                     '   the floor instead. If this keeps happening, parts may break even at\n' ...
                     '   the lowest height, or the run needs a better guess / more parts.)\n'], cfg.min_level);
        elseif isinf(cfg.min_level) && x < 0
            if ~nudged
                fprintf(['  (Heads up: the method suggested a level below 0. If your rig has a\n' ...
                         '   minimum height, set cfg.min_level to it, e.g. 0.)\n']);
                nudged = true;
            end
        end

        % Obtain the destructive outcome at that level.
        result = logical(outcome_fn(x, k));

        levels(k)    = x;
        successes(k) = result;
        est_mu(k)    = est.mu;
        est_sigma(k) = est.sigma;
        stage(k)     = est.stage;

        % Isolated experiment: activate v1.8's existing 0.8 setting only
        % after a surrogate D-optimal Stage-2 specimen, not after bisection.
        if isfield(est, 'is_stage2_probe') && est.is_stage2_probe
            working_sigma = cfg.stage2_shrink * working_sigma;
        end
    end

    record = struct('levels', levels, 'successes', successes, ...
                    'est_mu', est_mu, 'est_sigma', est_sigma, ...
                    'stage', stage, 'clamped', clamped, 'params', params, 'N', num_parts);
end
