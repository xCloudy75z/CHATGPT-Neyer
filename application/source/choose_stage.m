function [x_next, est] = choose_stage(levels, successes, params, cfg, reachable_levels)
%CHOOSE_STAGE  Worker #6 — the method's brain (the three-stage traffic cop).
%
%   [x_next, est] = CHOOSE_STAGE(levels, successes, params, cfg) decides which
%   stage the test is in and returns the next level to test, plus the estimate
%   the method holds *going in* to that test.  This is the second extension
%   point: a future design swaps its rule here without touching the rest.
%   [brief sec.3; sec.4 worker #6; Figure 2 flowchart]
%
%   Stages (find the zone -> close the gap -> refine):
%     STAGE 1  no break-and-survive pair yet. Test the centre of the bounds,
%              then reach out with an offset that doubles each step (up if
%              everything has survived, down if everything has broken) until
%              both a break and a survive have appeared. [brief Stage 1]
%     STAGE 2  both seen, but results have not interleaved (no overlap, so no
%              real best-fit). Close the gap between the highest survive and
%              the lowest break by bisection while the bracket is wide; once it
%              narrows to ~sigma_guess, probe D-optimally to overshoot and
%              force the first overlap. The estimate is a surrogate
%              (bracket midpoint, sigma_guess). [brief Stage 2; sec.8 #2]
%     STAGE 3  results overlap -> the MLE exists. Fit (worker #2), clamp
%              (worker #5), then test at the D-optimal level (worker #3).
%              [brief Stage 3]
%
%   Inputs
%     levels     levels tested so far (may be empty).
%     successes  logical results so far (true = break, false = survive).
%     params     struct with the starting guess:
%                  params.mu_min, params.mu_max  bounds on the average
%                  params.sigma_guess            guessed spread
%     cfg        settings struct (optional; defaults to settings()).
%
%   Outputs
%     x_next   next level to test.
%     est      struct: est.mu, est.sigma (estimate going in) and est.stage
%              (1, 2 or 3) for diagnostics / the acceptance test.

    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if nargin < 5 || isempty(reachable_levels), reachable_levels = levels; end

    levels    = levels(:);
    successes = logical(successes(:));
    reachable_levels = reachable_levels(:);
    if numel(reachable_levels) ~= numel(levels)
        error('choose_stage:reachableSizeMismatch', ...
            'Reachable-setting history must match measured-level history.');
    end

    sg   = params.sigma_guess;
    if isfield(params, 'working_sigma')
        working_sg = params.working_sigma;
    else
        working_sg = sg;
    end
    part2_started = isfield(params, 'part2_started') && params.part2_started;
    base = (params.mu_min + params.mu_max) / 2;

    success_levels = levels(successes);
    failure_levels = levels(~successes);
    have_both = ~isempty(success_levels) && ~isempty(failure_levels);

    % ---------------------------------------------------------------- STAGE 1
    if ~have_both
        n = numel(levels);
        if n == 0
            x_next = base;                        % start at the centre
            est = make_est(base, sg, 1);
            return;
        end

        % Gap response decreases: all interactions -> increase the gap;
        % all non-interactions -> decrease the gap.
        if isempty(success_levels)
            dir = -1;
        else
            dir = +1;
        end

        % Neyer Figure 2 uses the most aggressive of the prior-mean bound,
        % two guessed sigmas, and doubling the range already explored.
        hi = max(levels);
        lo = min(levels);
        if dir > 0
            x_next = max([(params.mu_max + hi) / 2, ...
                          hi + cfg.stage1_reach_sigmas * sg, ...
                          2 * hi - lo]);
        else
            x_next = min([(params.mu_min + lo) / 2, ...
                          lo - cfg.stage1_reach_sigmas * sg, ...
                          2 * lo - hi]);
        end
        est = make_est(base, sg, 1);
        return;
    end

    % ---------------------------------------------------------------- STAGE 2
    if ~has_overlap(levels, successes)
        hi_interaction = max(success_levels);
        lo_no          = min(failure_levels);
        midpoint       = (hi_interaction + lo_no) / 2;
        width          = lo_no - hi_interaction;

        transition_width = cfg.stage2_bisect_width_sigmas * sg;
        comparison_tol = 10 * eps(max([abs(width), abs(transition_width), 1]));
        if ~part2_started && width > transition_width + comparison_tol
            x_next = midpoint;                    % bisect: close the gap
            est = make_est(midpoint, sg, 1);
        else
            % Part 2 is one-way until overlap; do not return to bisection as
            % working_sg shrinks after successive D-optimal specimens.
            x_next = pick_next_level(levels, midpoint, working_sg, cfg);
            if isfield(cfg,'level_increment') && ~isempty(cfg.level_increment)
                physical_hi_interaction=max(reachable_levels(successes));
                physical_lo_no=min(reachable_levels(~successes));
                x_next = nearest_useful_reachable(x_next,physical_hi_interaction, ...
                    physical_lo_no,cfg.level_increment,cfg.min_level);
            end
            est = make_est(midpoint, working_sg, 2);
        end
        return;
    end

    % ---------------------------------------------------------------- STAGE 3
    % Overlap exists -> the MLE is well defined.
    [mu0, sigma0] = start_guess(levels, success_levels, failure_levels, sg);
    [mu, sigma]   = best_fit(levels, successes, mu0, sigma0);
    [mu, sigma]   = sanity_clamp(mu, sigma, levels, cfg);

    x_next = pick_next_level(levels, mu, sigma, cfg);
    est = make_est(mu, sigma, 3);
end

function x = nearest_useful_reachable(raw,hi_yes,lo_no,increment,min_level)
% A No below hi_yes or an interaction above lo_no creates strict overlap.
lower = (ceil(hi_yes/increment)-1)*increment;
upper = (floor(lo_no/increment)+1)*increment;
if lower < min_level
    x = upper;
elseif abs(raw-lower) <= abs(raw-upper)
    x = lower;
else
    x = upper;
end
end

% -------------------------------------------------------------------------
function est = make_est(mu, sigma, stage)
    est = struct('mu', mu, 'sigma', sigma, 'stage', stage);
end

% -------------------------------------------------------------------------
function [mu0, sigma0] = start_guess(levels, sl, fl, sg)
%START_GUESS  A robust starting point for the MLE optimiser.
    mu0    = (max(fl) + min(sl)) / 2;          % centre of the overlap region
    sigma0 = max(sg, (max(levels) - min(levels)) / 4);
end
