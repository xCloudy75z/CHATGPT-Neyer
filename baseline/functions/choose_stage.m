function [x_next, est] = choose_stage(levels, successes, params, cfg)
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

    levels    = levels(:);
    successes = logical(successes(:));

    sg   = params.sigma_guess;
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

        % Reach further: all-survive -> go up; all-break -> go down.
        if isempty(success_levels)
            dir = +1;     % nothing has broken yet -> mean is higher
        else
            dir = -1;     % everything has broken -> mean is lower
        end

        % Offset doubles: first reach 2*sigma_guess, then x2 each further step.
        offset = cfg.stage1_reach_sigmas * sg * cfg.stage1_growth^(n - 1);
        x_next = base + dir * offset;
        est = make_est(base, sg, 1);
        return;
    end

    % ---------------------------------------------------------------- STAGE 2
    if ~has_overlap(levels, successes)
        hi_survive = max(failure_levels);
        lo_break   = min(success_levels);
        midpoint   = (hi_survive + lo_break) / 2;
        width      = lo_break - hi_survive;

        if width > cfg.stage2_bisect_width_sigmas * sg
            x_next = midpoint;                    % bisect: close the gap
        else
            % Gap is tight: probe D-optimally to overshoot and force overlap.
            x_next = pick_next_level(levels, midpoint, sg, cfg);
        end
        est = make_est(midpoint, sg, 2);
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
