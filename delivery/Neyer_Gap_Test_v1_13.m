%% Neyer Gap Test v1.13
% Supported version: MATLAB R2022b.
%
% This one Live Script contains the complete application. Open it and press
% Run once. The Neyer Gap Test menu then appears. No helper-code folder,
% internet connection, or add-on package is needed.

%% What this tool answers
% The tool studies destructive tests in which a smaller physical gap makes
% Interaction more likely and a larger gap makes No interaction more likely.
% It estimates:
%
% * the middle gap, where similar articles are expected to interact about
%   half the time;
% * the overall variation, which says how gradual or sudden the change is;
% * a cautious operating gap for the chosen reliability and confidence.
%
% Reliability is the predicted chance at a gap. Confidence describes how
% much support the completed data give that prediction. They are different.

%% Start a direct test without the planner
% Press Run, choose Run a Test, and enter the direct-test settings. This route
% does not read or require a Pre-Test Planner result. The number of articles
% is the maximum number of destructive tests you allow. It is not a promise
% that a particular confidence target will be reached.
%
% The Pre-Test Planner remains available as a separate optional tool. It is
% not needed for the direct Run a Test workflow and can be reviewed later.

%% Physical gap settings
% Define settings from measured physical capability, not from the foil label.
% The current aluminium foil value of about 0.015 mm is unconfirmed starting
% information. Ten spacers from each printed size were sampled with three
% readings per spacer. Their batch-average thicknesses were 0.486, 1.1183,
% and 2.0703 mm for the 0.5, 1, and 2 mm labels. These sample averages describe
% the batches; the application does not require individual spacer IDs.
% Foil recipes are unavailable until measured foil stacks and a practical
% maximum layer count are confirmed. Do not use 0.015 mm as a recipe step.
% The planner can use a
% regular step such as 0.05, 0.10, 0.15, or 0.50 mm, a list of measured gaps,
% or combinations of measured spacer components and maximum counts.
%
% A requested build gap is shown with two decimal places. The exact reachable
% value remains stored. A setting is never chosen just because it is nearest:
% it must also be inside the permitted range and safe for the requested result.
% A final operating instruction moves one additional reachable setting in the
% safe direction to protect against differences in a newly built spacer setup.

%% Procedure for every destructive article
% 1. Use a new spacer setup at the reachable gap shown by the app.
% 2. Measure the completed setup once before the test.
% 3. Enter that measurement. It is the actual gap used in the calculation;
%    the ideal requested gap is not substituted for it.
% 4. Perform one test and record Interaction or No interaction.
% 5. Do not reuse the setup after the destructive test.
%
% Differences between separately built articles remain part of the overall
% tested process.

%% How the next gap is chosen
% The early tests establish both outcomes. The narrowing stage multiplies its
% working overall-variation value by 0.8 after each result and cannot shrink
% below two usable physical setting steps. Once the outcomes overlap, the
% fitted model chooses later gaps expected to add the most useful information.
% The two-step limit affects planning only; it is not a lower limit imposed on
% the final fitted overall variation.

%% Saving and reopening
% A study plan is saved as JSON in a folder and filename chosen by the user.
% Results are saved as a CSV data file and a self-contained HTML result page.
% The complete intended paths are shown before saving. The application never replaces an existing
% plan or result file silently; choose another name.

%% Important limits
% Confirm the real reachable gap list with repeated physical builds before a
% formal study. A model result does not replace a separate fixed-gap,
% zero-failure qualification demonstration when a standard requires one.
% Confidence of 50% or less is exploratory, so it does not produce a
% safety-supported operating instruction. Confidence above 95% can be
% calculated but is also kept outside the recorded validation envelope.
% Results outside the permitted gap range are never shown as usable build
% instructions.

%% Start the application
neyer_app;

function updated = apply_run_configuration_overrides(current, overrides)
%APPLY_RUN_CONFIGURATION_OVERRIDES Apply advanced settings without a stale gap list.
% Direct UI callers normally pass no overrides. Programmatic callers may do
% so; if they change the permitted range or usable step, the reachable gaps
% are rebuilt after all changes have been applied.
    updated = current;
    if nargin < 2 || isempty(overrides), return; end
    if ~isstruct(current) || ~isstruct(overrides)
        error('apply_run_configuration_overrides:badInput', ...
            'Advanced settings must be supplied as a settings structure.');
    end
    names = fieldnames(overrides);
    for field_number = 1:numel(names)
        updated.(names{field_number}) = overrides.(names{field_number});
    end

    step_changed = isfield(overrides, 'usable_resolution') || ...
        isfield(overrides, 'level_increment');
    if isfield(overrides, 'usable_resolution')
        updated.level_increment = overrides.usable_resolution;
    elseif isfield(overrides, 'level_increment')
        updated.usable_resolution = overrides.level_increment;
    end
    bounds_changed = isfield(overrides, 'min_level') || ...
        isfield(overrides, 'max_level');
    model_was_supplied = isfield(overrides, 'reachable_model');
    if (step_changed || bounds_changed) && ~model_was_supplied
        required = {'min_level', 'max_level', 'usable_resolution'};
        if ~all(isfield(updated, required))
            error('apply_run_configuration_overrides:incompletePhysicalSettings', ...
                ['Advanced settings that change the physical range or step ' ...
                 'must include a complete minimum, maximum, and usable step.']);
        end
        regular_setup = struct('mode', 'regular', ...
            'increment_mm', updated.usable_resolution);
        updated.reachable_model = reachable_gap_model(regular_setup, ...
            updated.min_level, updated.max_level);
    end
end

function [mu, sigma, ll] = best_fit(levels, successes, mu0, sigma0)
%BEST_FIT  Worker #2 â€” maximum-likelihood fit of the bell-curve (mu, sigma).
%
%   [mu, sigma] = BEST_FIT(levels, successes, mu0, sigma0) returns the average
%   and spread that best explain the results so far, by maximising the
%   log-likelihood of the normal sensitivity model.  [brief sec.4, worker #2;
%   App.A Eq.1]
%
%       l(mu, sigma) = sum_{interactions} ln Phi(z)
%                    + sum_{no interactions} ln Q(z),
%       with z = (mu - gap) / sigma.
%
%   Inputs
%     levels     vector of test levels x already run.
%     successes  logical vector, same length as levels:
%                  true  = interaction, uses Phi(z)
%                  false = no interaction, uses Q(z)
%     mu0, sigma0  starting guess for the optimiser (e.g. the current
%                  estimate). sigma0 must be > 0.
%
%   Outputs
%     mu, sigma  the maximum-likelihood estimate.
%     ll         the maximised log-likelihood (handy for diagnostics).
%
%   Notes tied to the brief:
%     * The bell curve is NOT recomputed here â€” every probability comes from
%       worker #1 (shape_model), so the shape stays in one file. [sec.4]
%     * The optimiser searches over (mu, log sigma) so the spread can never go
%       to zero or negative â€” sigma = exp(theta) is positive by construction.
%       This is the "keep spread positive / reparameterise" guard. [sec.8 #4]
%     * A finite, meaningful optimum exists only once successes and failures
%       overlap (the Silvapulle condition). Detecting that and deciding when
%       to call best_fit is worker #4 / worker #6; clipping wild early fits is
%       worker #5. best_fit itself just maximises the likelihood it is given.
%       [sec.8 #2, #3]
%     * Uses base fminsearch (Nelder-Mead) â€” no toolbox dependency.

    levels    = levels(:);
    successes = logical(successes(:));

    if numel(levels) ~= numel(successes)
        error('best_fit:sizeMismatch', ...
              'levels and successes must have the same length.');
    end
    if ~(isscalar(mu0) && isscalar(sigma0)) || ~(sigma0 > 0) || ~isfinite(sigma0)
        error('best_fit:badStart', ...
              'mu0 must be scalar and sigma0 a finite positive scalar.');
    end

    % Optimise over theta = [mu, log(sigma)] so sigma stays strictly positive.
    negloglik = @(theta) neg_loglik(theta, levels, successes);

    opts = optimset('TolX', 1e-10, 'TolFun', 1e-12, ...
                    'MaxFunEvals', 1e5, 'MaxIter', 1e5);
    theta0  = [mu0, log(sigma0)];
    thetahat = fminsearch(negloglik, theta0, opts);

    mu    = thetahat(1);
    sigma = exp(thetahat(2));
    ll    = -negloglik(thetahat);
end

function nll = neg_loglik(theta, levels, successes)
    mu    = theta(1);
    sigma = exp(theta(2));           % positive by construction
    nll   = -loglik(levels, successes, mu, sigma);
end

function check_inputs(params, num_parts)
%CHECK_INPUTS  Worker #7 â€” refuse bad starting guesses up front.
%
%   CHECK_INPUTS(params, num_parts) validates the run configuration and throws a
%   clear error if anything is wrong, so the method never starts from a
%   nonsensical state. It is the first thing run_test does.  [brief sec.4 worker #7]
%
%   Requirements:
%     * params.avg_low < params.avg_high       (a real bracket on the average)
%     * params.spread_guess > 0  and finite    (a positive guessed spread)
%     * num_parts a positive integer >= 3       (a sensible item budget; two
%                                              parameters cannot be pinned from
%                                              fewer than a few destructive tests)
%
%   All three bounds are finite real scalars. On success the function returns
%   quietly; on failure it errors with an identifier under "check_inputs:".

    % --- params must carry the three fields -------------------------------
    needed = {'avg_low', 'avg_high', 'spread_guess'};
    for i = 1:numel(needed)
        if ~isfield(params, needed{i})
            error('check_inputs:missingField', ...
                  'params is missing required field "%s".', needed{i});
        end
    end

    avg_low  = params.avg_low;
    avg_high = params.avg_high;
    sg       = params.spread_guess;

    % --- each bound a finite real scalar ----------------------------------
    check_scalar(avg_low,  'avg_low');
    check_scalar(avg_high, 'avg_high');
    check_scalar(sg,       'spread_guess');

    % --- the actual sanity rules ------------------------------------------
    if ~(avg_low < avg_high)
        error('check_inputs:badBounds', ...
              'avg_low (%.4g) must be strictly less than avg_high (%.4g).', avg_low, avg_high);
    end
    if ~(sg > 0)
        error('check_inputs:badSigma', ...
              'spread_guess (%.4g) must be strictly positive.', sg);
    end

    if ~isscalar(num_parts) || ~isreal(num_parts) || ~isfinite(num_parts) || num_parts ~= floor(num_parts)
        error('check_inputs:badBudget', ...
              'num_parts must be a finite integer.');
    end
    if num_parts < 3
        error('check_inputs:budgetTooSmall', ...
              'num_parts (%d) is too small; need at least 3 tests to estimate two parameters.', num_parts);
    end
end

% -------------------------------------------------------------------------
function check_scalar(v, name)
    if ~isscalar(v) || ~isreal(v) || ~isfinite(v)
        error('check_inputs:notFiniteScalar', ...
              '%s must be a finite real scalar.', name);
    end
end

function decision = check_study_checkpoint(result, plan, checkpoint_name)
%CHECK_STUDY_CHECKPOINT Decide whether the declared study checkpoint is enough.
% An incomplete statistical study is not called a failed physical test.
% Reserve groups are offered only at their declared checkpoints.

    required_plan_fields = {'outcome', 'reliability', 'confidence', ...
        'accuracy_mm', 'minimum_gap_mm', 'maximum_gap_mm', ...
        'main_articles', 'reserve_1_articles', 'reserve_2_articles', ...
        'reachable_model', 'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~isstruct(plan) || ~all(isfield(plan, required_plan_fields))
        error('check_study_checkpoint:badPlan', ...
            'A complete saved study plan is required for the checkpoint.');
    end
    [safe_plan, safety_message] = validate_study_plan_safety(plan);
    if ~safe_plan
        error('check_study_checkpoint:badPlan', '%s', safety_message);
    end
    checkpoint_name = lower(strtrim(char(string(checkpoint_name))));
    if ~any(strcmp(checkpoint_name, {'main', 'reserve_1', 'reserve_2'}))
        error('check_study_checkpoint:badCheckpoint', ...
            'Checkpoint must be main, reserve 1, or reserve 2.');
    end

    missing = strings(0, 1);
    has_successes = isstruct(result) && isfield(result, 'successes') && ...
        ~isempty(result.successes);
    if ~has_successes || ~any(logical(result.successes)) || ...
            ~any(~logical(result.successes))
        missing(end + 1, 1) = [ ...
            "Both outcomes have not been observed in the tested region."];
    end

    if ~isstruct(result) || ~isfield(result, 'has_overlap') || ...
            ~result.has_overlap
        missing(end + 1, 1) = [ ...
            "The Interaction and No-interaction results do not yet overlap enough for a valid fit."];
    end

    finite_fit = isstruct(result) && all(isfield(result, {'mu', 'sigma'})) && ...
        isfinite(result.mu) && isfinite(result.sigma) && result.sigma > 0;
    if ~finite_fit
        missing(end + 1, 1) = [ ...
            "A finite middle gap and positive overall variation have not been obtained."];
    end

    finite_middle_range = isstruct(result) && ...
        all(isfield(result, {'mu_lo', 'mu_hi'})) && ...
        isfinite(result.mu_lo) && isfinite(result.mu_hi) && ...
        result.mu_hi >= result.mu_lo;
    if ~finite_middle_range
        missing(end + 1, 1) = [ ...
            "A finite confidence range for the middle gap has not been obtained."];
    elseif 0.5 * (result.mu_hi - result.mu_lo) > plan.accuracy_mm
        missing(end + 1, 1) = sprintf([ ...
            'The requested middle-gap accuracy of +/-%.4g mm has not been reached.'], ...
            plan.accuracy_mm);
    end

    planned_count = checkpoint_count(plan, checkpoint_name);
    if ~isfield(result, 'n') || result.n < planned_count
        missing(end + 1, 1) = sprintf([ ...
            'The declared %s checkpoint requires %d completed articles.'], ...
            strrep(checkpoint_name, '_', ' '), planned_count);
    end

    if ~isfield(result, 'n') || ...
            result.n < plan.reliability_validation_floor_articles
        missing(end + 1, 1) = sprintf([ ...
            'A supported reliability result requires %d independent articles ' ...
            'under the recorded virtual-study safety rule.'], ...
            plan.reliability_validation_floor_articles);
    end

    if ~plan.reliability_instruction_supported
        if isfield(plan, 'reliability_instruction_status') && ...
                strcmp(plan.reliability_instruction_status, ...
                'exploratory_confidence')
            missing(end + 1, 1) = [ ...
                "This confidence is exploratory, so no safety-supported " + ...
                "reliability operating instruction can be issued."];
        else
            missing(end + 1, 1) = [ ...
                "Confidence above 95% is outside the recorded validation; " + ...
                "no safety-supported reliability operating instruction can be issued."];
        end
    end

    boundary_established = false;
    safe_gap_mm = NaN;
    safe_gap_status = struct('code', 'not_checked', ...
        'message', 'The reliability boundary could not yet be checked.', ...
        'display_gap', "Not established", 'instruction', "", ...
        'raw_gap_mm', NaN);
    if has_successes && isfield(result, 'has_overlap') && result.has_overlap && ...
            finite_fit
        boundary = reliability_query(result, plan.outcome, 'gap_for', ...
            plan.reliability, plan.confidence);
        raw_boundary = boundary.raw_bound;
        boundary_established = isfinite(raw_boundary) && ...
            raw_boundary >= plan.minimum_gap_mm && ...
            raw_boundary <= plan.maximum_gap_mm;
        if boundary_established
            [safe_gap_mm, safe_gap_status] = select_operating_gap( ...
                raw_boundary, plan.outcome, plan.reachable_model);
        end
    end
    if ~boundary_established
        missing(end + 1, 1) = [ ...
            "The requested reliability boundary is not established inside the permitted range."];
    elseif ~strcmp(safe_gap_status.code, 'ok')
        missing(end + 1, 1) = [ ...
            "No reachable gap with the extra safe-direction build step is available for the requested result."];
    end

    if isempty(missing)
        status = 'complete';
        next_checkpoint = '';
        explanation = [ ...
            'The declared checkpoint supports the requested result. ' ...
            'Do not use reserve articles.'];
    else
        [next_checkpoint, reserve_available] = following_checkpoint(plan, checkpoint_name);
        if reserve_available
            status = 'ask_for_reserve';
            explanation = sprintf([ ...
                'The statistical study is incomplete; this is not a failed physical test. ' ...
                'Review what is missing, then choose whether to use %s.'], ...
                strrep(next_checkpoint, '_', ' '));
        else
            status = 'unsupported';
            next_checkpoint = '';
            explanation = [ ...
                'The requested statement is not supported after the declared reserve checkpoints. ' ...
                'Do not present this as a failed physical test or a reliability claim.'];
        end
    end

    decision = struct('status', status, 'checkpoint', checkpoint_name, ...
        'next_checkpoint', next_checkpoint, ...
        'missing_conditions', missing, ...
        'plain_explanation', explanation, ...
        'boundary_established', boundary_established, ...
        'safe_gap_mm', safe_gap_mm, 'safe_gap_status', safe_gap_status);
end

function count = checkpoint_count(plan, checkpoint_name)
    switch checkpoint_name
        case 'main'
            count = plan.main_articles;
        case 'reserve_1'
            count = plan.main_articles + plan.reserve_1_articles;
        otherwise
            count = plan.main_articles + plan.reserve_1_articles + ...
                plan.reserve_2_articles;
    end
end

function [name, available] = following_checkpoint(plan, checkpoint_name)
    if strcmp(checkpoint_name, 'main') && plan.reserve_1_articles > 0
        name = 'reserve_1';
        available = true;
    elseif strcmp(checkpoint_name, 'main') && plan.reserve_2_articles > 0
        name = 'reserve_2';
        available = true;
    elseif strcmp(checkpoint_name, 'reserve_1') && plan.reserve_2_articles > 0
        name = 'reserve_2';
        available = true;
    else
        name = '';
        available = false;
    end
end

function [x_next, est] = choose_stage(levels, successes, params, cfg, reachable_levels)
%CHOOSE_STAGE  Worker #6 â€” the method's brain (the three-stage traffic cop).
%
%   [x_next, est] = CHOOSE_STAGE(levels, successes, params, cfg) decides which
%   stage the test is in and returns the next level to test, plus the estimate
%   the method holds *going in* to that test.  This is the second extension
%   point: a future design swaps its rule here without touching the rest.
%   [brief sec.3; sec.4 worker #6; Figure 2 flowchart]
%
%   Stages (find the zone -> close the gap -> refine):
%     STAGE 1  both outcomes have not yet appeared. Test the centre of the bounds,
%              then reach out with an offset that doubles each step (up if
%              every result is no interaction, down if every result is
%              interaction) until both outcomes have appeared. [brief Stage 1]
%     STAGE 2  both seen, but results have not interleaved (no overlap, so no
%              real best-fit). Close the gap between the highest interaction
%              and lowest no-interaction result by bisection while the bracket
%              is wide; once it
%              narrows to ~sigma_guess, probe D-optimally to overshoot and
%              force the first overlap. The estimate is a surrogate
%              (bracket midpoint, sigma_guess). [brief Stage 2; sec.8 #2]
%     STAGE 3  results overlap -> the MLE exists. Fit (worker #2), clamp
%              (worker #5), then test at the D-optimal level (worker #3).
%              [brief Stage 3]
%
%   Inputs
%     levels     levels tested so far (may be empty).
%     successes  logical results (true = interaction, false = no interaction).
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
            has_reachable_model=isfield(cfg,'reachable_model') && ...
                ~isempty(cfg.reachable_model);
            if isfield(cfg,'level_increment') && ~isempty(cfg.level_increment) && ...
                    ~has_reachable_model
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
nearest = round(raw/increment)*increment;
tolerance = 10 * eps(max([abs(raw),abs(hi_yes),abs(lo_no),increment,1]));
if nearest < hi_yes-tolerance || nearest > lo_no+tolerance
    x = nearest;
    return;
end
lower = (ceil((hi_yes-tolerance)/increment)-1)*increment;
upper = (floor((lo_no+tolerance)/increment)+1)*increment;
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

function draw_distribution(ax, result, cfg)
%DRAW_DISTRIBUTION  Draw the fitted distribution of critical interaction gaps.
%   markers into a given axes handle `ax`. Base plotting only (works for a normal
%   figure axes and a uiaxes). Shared by plot_result and show_result. [addendum POPUP]
    if nargin<3 || isempty(cfg), cfg=neyer_settings(); end
    u = 'mm'; if isfield(result,'unit') && ~isempty(result.unit), u = result.unit; end
    mu = result.mu; sigma = result.sigma;
    confidencePercent = 95;
    if isfield(result, 'confidence_level') && ...
            ~isempty(result.confidence_level) && isfinite(result.confidence_level)
        confidencePercent = 100 * result.confidence_level;
    end
    % percentage attached to the high/negligible interaction edge gaps
    if isfield(result,'tail_fraction') && ~isempty(result.tail_fraction) && isfinite(result.tail_fraction)
        pc = 100 * result.tail_fraction;
    else
        pc = 99.9;
    end
    compact = isfield(cfg, 'compact') && logical(cfg.compact);
    if compact
        draw_compact_distribution(ax, result, cfg, u, mu, sigma, ...
            confidencePercent);
        return;
    end
    x   = linspace(mu - 4.5*sigma, mu + 4.5*sigma, 400);
    pdf = shape_model(x, mu, sigma).phi ./ sigma;
    plot(ax, x, pdf, '-', 'Color', [0.10 0.16 0.19], 'LineWidth', 2); hold(ax, 'on');
    % shade +/- 1 spread, then redraw the curve on top of the shade
    xin = x(x >= mu-sigma & x <= mu+sigma);
    pin = shape_model(xin, mu, sigma).phi ./ sigma;
    hBand = area(ax, xin, pin, 'FaceColor', [0.945 0.914 0.847], 'EdgeColor', 'none');
    hCurve = plot(ax, x, pdf, '-', 'Color', [0.10 0.16 0.19], 'LineWidth', 2);
    ymax = max(pdf);
    hMean = line(ax, [mu mu], [0 ymax], 'Color', [0.66 0.51 0.23], 'LineWidth', 1.5);

    % colours reused below
    teal = [0.18 0.44 0.42];
    clay = [0.74 0.37 0.20];
    gold = [0.66 0.51 0.23];

    % --- (1) label the mean line, clearly ABOVE the apex, in the gold colour
    text(ax, mu, 1.04*ymax, sprintf('middle gap %.2f %s', mu, u), ...
        'Color', gold, 'FontWeight', 'bold', 'FontSize', 14, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % --- (2) label the +/-1 spread band, lifted clearly above the relocated CI bracket
    text(ax, mu, 0.46*ymax, ...
        'middle ~68% of transition gaps (\pm1 overall variation)', ...
        'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.45 0.42 0.36]);

    highGap = result.high_interaction_gap;
    negligibleGap = result.negligible_interaction_gap;
    plot(ax, highGap, 0, 'v', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
    plot(ax, negligibleGap, 0, 'v', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);

    % --- (4) threshold dashed lines (make the triangle markers into clear lines)
    if isfinite(highGap)
        line(ax, [highGap highGap], [0 0.15*ymax], ...
            'Color', clay, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    if isfinite(negligibleGap)
        line(ax, [negligibleGap negligibleGap], [0 0.15*ymax], ...
            'Color', teal, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    % --- (4) clear filled baseline dots + readable multi-line callouts with leaders
    if isfinite(highGap)
        yCall = 0.30*ymax;
        plot(ax, highGap, 0, 'o', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [highGap highGap], [0 yCall], 'Color', clay, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, highGap, yCall, ...
            sprintf('%.4g%% interaction\n%.2f %s', pc, highGap, u), ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', clay);
    end
    if isfinite(negligibleGap)
        yCall = 0.30*ymax;
        plot(ax, negligibleGap, 0, 'o', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [negligibleGap negligibleGap], [0 yCall], 'Color', teal, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, negligibleGap, yCall, ...
            sprintf('negligible interaction\n%.2f %s', negligibleGap, u), ...
            'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', teal);
    end

    % --- (3) 95% CI bracket for the average (SEPARATE from the beige spread band)
    hCI = [];
    mu_lo = NaN; mu_hi = NaN;
    if isfield(result, 'mu_lo'), mu_lo = result.mu_lo; end
    if isfield(result, 'mu_hi'), mu_hi = result.mu_hi; end
    if isfinite(mu_lo) && isfinite(mu_hi)
        yCI = 0.12*ymax;    % low, just above the x-axis (vacates the crowded apex)
        cap = 0.03*ymax;    % end-cap half-height
        hCI = line(ax, [mu_lo mu_hi], [yCI yCI], 'Color', teal, 'LineWidth', 1.5);
        line(ax, [mu_lo mu_lo], [yCI-cap yCI+cap], 'Color', teal, 'LineWidth', 1.5);
        line(ax, [mu_hi mu_hi], [yCI-cap yCI+cap], 'Color', teal, 'LineWidth', 1.5);
        text(ax, mu, 0.18*ymax, sprintf( ...
            '%.4g%% range for middle gap: %.2f-%.2f %s', ...
            confidencePercent, mu_lo, mu_hi, u), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 13, 'Color', teal);
    end

    % --- (5) SAFE / Expected / FAIL colour strip just below the baseline
    xl = get(ax, 'XLim');
    if xl(1) >= min(x), xl(1) = min(x); end
    if xl(2) <= max(x), xl(2) = max(x); end
    xlo = xl(1); xhi = xl(2);
    y0 = 0; ys = -0.03*ymax;                % small negative-y sliver
    green = [0.86 0.92 0.86];
    amber = [0.97 0.93 0.80];
    reddy = [0.96 0.86 0.83];
    if isfinite(highGap) && isfinite(negligibleGap)
        strip_patch(ax, xlo, highGap, ys, y0, reddy);
        strip_patch(ax, highGap, negligibleGap, ys, y0, amber);
        strip_patch(ax, negligibleGap, xhi, ys, y0, green);
        text(ax, (xlo+highGap)/2, ys/2, 'high interaction', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',9,'Color',[0.60 0.25 0.20]);
        text(ax, (highGap+negligibleGap)/2, ys/2, 'transition', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',11,'Color',[0.55 0.45 0.15]);
    end

    % --- (7) axis labels + title (enlarged text)
    xlabel(ax, sprintf('gap (%s)', u), 'FontSize', 14);
    ylabel(ax, {'relative distribution', 'of transition gaps'}, 'FontSize', 14);
    title(ax, sprintf( ...
        'Fitted gap transition: middle %.2f, overall variation %.2f', mu, sigma), ...
        'FontSize', 15, 'FontWeight', 'bold');

    % ensure the y-lower-limit includes the strip and headroom for the raised average label
    set(ax, 'YLim', [ys*1.2 1.30*ymax]);
    set(ax, 'XLim', [cfg.min_level cfg.max_level]);

    % --- (6) legend naming the four key elements (unobtrusive)
    try
        if isempty(hCI)
            legend(ax, [hCurve hMean hBand], ...
                {'fitted transition distribution', 'middle gap', ...
                 'middle ~68% (\pm1 overall variation)'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        else
            legend(ax, [hCurve hMean hBand hCI], ...
                {'fitted transition distribution', 'middle gap', ...
                 'middle ~68% (\pm1 overall variation)', ...
                 sprintf('%.4g%% range for middle gap', confidencePercent)}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        end
    catch
        % legend can be problematic on some uiaxes configs; the labels/text
        % above already name each element, so failing here is non-fatal.
    end

    hold(ax, 'off');
end

function draw_compact_distribution(ax, result, cfg, u, mu, sigma, confidencePercent)
% One clear purpose in the combined result screen: explain overall variation.
    x = linspace(mu - 4.5 * sigma, mu + 4.5 * sigma, 400);
    density = shape_model(x, mu, sigma).phi ./ sigma;
    bandX = x(x >= mu - sigma & x <= mu + sigma);
    bandDensity = shape_model(bandX, mu, sigma).phi ./ sigma;
    dark = [0.10 0.16 0.19];
    gold = [0.66 0.51 0.23];
    teal = [0.18 0.44 0.42];

    curveHandle = plot(ax, x, density, '-', 'Color', dark, 'LineWidth', 2);
    hold(ax, 'on');
    bandHandle = area(ax, bandX, bandDensity, ...
        'FaceColor', [0.945 0.914 0.847], 'EdgeColor', 'none');
    plot(ax, x, density, '-', 'Color', dark, 'LineWidth', 2);
    middleHandle = line(ax, [mu mu], [0 max(density)], ...
        'Color', gold, 'LineWidth', 1.5);
    maximumDensity = max(density);
    text(ax, mu, 1.04 * maximumDensity, sprintf('middle %.2f %s', mu, u), ...
        'Color', gold, 'FontWeight', 'bold', 'FontSize', 11, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    text(ax, mu, 0.42 * maximumDensity, ...
        {'middle ~68% of transition gaps', '(within 1 overall variation)'}, ...
        'HorizontalAlignment', 'center', 'FontSize', 10, ...
        'Color', [0.40 0.38 0.33]);

    if isfield(result, 'mu_lo') && isfield(result, 'mu_hi') && ...
            isfinite(result.mu_lo) && isfinite(result.mu_hi)
        confidenceY = 0.12 * maximumDensity;
        cap = 0.025 * maximumDensity;
        line(ax, [result.mu_lo result.mu_hi], [confidenceY confidenceY], ...
            'Color', teal, 'LineWidth', 1.5);
        line(ax, [result.mu_lo result.mu_lo], ...
            [confidenceY - cap confidenceY + cap], 'Color', teal, 'LineWidth', 1.5);
        line(ax, [result.mu_hi result.mu_hi], ...
            [confidenceY - cap confidenceY + cap], 'Color', teal, 'LineWidth', 1.5);
        text(ax, mu, 0.18 * maximumDensity, sprintf( ...
            '%.4g%% middle-gap range: %.2f to %.2f %s', ...
            confidencePercent, result.mu_lo, result.mu_hi, u), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 9, 'Color', teal);
    end

    xlabel(ax, sprintf('gap (%s)', u));
    ylabel(ax, {'relative spread', 'of transition gaps'});
    title(ax, 'How transition gaps vary around the middle', ...
        'FontSize', 12, 'FontWeight', 'bold');
    set(ax, 'XLim', [cfg.min_level cfg.max_level]);
    set(ax, 'YLim', [0 1.24 * maximumDensity]);
    grid(ax, 'on');
    legend(ax, [curveHandle middleHandle bandHandle], ...
        {'fitted variation', 'middle gap', 'middle ~68%'}, ...
        'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
    hold(ax, 'off');
end

function strip_patch(ax, x1, x2, ylo, yhi, col)
%STRIP_PATCH  Draw one coloured band with explicit vertices (works on uiaxes).
    if ~(isfinite(x1) && isfinite(x2)) || x2 <= x1, return; end
    patch(ax, [x1 x2 x2 x1], [ylo ylo yhi yhi], col, 'EdgeColor', 'none');
end

function draw_interaction_curve(ax,result,cfg)
%DRAW_INTERACTION_CURVE Show how interaction probability falls as gap grows.
    if nargin<3 || isempty(cfg), cfg=neyer_settings(); end
    u='mm';
    if isfield(result,'unit') && ~isempty(result.unit), u=result.unit; end

    x=linspace(cfg.min_level,cfg.max_level,500);
    p=shape_model(x,result.mu,result.sigma).p;
    gold=[0.66 0.51 0.23];
    yesColor=[0.74 0.37 0.20];
    noColor=[0.18 0.44 0.42];

    plot(ax,x,100*p,'Color',gold,'LineWidth',2.5);
    hold(ax,'on');
    yes=result.successes(:);
    levels=result.levels(:);
    plot(ax,levels(yes),97*ones(sum(yes),1),'o', ...
        'MarkerFaceColor',yesColor,'MarkerEdgeColor','none','MarkerSize',6);
    plot(ax,levels(~yes),3*ones(sum(~yes),1),'o', ...
        'MarkerFaceColor',noColor,'MarkerEdgeColor','none','MarkerSize',6);

    edge_line(ax,result.high_interaction_gap,yesColor,'99.9% interaction');
    edge_line(ax,result.mu,gold,'middle gap - 50%');
    edge_line(ax,result.negligible_interaction_gap,noColor,'99.9% no interaction');

    xlim(ax,[cfg.min_level cfg.max_level]);
    ylim(ax,[0 100]);
    yticks(ax,[0 50 100]);
    yticklabels(ax,{'0%','50%','100%'});
    grid(ax,'on');
    xlabel(ax,sprintf('gap (%s)',u));
    ylabel(ax,'chance of interaction');
    title(ax,'Interaction becomes less likely as the gap increases');
    hold(ax,'off');
end

function edge_line(ax,x,color,label)
    if ~isfinite(x), return; end
    line(ax,[x x],[0 100],'Color',color,'LineStyle','--','LineWidth',1);
    text(ax,x,54,label,'Color',color,'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize',9);
end

function plan = estimate_study_plan(clean, reachable_model)
%ESTIMATE_STUDY_PLAN Produce a transparent requirements-first preparation plan.
% This is a pre-test estimate. It is not a final reliability claim and its
% rule version must be checked against the recorded simulation evidence.

    if ~isstruct(clean) || ~all(isfield(clean, {'mode', 'outcome', ...
            'reliability', 'confidence', 'accuracy_mm', ...
            'interaction_gap_mm', 'no_interaction_gap_mm', ...
            'minimum_gap_mm', 'maximum_gap_mm', ...
            'previous_information'}))
        error('estimate_study_plan:badInput', ...
            'Validated pre-test planner answers are required.');
    end
    if ~strcmp(clean.mode, 'requirements_first')
        error('estimate_study_plan:badMode', ...
            'This calculation needs the requirements-first planner mode.');
    end
    if ~isstruct(reachable_model) || ~isfield(reachable_model, 'gaps_mm')
        error('estimate_study_plan:badReachableModel', ...
            'The reachable physical gaps must be prepared before calculating the plan.');
    end

    z95 = shape_model(0.95, 'quantile');
    midpoint_mm = 0.5 * (clean.interaction_gap_mm + ...
        clean.no_interaction_gap_mm);
    expected_sigma_mm = (clean.no_interaction_gap_mm - ...
        clean.interaction_gap_mm) / (2 * z95);
    expected_sigma_mm = adjust_previous_information(expected_sigma_mm, clean);

    settings = neyer_settings();
    main_result = plan_samples(legacy_tail(clean.outcome), ...
        clean.reliability, clean.confidence, settings, ...
        struct('sigma', expected_sigma_mm, ...
        'accuracy_mm', clean.accuracy_mm));
    moderate_result = plan_samples(legacy_tail(clean.outcome), ...
        clean.reliability, clean.confidence, settings, ...
        struct('sigma', 1.5 * expected_sigma_mm, ...
        'accuracy_mm', clean.accuracy_mm));
    difficult_result = plan_samples(legacy_tail(clean.outcome), ...
        clean.reliability, clean.confidence, settings, ...
        struct('sigma', 2.0 * expected_sigma_mm, ...
        'accuracy_mm', clean.accuracy_mm));

    main_articles = main_result.n_recommended;
    reserve_1_articles = max(0, moderate_result.n_recommended - main_articles);
    reserve_2_articles = max(0, difficult_result.n_recommended - ...
        moderate_result.n_recommended);
    reliability_validation_floor_articles = 400;
    calculated_total_articles = main_articles + reserve_1_articles + ...
        reserve_2_articles;
    reserve_2_articles = reserve_2_articles + max(0, ...
        reliability_validation_floor_articles - calculated_total_articles);
    total_articles = main_articles + reserve_1_articles + reserve_2_articles;

    [~, start_row] = min(abs(reachable_model.gaps_mm - midpoint_mm));
    starting_gap_mm = reachable_model.gaps_mm(start_row);

    reliability_k = shape_model(clean.reliability, 'quantile');
    if strcmp(clean.outcome, 'interaction')
        estimated_target_gap_mm = midpoint_mm - reliability_k * expected_sigma_mm;
    else
        estimated_target_gap_mm = midpoint_mm + reliability_k * expected_sigma_mm;
    end
    [reachable_target_gap_mm, reachable_status] = round_reachable_gap( ...
        estimated_target_gap_mm, clean.outcome, reachable_model, []);

    assumptions = strings(0, 1);
    if strcmp(clean.previous_information, 'first_study')
        assumptions(end + 1, 1) = [ ...
            "This is treated as a first study with no fitted earlier result."];
        assumptions(end + 1, 1) = [ ...
            "Each almost-every-time endpoint is treated as 95%, not 100%."];
    end
    assumptions(end + 1, 1) = sprintf([ ...
        'The starting overall variation is estimated as %.4g mm from the two endpoint answers.'], ...
        expected_sigma_mm);
    assumptions(end + 1, 1) = [ ...
        "Reserve group 1 checks 1.5 times the starting variation; " + ...
        "reserve group 2 extends that check to 2 times the starting variation."];
    assumptions(end + 1, 1) = [ ...
        "Those reserve sizes are recommendations until the recorded virtual study is accepted."];
    assumptions(end + 1, 1) = sprintf([ ...
        'The main study may estimate the middle gap and overall variation. ' ...
        'A supported reliability setting is withheld until %d independent articles.'], ...
        reliability_validation_floor_articles);

    suggestions = strings(0, 1);
    feasible = true;
    plan_kind = 'full_study';
    if clean.confidence <= 0.50
        reliability_instruction_supported = false;
        reliability_instruction_status = 'exploratory_confidence';
        suggestions(end + 1, 1) = [ ...
            "Confidence of 50% or less is exploratory. The study may estimate " + ...
            "the middle gap and overall variation, but it will not issue a " + ...
            "safety-supported reliability setting."];
    elseif clean.confidence > 0.95
        reliability_instruction_supported = false;
        reliability_instruction_status = 'above_recorded_validation';
        suggestions(end + 1, 1) = [ ...
            "Confidence above 95% can be calculated, but the recorded virtual " + ...
            "studies do not validate a safety-supported operating instruction " + ...
            "at that level. Use 95% or add stronger validation evidence."];
    else
        reliability_instruction_supported = true;
        reliability_instruction_status = 'supported_after_final_checkpoint';
    end

    uncertainty_ratio = expected_sigma_mm / clean.accuracy_mm;
    if strcmp(clean.previous_information, 'first_study') && uncertainty_ratio > 50
        feasible = false;
        plan_kind = 'discovery';
        suggestions(end + 1, 1) = [ ...
            "Begin with a smaller discovery study. The first-study range is too broad " + ...
            "for one trustworthy full-study quantity at the requested accuracy."];
    end

    if strcmp(reachable_status.code, 'ok')
        physical_rounding_error_mm = abs(reachable_target_gap_mm - ...
            estimated_target_gap_mm);
    else
        physical_rounding_error_mm = Inf;
    end
    if physical_rounding_error_mm > clean.accuracy_mm
        feasible = false;
        suggestions(end + 1, 1) = [ ...
            "Improve the physical gap capability or accept wider gap accuracy; " + ...
            "the current reachable settings cannot meet the requested accuracy safely."];
    end
    if estimated_target_gap_mm < clean.minimum_gap_mm || ...
            estimated_target_gap_mm > clean.maximum_gap_mm
        feasible = false;
        suggestions(end + 1, 1) = [ ...
            "The estimated reliability gap is outside the permitted range. " + ...
            "Widen the permitted range only if the equipment and safety rules allow it."];
    end
    if isempty(suggestions)
        suggestions = [ ...
            "No change is suggested before recorded virtual validation."];
    end

    plan = struct( ...
        'schema_version', '1.1', ...
        'rule_version', 'absolute-gap-n-minus-15-simulation-floor-400-v3', ...
        'mode', clean.mode, ...
        'outcome', clean.outcome, ...
        'reliability', clean.reliability, ...
        'confidence', clean.confidence, ...
        'accuracy_mm', clean.accuracy_mm, ...
        'interaction_gap_mm', clean.interaction_gap_mm, ...
        'no_interaction_gap_mm', clean.no_interaction_gap_mm, ...
        'minimum_gap_mm', clean.minimum_gap_mm, ...
        'maximum_gap_mm', clean.maximum_gap_mm, ...
        'physical_setup', clean.physical_setup, ...
        'reachable_model', reachable_model, ...
        'main_articles', main_articles, ...
        'reserve_1_articles', reserve_1_articles, ...
        'reserve_2_articles', reserve_2_articles, ...
        'total_articles', total_articles, ...
        'reliability_validation_floor_articles', ...
            reliability_validation_floor_articles, ...
        'reliability_instruction_supported', ...
            reliability_instruction_supported, ...
        'reliability_instruction_status', reliability_instruction_status, ...
        'starting_gap_mm', starting_gap_mm, ...
        'estimated_middle_gap_mm', midpoint_mm, ...
        'estimated_sigma_mm', expected_sigma_mm, ...
        'estimated_target_gap_mm', estimated_target_gap_mm, ...
        'reachable_target_gap_mm', reachable_target_gap_mm, ...
        'physical_rounding_error_mm', physical_rounding_error_mm, ...
        'reachable_status', reachable_status, ...
        'checkpoint_status', 'not_started', ...
        'plan_kind', plan_kind, ...
        'feasible', feasible, ...
        'assumptions', assumptions, ...
        'suggestions', suggestions, ...
        'validation_basis', [ ...
            'Published large-sample Neyer variance starting estimate with the ' ...
            'N-15 spread correction, plus the 400-article safety floor selected ' ...
            'from the recorded virtual studies. Reserve use remains a user decision.']);
end

function name = legacy_tail(outcome)
    if strcmp(outcome, 'interaction')
        name = 'break';
    else
        name = 'survive';
    end
end

function sigma_mm = adjust_previous_information(sigma_mm, clean)
    switch clean.previous_information
        case 'sudden'
            sigma_mm = 0.5 * sigma_mm;
        case 'gradual'
            sigma_mm = 2.0 * sigma_mm;
        case 'advanced_value'
            if ~isfield(clean, 'previous_sigma_mm') || ...
                    ~(isscalar(clean.previous_sigma_mm) && ...
                    isfinite(clean.previous_sigma_mm) && clean.previous_sigma_mm > 0)
                error('estimate_study_plan:missingPreviousSigma', ...
                    'Enter the positive previous overall-variation value in millimetres.');
            end
            sigma_mm = clean.previous_sigma_mm;
    end
end

function answer = estimate_supported_targets(clean, reachable_model, fixed_kind)
%ESTIMATE_SUPPORTED_TARGETS Estimate what a fixed article supply may support.
% One user choice remains fixed. The other value is estimated from the same
% provisional quantity rule as the requirements-first planner.

    if ~isstruct(clean) || ~isfield(clean, 'mode') || ...
            ~strcmp(clean.mode, 'available_articles_first')
        error('estimate_supported_targets:badMode', ...
            'Choose the available-articles-first planner mode for this calculation.');
    end
    if ~isfield(clean, 'available_articles') || ...
            ~(isscalar(clean.available_articles) && ...
            clean.available_articles >= 1 && ...
            clean.available_articles == floor(clean.available_articles))
        error('estimate_supported_targets:badArticleCount', ...
            'Enter the positive whole number of articles available.');
    end
    fixed_kind = lower(strtrim(char(string(fixed_kind))));
    if ~any(strcmp(fixed_kind, {'reliability', 'confidence'}))
        error('estimate_supported_targets:badFixedChoice', ...
            'Choose whether reliability or confidence must remain fixed.');
    end

    candidate_input = clean;
    candidate_input.mode = 'requirements_first';
    if strcmp(fixed_kind, 'reliability')
        candidate_values = (100:999)' / 1000;
        fixed_value = clean.reliability;
        estimated_kind = 'confidence';
    else
        candidate_values = (500:999)' / 1000;
        fixed_value = clean.confidence;
        estimated_kind = 'reliability';
    end

    required_articles = zeros(size(candidate_values));
    candidate_is_validated = false(size(candidate_values));
    estimated_plans = cell(size(candidate_values));
    for candidate_number = 1:numel(candidate_values)
        if strcmp(fixed_kind, 'reliability')
            candidate_input.reliability = fixed_value;
            candidate_input.confidence = candidate_values(candidate_number);
        else
            candidate_input.confidence = fixed_value;
            candidate_input.reliability = candidate_values(candidate_number);
        end
        estimated_plans{candidate_number} = estimate_study_plan( ...
            candidate_input, reachable_model);
        required_articles(candidate_number) = ...
            estimated_plans{candidate_number}.total_articles;
        candidate_is_validated(candidate_number) = ...
            estimated_plans{candidate_number}.reliability_instruction_supported;
    end
    supported = required_articles <= clean.available_articles & ...
        candidate_is_validated;
    supported_rows = find(supported);

    best_reliability = NaN;
    best_confidence = NaN;
    if ~isempty(supported_rows)
        best_row = supported_rows(end);
        if strcmp(fixed_kind, 'reliability')
            best_reliability = fixed_value;
            best_confidence = candidate_values(best_row);
        else
            best_reliability = candidate_values(best_row);
            best_confidence = fixed_value;
        end
    end

    gaps = reachable_model.gaps_mm(:);
    if numel(gaps) < 2
        physical_resolution_mm = Inf;
    else
        physical_resolution_mm = min(diff(gaps));
    end
    physically_achievable = 0.5 * physical_resolution_mm <= ...
        clean.accuracy_mm + reachable_model.comparison_tolerance_mm;
    messages = strings(0, 1);
    validation_floor = estimated_plans{1}.reliability_validation_floor_articles;
    if clean.available_articles < validation_floor
        messages(end + 1, 1) = sprintf([ ...
            'The recorded safety rule requires at least %d independent articles ' ...
            'before a reliability operating instruction can be supported.'], ...
            validation_floor);
    end
    if ~physically_achievable
        messages(end + 1, 1) = [ ...
            "The physical reachable gaps are too coarse for the requested accuracy. " + ...
            "Improve the physical capability or accept wider accuracy."];
    end
    if isempty(supported_rows)
        messages(end + 1, 1) = [ ...
            "This article quantity does not support even the lowest displayed " + ...
            "candidate under the current planning estimate."];
    end
    messages(end + 1, 1) = [ ...
        "Final confidence and reliability depend on the real gap locations and outcomes."];

    answer = struct( ...
        'fixed_kind', fixed_kind, ...
        'fixed_value', fixed_value, ...
        'estimated_kind', estimated_kind, ...
        'available_articles', clean.available_articles, ...
        'candidate_values', candidate_values, ...
        'required_articles', required_articles, ...
        'supported', supported, ...
        'best_reliability', best_reliability, ...
        'best_confidence', best_confidence, ...
        'physically_achievable', physically_achievable, ...
        'physical_resolution_mm', physical_resolution_mm, ...
        'messages', messages, ...
        'statement', [ ...
            'This is a pre-test expectation, not a final claim. Real evidence ' ...
            'must be checked after the study.']);
end

function xb = find_root(R, x0, dir, thr, cap, floorval)
%FIND_ROOT  Bracket-then-bisect one-sided root of R(x)=thr, on side `dir` of x0.
%   R(x0)~0 and R rises away from x0. Returns NaN if not bracketed within `cap`
%   of x0. `floorval` eases a downward search toward a hard limit (e.g. sigma>0).
%   Shared by lr_confidence and the reliability-at-confidence units.  [addendum LR]
    xb  = NaN;
    lo  = x0;                       % R(lo) < thr
    step = 0.05 * max(abs(x0), 1);
    hi  = NaN; found = false;
    for it = 1:100
        cand = x0 + dir*step;
        if dir < 0 && cand <= floorval
            cand = 0.5*(lo + floorval);
        end
        if abs(cand - x0) > cap, return; end       % not bracketed -> NaN
        if R(cand) >= thr
            hi = cand; found = true; break;
        else
            lo = cand; step = 2*step;
        end
    end
    if ~found, return; end
    for it = 1:100                                  % bisection
        mid = 0.5*(lo + hi);
        if R(mid) >= thr, hi = mid; else lo = mid; end
        if abs(hi - lo) <= 1e-6 * max(abs(x0),1), break; end
    end
    xb = 0.5*(lo + hi);
end

function s0 = fit_sigma0(levels)
%FIT_SIGMA0  A positive starting spread for best_fit, derived from the data.
%   Used by the reliability-at-confidence units (Mode A/B) to seed best_fit's
%   inner optimiser. Falls back to a quarter of the tested range (min 1) when the
%   sample spread is zero or undefined.  [addendum RAC / RECOMMENDATION]
    lv = levels(:);
    s0 = std(lv);
    if ~(s0 > 0 && isfinite(s0))
        s0 = max((max(lv) - min(lv)) / 4, 1);
    end
end

function text = format_confidence_range(confidence, lower_limit, upper_limit, unit)
%FORMAT_CONFIDENCE_RANGE Describe incomplete limits without displaying NaN.
    if nargin < 4 || isempty(unit), unit = 'mm'; end
    confidence_text = sprintf('%.4g%%', 100 * confidence);
    lower_text = limit_text(lower_limit, unit, 'lower');
    upper_text = limit_text(upper_limit, unit, 'upper');
    if isfinite(lower_limit) && isfinite(upper_limit)
        text = sprintf('%s confidence range: %.2f to %.2f %s', ...
            confidence_text, lower_limit, upper_limit, unit);
    else
        text = sprintf('%s confidence range: %s; %s', ...
            confidence_text, lower_text, upper_text);
    end
end

function text = limit_text(value, unit, side)
    if isfinite(value)
        text = sprintf('%s limit %.2f %s', side, value, unit);
    else
        text = sprintf('%s limit not established', side);
    end
end

function message = format_requested_gap(level, unit)
%FORMAT_REQUESTED_GAP Build the operator instruction with two decimals.
%   Internal calculations and measured readings retain their full precision;
%   only the physical build instruction is deliberately simplified.
    if nargin < 2 || isempty(unit), unit = 'mm'; end
    message = sprintf('Build a gap of %.2f %s.',level,unit);
end

function s = format_result_text(result)
%FORMAT_RESULT_TEXT  Pure: turn a report `result` into the plain-language popup text.
%   s = FORMAT_RESULT_TEXT(result) returns a multi-line char array, reusing the
%   numbers already on `result` (no re-estimation; report.m untouched). If results
%   have not overlapped, returns a single "no result" line. [addendum POPUP]
    if ~isfield(result,'has_overlap') || ~result.has_overlap || isnan(result.mu)
        if isfield(result,'status') && strcmp(result.status,'paused')
            s = 'PAUSED - REVIEW REQUIRED. Completed test data are saved; do not continue automatically.';
        else
            s = 'No result yet - results have not overlapped. Run more tests.';
        end
        return;
    end
    decision = result_decision_summary(result);
    if decision.supported
        decision_lines = { ...
            'SUPPORTED OPERATING INSTRUCTION'
            decision.operating_instruction
            char(decision.physical_build_instruction)};
    else
        decision_lines = { ...
            'SUPPORTED OPERATING INSTRUCTION: Not established'
            decision.explanation};
    end
    result_lines = {
        ''
        sprintf('Tests used: %d', result.n)
        ''
        sprintf('MIDDLE GAP (about 50%% interaction): %.2f mm', result.mu)
        ['  ' format_confidence_range(result.confidence_level, ...
            result.mu_lo, result.mu_hi, 'mm')]
        ''
        sprintf('OVERALL VARIATION: %.2f mm', result.sigma)
        ['  ' format_confidence_range(result.confidence_level, ...
            result.sigma_lo, result.sigma_hi, 'mm')]
        '  This describes how much the entire tested process varies from article to article.'
        ''
        'Smaller gaps make interaction more likely; larger gaps make it less likely.'
    };
    lines = [decision_lines(:); result_lines(:)];
    s = strjoin(lines, sprintf('\n'));
end

function tf = has_overlap(levels, successes)
%HAS_OVERLAP  Worker #4 â€” the Silvapulle condition (Stage 2 -> Stage 3 gate).
%
%   tf = HAS_OVERLAP(levels, successes) answers yes/no: have interaction and
%   no-interaction results started to interleave? Until they do, there is
%   enough information to compute a real best-fit, so the loop must stay on the
%   Stage-2 surrogate path. Once they overlap, the MLE exists and Stage 3
%   begins.  [brief sec.3 Stage 2; sec.4 worker #4; sec.8 #2 -- the Silvapulle
%   condition]
%
%   In this decreasing-gap model, overlap means an interaction occurred at a
%   strictly larger gap than at least one no-interaction result. Equivalently:
%
%       overlap  <=>  max(interaction gaps) > min(no-interaction gaps)
%
%   Strict inequality is deliberate: if the two outcomes occur only at the
%   same boundary gap, the data is still
%   separable and the MLE diverges, so that is NOT overlap.
%
%   Inputs
%     levels     vector of test levels run so far.
%     successes  logical vector: true = interaction, false = no interaction.
%
%   Output
%     tf  logical scalar. false if either group is empty (nothing to interleave).

    levels    = levels(:);
    successes = logical(successes(:));

    if numel(levels) ~= numel(successes)
        error('has_overlap:sizeMismatch', ...
              'levels and successes must have the same length.');
    end

    success_levels = levels(successes);
    failure_levels = levels(~successes);

    % Need at least one of each to possibly interleave.
    if isempty(success_levels) || isempty(failure_levels)
        tf = false;
        return;
    end

    % Gap model decreases: overlap requires an interaction at a larger gap
    % than at least one non-interaction.
    tf = max(success_levels) > min(failure_levels);
end

function res = height_for_reliability(levels, successes, tail, R, C)
%HEIGHT_FOR_RELIABILITY  Mode A: the conservative height for a target reliability.
%   res = HEIGHT_FOR_RELIABILITY(levels, successes, tail, R, C)
%     tail : 'break'   -> all-fire level (mu + k*sigma), one-sided UPPER bound
%            'survive' -> no-fire  level (mu - k*sigma), one-sided LOWER bound
%     R    : target reliability in (0,1)   (e.g. 0.999)
%     C    : confidence level in (0,1)      (e.g. 0.95)
%   Returns struct: .height (point estimate), .bound (conservative bound), .tail,
%   .R, .C. Fields are NaN when the data do not overlap, or when the bound cannot
%   be bracketed within the sanity cap (never a fabricated number).
%   Reuses the same profile-likelihood engine as lr_confidence.
%   [PAPER q=mu+/-k*sigma; PUBLISHED likelihood-ratio profile bound]
    levels    = levels(:);
    successes = logical(successes(:));
    tail = lower(tail);
    if ~any(strcmp(tail, {'break','survive'}))
        error('height_for_reliability:badTail', 'tail must be ''break'' or ''survive''.');
    end
    if ~(isscalar(R) && isreal(R) && R > 0 && R < 1)
        error('height_for_reliability:badR', 'reliability R must be a single number in (0,1).');
    end
    if ~(isscalar(C) && isreal(C) && C > 0 && C < 1)
        error('height_for_reliability:badC', 'confidence C must be a single number in (0,1).');
    end

    res = struct('height', NaN, 'bound', NaN, 'tail', tail, 'R', R, 'C', C);
    if ~has_overlap(levels, successes), return; end

    [mu, sigma, Lmax] = best_fit(levels, successes, mean(levels), fit_sigma0(levels));
    k   = shape_model(R, 'quantile');
    c1  = one_sided_profile_threshold(C);
    cap = 5 * (max(levels) - min(levels));

    % In the gap application, interaction probability DECREASES with gap.
    % Therefore a high-interaction target is on the small-gap side, while a
    % high no-interaction target is on the large-gap side.
    if strcmp(tail, 'break')
        res.height = mu - k*sigma;
        Rq = @(q) 2*(Lmax - prof_quantile(levels, successes, q, -k, sigma));
        res.bound  = find_root(Rq, res.height, -1, c1, cap, -Inf);
    else
        res.height = mu + k*sigma;
        Rq = @(q) 2*(Lmax - prof_quantile(levels, successes, q, +k, sigma));
        res.bound  = find_root(Rq, res.height, +1, c1, cap, +Inf);
    end
end

function [j0, j1, j2] = info_terms(x, mu, sigma)
%INFO_TERMS  Fisher information building blocks J0, J1, J2 (Eq.3).
%
%   [j0, j1, j2] = INFO_TERMS(x, mu, sigma) returns, for each level x, the
%   per-test information terms of the bell-curve model:  [brief App.A Eq.3]
%
%       J_j(z) = phi(z)^2 * z^j / ( Phi(z) * Q(z) * sigma^2 ),   z = (x-mu)/sigma
%
%   so j0 = J0, j1 = J1, j2 = J2. Summing these over a set of levels gives the
%   information matrix entries I00, I01(=I10), I11 (Eq.4), used by the D-optimal
%   picker (worker #3) and by the confidence calculation in report (worker #9).
%   Keeping the formula here means the information model lives in exactly one
%   place, just as the shape lives only in shape_model.
%
%   Tail guard (numerical hazard #1, brief sec.8): where Phi*Q underflows to
%   zero far from centre, the ratio becomes Inf/NaN although the true
%   information there is ~0; those entries are set to 0. All shape quantities
%   come from shape_model (worker #1).

    s = shape_model(x, mu, sigma);

    base = (s.phi.^2) ./ (s.Phi .* s.Q .* sigma^2);
    base(~isfinite(base)) = 0;

    j0 = base;
    j1 = base .* s.z;
    j2 = base .* s.z.^2;
end

function [plan, loaded_path] = load_study_plan(selected_path)
%LOAD_STUDY_PLAN Reopen a supported human-readable JSON study plan.

    loaded_path = absolute_load_path(selected_path);
    if ~isfile(loaded_path)
        error('load_study_plan:notFound', ...
            'The selected study plan could not be found: %s', loaded_path);
    end
    try
        plan = jsondecode(fileread(loaded_path));
    catch decode_error
        error('load_study_plan:invalidJson', ...
            'The selected file is not a readable study plan: %s', ...
            decode_error.message);
    end
    if ~isstruct(plan) || ~isfield(plan, 'schema_version')
        error('load_study_plan:unsupportedVersion', ...
            'This file has no supported study-plan version.');
    end
    version_text = char(string(plan.schema_version));
    if ~strcmp(version_text, '1.1')
        error('load_study_plan:unsupportedVersion', ...
            ['This study plan uses version %s. This tool supports the safer ' ...
             'version 1.1 plan; the older file was not changed. Create a new ' ...
             'plan so the validated article floor and confidence limits are present.'], ...
             version_text);
    end
    required_fields = {'mode', 'outcome', 'reliability', 'confidence', ...
        'accuracy_mm', 'minimum_gap_mm', 'maximum_gap_mm', ...
        'main_articles', 'reserve_1_articles', 'reserve_2_articles', ...
        'total_articles', 'reachable_model', 'checkpoint_status', ...
        'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~all(isfield(plan, required_fields))
        error('load_study_plan:incompletePlan', ...
            'The selected plan is missing information required to continue the study.');
    end
    [safe_plan, safety_message] = validate_study_plan_safety(plan);
    if ~safe_plan
        error('load_study_plan:unsafePlan', ...
            'The selected plan cannot be used safely: %s', safety_message);
    end
end

function path = absolute_load_path(selected_path)
    if isstring(selected_path) && isscalar(selected_path)
        path = char(selected_path);
    elseif ischar(selected_path) && isrow(selected_path)
        path = selected_path;
    else
        error('load_study_plan:badPath', ...
            'Choose one complete study-plan filename.');
    end
    path = strtrim(path);
    if isempty(path)
        error('load_study_plan:badPath', ...
            'Choose one complete study-plan filename.');
    end
    is_windows_absolute = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
    is_unc = startsWith(path, '\\');
    if ~(is_windows_absolute || is_unc)
        path = fullfile(pwd, path);
    end
end

function ll = loglik(levels, successes, mu, sigma)
%LOGLIK  Log-likelihood of the bell-curve sensitivity model (Eq.1), one home.
%
%   ll = LOGLIK(levels, successes, mu, sigma) returns
%     l(mu,sigma) = sum_{interaction} ln Phi(z)
%                 + sum_{no interaction} ln Q(z),  z=(mu-gap)/sigma
%   All probabilities come from shape_model (#1). A realmin floor stops a single
%   ln(0) from sending the value to -Inf. Kept here so best_fit (#2) and
%   lr_confidence use the identical formula.  [brief App.A Eq.1]
    levels    = levels(:);
    successes = logical(successes(:));
    if numel(levels) ~= numel(successes)
        error('loglik:sizeMismatch', 'levels and successes must have the same length.');
    end
    s   = shape_model(levels, mu, sigma);       % worker #1
    Phi = max(s.Phi, realmin);
    Q   = max(s.Q,   realmin);
    ll  = sum(log(Phi(successes))) + sum(log(Q(~successes)));
end

function ci = lr_confidence(levels, successes, mu0, sigma0, cfg)
%LR_CONFIDENCE  Likelihood-ratio (profile) confidence bounds.
%
%   ci = LR_CONFIDENCE(levels, successes, mu0, sigma0, cfg) returns bounds at
%   cfg.confidence_level computed by the profile-likelihood method:
%     .confidence_level
%     .mu_lo, .mu_hi        two-sided interval for the average
%     .sigma_lo, .sigma_hi  two-sided interval for the spread
%     .all_fire_cbound      one-sided UPPER bound on the all-fire level (mu+k*sigma)
%     .no_fire_cbound       one-sided LOWER bound on the no-fire  level (mu-k*sigma)
%   (mu0,sigma0) is only a starting guess; the true (unclamped) MLE is found
%   internally so the likelihood-ratio reference is the real maximum. Requires
%   overlap; if the data do not overlap, or a bound cannot be bracketed within a
%   sanity cap, that field is NaN. Thresholds come from the normal quantile
%   (shape_model inverse) so no toolbox is needed.  [addendum LR; profile likelihood]
    if nargin < 5 || isempty(cfg), cfg = neyer_settings(); end
    C = cfg.confidence_level;

    ci = struct('confidence_level', C, 'mu_lo', NaN, 'mu_hi', NaN, ...
                'sigma_lo', NaN, 'sigma_hi', NaN, ...
                'all_fire_cbound', NaN, 'no_fire_cbound', NaN);

    if ~has_overlap(levels, successes)
        return;                              % no real MLE -> no bounds
    end

    [muhat, sighat, Lmax] = best_fit(levels, successes, mu0, sigma0);

    c2  = shape_model((1+C)/2, 'quantile')^2;    % two-sided threshold
    c1  = one_sided_profile_threshold(C);         % one-sided threshold
    k   = shape_model(cfg.tail_fraction, 'quantile');
    rng = max(levels(:)) - min(levels(:));
    cap = 5 * rng;   % based on the tested range only, so a runaway sigma can't inflate the sanity cap

    Rmu = @(m) 2*(Lmax - prof_mu(levels, successes, m, sighat));
    ci.mu_lo = find_root(Rmu, muhat, -1, c2, cap, -Inf);
    ci.mu_hi = find_root(Rmu, muhat, +1, c2, cap, +Inf);

    Rsig = @(s) 2*(Lmax - prof_sigma(levels, successes, s, muhat));
    ci.sigma_lo = find_root(Rsig, sighat, -1, c2, cap, 1e-6);
    ci.sigma_hi = find_root(Rsig, sighat, +1, c2, cap, +Inf);

    qa  = muhat + k*sighat;
    Rqa = @(q) 2*(Lmax - prof_quantile(levels, successes, q, +k, sighat));
    ci.all_fire_cbound = find_root(Rqa, qa, +1, c1, cap, +Inf);

    qn  = muhat - k*sighat;
    Rqn = @(q) 2*(Lmax - prof_quantile(levels, successes, q, -k, sighat));
    ci.no_fire_cbound = find_root(Rqn, qn, -1, c1, cap, -Inf);
end

% ---- profile maximisers (base fminsearch over log sigma) -----------------
function L = prof_mu(levels, successes, m, sigma0)
    f = @(t) -loglik(levels, successes, m, exp(t));
    that = fminsearch(f, log(sigma0), pl_opts());
    L = -f(that);
end

function L = prof_sigma(levels, successes, s, mu0)
    f = @(m) -loglik(levels, successes, m, s);
    mhat = fminsearch(f, mu0, pl_opts());
    L = -f(mhat);
end

function neyer_app()
%NEYER_APP  Launch menu for the D-Optimal Sensitivity Tool (the compiled app's
%   entry point). Five grouped buttons over the unchanged engine. [compiled-app]
    if ~isdeployed
    end

    state.result = [];      % most recent run, for the Reliability button
    fig = uifigure('Name', 'Neyer Gap Test', 'Position', [300 160 480 500], ...
        'Color', [247 249 250] / 255);
    gl = uigridlayout(fig, [8 1]);
    gl.RowHeight  = {44, 42, 58, 58, 48, 12, 48, 48};
    gl.Padding    = [26 20 26 20];
    gl.RowSpacing = 10;

    title = uilabel(gl, 'Text', 'Neyer Gap Test', 'FontSize', 20, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
                    'FontColor', [33 49 58] / 255);
    title.Layout.Row = 1;

    guide = uilabel(gl, 'Text', ...
        'Run a Test works independently. The planner is optional and separate.', ...
        'FontSize', 13, 'FontWeight', 'bold', ...
        'FontColor', [35 108 142] / 255);
    guide.Layout.Row = 2;

    uibutton(gl, 'Text', 'Pre-Test Planner (separate)', 'FontSize', 16, ...
        'FontWeight', 'bold', 'BackgroundColor', [35 108 142] / 255, ...
        'FontColor', [1 1 1], 'ButtonPushedFcn', @onPlanner);
    uibutton(gl, 'Text', 'Run a Test', 'FontSize', 16, ...
        'FontWeight', 'bold', 'BackgroundColor', [47 125 109] / 255, ...
        'FontColor', [1 1 1], 'ButtonPushedFcn', @onRunTest);
    uibutton(gl, 'Text', 'Review latest results', 'FontSize', 15, ...
        'ButtonPushedFcn', @onReliability);
    uilabel(gl,  'Text', '');
    uibutton(gl, 'Text', 'Run the published example', 'FontSize', 15, ...
        'ButtonPushedFcn', @onDemo);
    uibutton(gl, 'Text', 'Help and definitions', 'FontSize', 15, ...
        'ButtonPushedFcn', @onHelp);

    % ---- callbacks (nested: share `state` and `fig`) ------------------------
    function onRunTest(~, ~)
        try
            res = run_test_ui([], []);
            if ~isempty(res), state.result = res; end
        catch err
            uialert(fig, err.message, 'Something went wrong');
        end
    end

    function onDemo(~, ~)
        try
            d = run_demo();
            state.result = d.result;
            show_result(d.result);
            if d.is_match
                uialert(fig, sprintf(['Self-check PASSED.\n\nExpected middle gap 5.3922, overall variation 1.0412.\n' ...
                    'Got %.4f / %.4f.  MATCH.'], d.got_mu, d.got_sigma), ...
                    'Demo verified', 'Icon', 'success');
            else
                uialert(fig, sprintf(['Self-check MISMATCH.\n\nExpected middle gap 5.3922 and overall variation 1.0412; got %.4f / %.4f.\n' ...
                    'Do not trust this build.'], d.got_mu, d.got_sigma), ...
                    'Demo FAILED', 'Icon', 'error');
            end
        catch err
            fig.UserData = struct('demo_error_identifier', err.identifier, ...
                'demo_error_message', err.message);
            uialert(fig, err.message, 'Demo could not run');
        end
    end

    function onPlanner(~, ~)
        try
            plan = pretest_planner_ui();
            if ~isempty(plan)
                uialert(fig, sprintf([ ...
                    'The separate plan contains %d main-study articles.\n\n' ...
                    'Direct Run a Test does not use this plan.'], ...
                    plan.main_articles), 'Plan ready', 'Icon', 'success');
            end
        catch err
            uialert(fig, err.message, 'Please check your inputs');
        end
    end

    function onReliability(~, ~)
        if isempty(state.result)
            uialert(fig, 'Run a test first, then this opens its results and reliability tool.', ...
                    'No test yet', 'Icon', 'info');
            return;
        end
        try
            show_result(state.result);
        catch err
            uialert(fig, err.message, 'Could not open');
        end
    end

    function onHelp(~, ~)
        try
            show_manual();
        catch err
            uialert(fig, err.message, 'Help unavailable');
        end
    end
end

function s = neyer_settings()
%NEYER_SETTINGS  The single home for every constant the method uses.
%
%   Ground rule from the build brief: nothing is hard-coded out of sight.
%   Every number lives here with its source tagged inline as one of
%     PAPER          - straight from Neyer (1994)
%     PUBLISHED      - from other named work
%     RECOMMENDATION - an engineering judgement made during design
%   This mirrors the table in brief sec.6.
%
%   Usage:  s = settings();  then read fields, e.g. s.search_window_sigmas.

    % --- Stage 1: reach-out search (find the zone) --------------------------
    % First reach from the centre, then the offset doubles each step until both
    % a break and a survive have been seen. Both values are reconstructed to
    % reproduce Neyer Table 1 (offsets 0.2,0.4,0.8,1.6,3.2 = 2*sigma_guess
    % doubling); for the paper's inputs 2*sigma_guess also equals
    % (mu_max-mu_min)/4. brief sec.3 Stage 1 / sec.7.
    s.stage1_reach_sigmas = 2;             % RECOMMENDATION (first reach = 2*sigma_guess)
    s.stage1_growth       = 2;             % PAPER ("roughly doubling the stride each step")

    % --- Stage 2: shrink the assumed spread a little each gap-closing step ---
    % brief sec.6 / sec.3 Stage 2.
    s.stage2_shrink = 0.8;                 % PAPER (tuned by simulation; 0.8-0.85 discussed)

    % --- Stage 2: bisect-vs-probe switch ------------------------------------
    % While the survive/break bracket is wider than this many guessed spreads,
    % close the gap by bisection (test the midpoint). Once it is narrower,
    % bisection stalls, so switch to a D-optimal probe that overshoots the
    % bracket to force the first overlap. Reconstructed from Table 1: the
    % bracket goes 1.6,0.8,0.4,0.2 (bisected) then 0.1 (probed). brief sec.7.
    s.stage2_bisect_width_sigmas = 1.0;    % PAPER (Figure 2: binary search while Diff > SigmaG)

    % --- Most-informative offset from centre --------------------------------
    % This is an EMERGENT target used only as a sanity check; it is NOT fed
    % into the level search (the search finds it on its own). brief sec.6.
    s.most_informative_offset = 1.138;     % PAPER (in units of spread)

    % --- Candidate-search window: fence against useless extreme levels -------
    % Search within +/- this many spreads of the current centre. brief sec.6/8.
    s.search_window_sigmas = 5;            % RECOMMENDATION ("no info beyond ~3 spreads" is PAPER)

    % --- Candidate grid resolution for the level search ---------------------
    % Number of grid points across the full window. brief sec.6.
    s.grid_points = 20001;                 % RECOMMENDATION

    % --- Test stimulus resolution -------------------------------------------
    % A physical test level can only be set to finite resolution, so the chosen
    % level is rounded to this many decimals before it is tested and recorded.
    % This matches the paper's 2-decimal Table 1 (and the acceptance tolerance)
    % and prevents full-precision feedback from drifting the trajectory. sec.6/7.
    s.level_decimals = 2;                  % RECOMMENDATION

    % --- MLE clips (worker #5, sanity_clamp) --------------------------------
    s.clip_mu_to_tested_range    = true;   % PAPER (average kept within tested level range)
    s.clip_sigma_to_tested_range = true;   % PAPER (spread <= max-min tested level)

    % --- Left/right shoulder choice each step -------------------------------
    % Tie-break / balancing policy when both sides are equally informative.
    % The determinant normally picks a clear side on its own; this only
    % matters on a near-tie. brief sec.6.
    s.alternate_sides = true;              % RECOMMENDATION (keeps the answer balanced)

    % --- Acceptance-test tolerance ------------------------------------------
    s.accept_tol_decimals = 2;             % RECOMMENDATION (match to 2 decimal places)

    % --- Keep spread strictly positive inside the optimiser -----------------
    s.enforce_positive_sigma = true;       % RECOMMENDATION (reparameterise / constrain)

    % --- Tail-quantile reporting (addendum B1) ------------------------------
    % report (#9) also prints two tail levels: the all-fire level, where this
    % fraction of items break, and the no-fire level, where this fraction
    % survive. Neyer usually uses 99.9% (some use 99.99% / 99.9999%), so this
    % is an adjustable dial, not a hard-wired number. brief App.B / addendum B1.
    s.tail_fraction = 0.999;               % PAPER (all-fire ~99.9% definition); 0.999 default RECOMMENDATION

    % --- Likelihood-ratio confidence level (addendum LR) --------------------
    % Confidence level used by lr_confidence for the two-sided (mu, sigma) and
    % one-sided (all-fire, no-fire) profile-likelihood bounds.
    s.confidence_level = 0.95;             % RECOMMENDATION (industry standard)

    % --- Reliability-at-confidence presets & sample-size planner (addendum RAC) ---
    % Preset reliability ladder offered by reliability_query, powers of ten up to
    % 1-in-a-million. Free-text percentage is always accepted too.
    s.reliability_presets = [0.99 0.999 0.9999 0.99999 0.999999]; % RECOMMENDATION
    % Floor on the recommended number of tests. Below ~20 the likelihood-ratio
    % confidence bounds are not dependable (large-sample approximation), results
    % must first overlap for any fit to exist (Silvapulle), and the estimates are
    % still settling. See spec 2.4.
    s.sample_floor       = 20;    % RECOMMENDATION (LR asymptotics dependable ~>=20)
    % Planner target: the conservative one-sided margin should be within this
    % fraction of the spread (sigma) -- the natural unit the Banerjee variances
    % are expressed in -- so the bound is meaningful (finite, and for survive
    % stays above zero). The target is a fraction of sigma, NOT of the level's
    % distance-from-centre (k*sigma): tying it to k*sigma would let the target
    % grow alongside the estimate and make the required number of tests SHRINK
    % as the reliability R gets more extreme, which is backwards. See
    % plan_samples.m (banerjee basis) for the matching derivation.
    s.plan_rel_precision = 0.5;   % RECOMMENDATION

    % --- Physical floor on the tested level (addendum MINLEVEL) --------------
    % Lowest stimulus the rig can actually apply. Default -Inf = no floor, so the
    % method stays byte-for-byte pure Neyer out of the box (Table 1 gate unchanged).
    % For a real drop test set this to your rig's minimum (e.g. 0 mm): when the
    % method's chosen level falls below it, the test is done AT the floor.
    s.min_level = 0;      % GAP APPLICATION: physical minimum gap
    s.max_level = 10;     % GAP APPLICATION: permitted study boundary

    % --- Display unit for heights (label only; no conversion) ----------------
    s.unit = 'mm';   % RECOMMENDATION ('mm'/'cm'/'m'/'km' or any short label)
end

function threshold = one_sided_profile_threshold(confidence)
%ONE_SIDED_PROFILE_THRESHOLD Monotonic likelihood threshold for a lower bound.
% At 50% confidence the cautious boundary is the best estimate. A requested
% confidence below 50% must not accidentally become a stronger claim, so it
% remains at that same estimate. Above 50%, caution increases continuously.
    if ~(isnumeric(confidence) && isscalar(confidence) && isreal(confidence) && ...
            isfinite(confidence) && confidence > 0 && confidence < 1)
        error('one_sided_profile_threshold:badConfidence', ...
            'Confidence must be one number between 0 and 1.');
    end
    signed_distance = shape_model(confidence, 'quantile');
    threshold = max(signed_distance, 0)^2;
end

function coverage = operating_gap_coverage(raw_boundary_mm, ...
        true_boundary_mm, outcome, reachable_model)
%OPERATING_GAP_COVERAGE Judge the final reachable instruction, not a hidden raw value.
    coverage = struct('safe_gap_mm', NaN, 'available', false, ...
        'conservative', false, 'status', struct());
    if ~(isfinite(raw_boundary_mm) && isfinite(true_boundary_mm))
        return;
    end
    [safe_gap_mm, status] = select_operating_gap(raw_boundary_mm, ...
        outcome, reachable_model);
    coverage.status = status;
    coverage.safe_gap_mm = safe_gap_mm;
    coverage.available = strcmp(status.code, 'ok');
    if ~coverage.available, return; end
    tolerance = reachable_model.comparison_tolerance_mm;
    if strcmp(char(string(outcome)), 'interaction')
        coverage.conservative = safe_gap_mm <= true_boundary_mm + tolerance;
    elseif strcmp(char(string(outcome)), 'no_interaction')
        coverage.conservative = safe_gap_mm >= true_boundary_mm - tolerance;
    else
        error('operating_gap_coverage:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end
end

function response = parse_physical_response(measurement_text, outcome)
%PARSE_PHYSICAL_RESPONSE Convert one measured gap and outcome to a response.
%   Exactly one finite, real, nonnegative gap measurement is required.

    if isstring(measurement_text) && isscalar(measurement_text)
        measurement_text = char(measurement_text);
    end
    if ~ischar(measurement_text)
        error('parse_physical_response:badMeasurements', ...
            'Enter one measured gap.');
    end
    tokens = strsplit(strtrim(strrep(measurement_text,',',' ')));
    if isempty(tokens) || (numel(tokens)==1 && isempty(tokens{1}))
        readings = [];
    else
        readings = cellfun(@str2double,tokens);
    end
    if ~(numel(readings)==1 && isfinite(readings) && ...
            isreal(readings) && readings >= 0)
        error('parse_physical_response:badMeasurements', ...
            'Enter exactly one finite, nonnegative measured gap.');
    end
    if ~(islogical(outcome) && isscalar(outcome))
        error('parse_physical_response:badOutcome', ...
            'Choose either Interaction or No interaction.');
    end
    response = struct('outcome',outcome,'measurements',readings);
end

function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS  Pure core of the settings popup: strings -> validated {params,num_parts,cfg}.
%   out = PARSE_RUN_INPUTS(answers), answers a 9-cell array of strings
%   {lo, hi, spread_guess, num_parts, min_level, max_level, unit,
%   usable_resolution, foil_thickness}. The older 7- and 8-cell layouts are
%   still accepted for compatibility. Foil thickness is construction
%   information only. The
%   usable resolution controls physical requests and the Stage-2 safety floor.
%   Returns
%   struct with .params, .num_parts, .cfg. Validates by reusing check_inputs so
%   the popup cannot accept anything the engine would reject. Blank min_level =
%   no floor (-Inf). Throws a named error on any bad field. [addendum POPUP]
    if ~(iscell(answers) && any(numel(answers) == [7 8 9]))
        error('parse_run_inputs:badShape', ...
              'Expected all physical test settings.');
    end
    lo = str2double(answers{1});
    hi = str2double(answers{2});
    sg = str2double(answers{3});
    num_parts = str2double(answers{4});
    ml_str = strtrim(answers{5});
    if isempty(ml_str)
        ml = -Inf;                        % blank = no floor
    else
        ml = str2double(ml_str);
    end
    if ~(isscalar(ml) && isreal(ml) && ~isnan(ml) && ml < Inf)
        error('parse_run_inputs:badMinLevel', ...
              'Minimum gap must be a number.');
    end
    params = struct('avg_low', lo, 'avg_high', hi, 'spread_guess', sg);
    try
        check_inputs(params, num_parts);  % keep one set of mathematical rules
    catch input_error
        throw_plain_input_error(input_error);
    end
    cfg = neyer_settings();
    cfg.min_level = ml;
    if numel(answers) == 9
        if ~isfinite(ml)
            error('parse_run_inputs:badMinLevel', ...
                'Enter the smallest physical gap permitted for this test.');
        end
        max_level = str2double(answers{6});
        if ~(isscalar(max_level) && isreal(max_level) && ...
                isfinite(max_level) && max_level > ml)
            error('parse_run_inputs:badMaxLevel', ...
                'Maximum permitted gap must be greater than the minimum gap.');
        end
        unit_index = 7;
        resolution_index = 8;
        foil_index = 9;
    else
        max_level = cfg.max_level;
        unit_index = 6;
        resolution_index = 7;
        foil_index = 8;
    end
    cfg.max_level = max_level;
    if ~isempty(strtrim(answers{unit_index}))
        cfg.unit = strtrim(answers{unit_index});
    end
    usable_resolution = str2double(answers{resolution_index});
    if ~(isscalar(usable_resolution) && isreal(usable_resolution) && ...
            isfinite(usable_resolution) && usable_resolution > 0)
        error('parse_run_inputs:badLevelIncrement', ...
            ['Enter the positive usable gap step for this study ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    hundredths = usable_resolution * 100;
    if abs(hundredths-round(hundredths)) > 1e-10
        error('parse_run_inputs:badUsableResolution', ...
            ['The usable gap step must work with two-decimal build requests. ' ...
             'Enter 0.01, 0.02, 0.05, 0.10 mm, or another whole hundredth. ' ...
             'Do not enter the 0.015 mm foil thickness here.']);
    end
    cfg.usable_resolution = usable_resolution;
    cfg.level_increment = usable_resolution; % compatibility with the Neyer core

    if numel(answers) >= foil_index
        foil_thickness = str2double(answers{foil_index});
        if ~(isscalar(foil_thickness) && isreal(foil_thickness) && ...
                isfinite(foil_thickness) && foil_thickness > 0)
            error('parse_run_inputs:badFoilThickness', ...
                'Foil thickness must be a positive number, for example 0.015 mm.');
        end
        cfg.foil_thickness = foil_thickness;
    end
    if numel(answers) == 9
        regular_setup = struct('mode', 'regular', ...
            'increment_mm', usable_resolution);
        cfg.reachable_model = reachable_gap_model(regular_setup, ml, max_level);
    end
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end

function throw_plain_input_error(input_error)
    switch input_error.identifier
        case 'check_inputs:notFiniteScalar'
            error('parse_run_inputs:badStartingNumber', ...
                ['Enter ordinary numbers for the low guess, high guess, ' ...
                 'and overall variation guess.']);
        case 'check_inputs:badBounds'
            error('parse_run_inputs:badStartingGuesses', ...
                'High guess must be greater than the low guess.');
        case 'check_inputs:badSigma'
            error('parse_run_inputs:badOverallVariation', ...
                'The overall variation guess must be greater than zero.');
        case 'check_inputs:badBudget'
            error('parse_run_inputs:badTestMaximum', ...
                'Maximum allowed number of destructive tests must be a whole number.');
        case 'check_inputs:budgetTooSmall'
            error('parse_run_inputs:testMaximumTooSmall', ...
                'Allow at least 3 destructive tests.');
        otherwise
            rethrow(input_error);
    end
end

function [x_next, det_max] = pick_next_level(levels, mu, sigma, cfg, side_pref)
%PICK_NEXT_LEVEL  Worker #3 â€” the D-optimal picker (the method's heart).
%
%   x = PICK_NEXT_LEVEL(levels, mu, sigma) returns the single next test level
%   that sharpens the current estimate the most: the level that maximises the
%   determinant of the Fisher information matrix.  [brief sec.4 worker #3;
%   App.A "D-optimal objective"]
%
%       det(I) = I00*I11 - I01^2
%
%   where, summed over the already-tested levels plus the candidate level,
%   using the Eq.3 building blocks J_j(z) = phi(z)^2 * z^j / (Phi*Q*sigma^2):
%
%       I00 = sum J0 ,  I01 = sum J1 ,  I11 = sum J2 .
%
%   In words: maximise (knowledge of average) x (knowledge of spread) minus
%   (entanglement)^2. The maximiser emerges near +/-1.138 spreads from centre
%   on its own -- it is found, not hard-coded.
%
%   Inputs
%     levels   levels already tested (column or row). Their information,
%              evaluated at the current estimate, forms the running matrix.
%     mu, sigma  the current best estimate (centre and spread).
%     cfg      settings struct (optional; defaults to settings()). Uses
%              cfg.search_window_sigmas (the fence) and cfg.grid_points.
%     side_pref  optional -1 / 0 / +1. 0 (default) = search both sides and
%              take the global best. +1 restricts to x >= mu, -1 to x <= mu.
%              choose_stage (#6) can use this to enforce the alternate-sides
%              balancing policy; the core stays a pure determinant search.
%
%   Outputs
%     x_next   the chosen next level.
%     det_max  det(I) achieved there (diagnostic).
%
%   Guardrail (numerical hazard #1, brief sec.8): the candidate search is
%   fenced to +/- search_window_sigmas spreads, and the information term is
%   guarded so far-out levels (where Phi*Q underflows) contribute ~0 instead
%   of producing NaN/Inf. All shape quantities come from worker #1.

    if nargin < 4 || isempty(cfg),       cfg = neyer_settings();   end
    if nargin < 5 || isempty(side_pref), side_pref = 0;      end

    levels = levels(:);

    % Running information from the already-tested levels at the current estimate.
    [I00e, I01e, I11e] = info_sum(levels, mu, sigma);

    % Fenced candidate grid around the current centre.
    W  = cfg.search_window_sigmas;
    n  = cfg.grid_points;
    xs = linspace(mu - W*sigma, mu + W*sigma, n)';

    if side_pref > 0
        xs = xs(xs >= mu);
    elseif side_pref < 0
        xs = xs(xs <= mu);
    end

    % Information each candidate would add (guarded against tail blow-up).
    [j0, j1, j2] = info_terms(xs, mu, sigma);

    I00 = I00e + j0;
    I01 = I01e + j1;
    I11 = I11e + j2;

    det = I00 .* I11 - I01.^2;

    [det_max, k] = max(det);
    x_next = xs(k);
end

% -------------------------------------------------------------------------
function [I00, I01, I11] = info_sum(levels, mu, sigma)
%INFO_SUM  Sum the Eq.4 information matrix over a set of levels.
    if isempty(levels)
        I00 = 0; I01 = 0; I11 = 0;
        return;
    end
    [j0, j1, j2] = info_terms(levels, mu, sigma);   % shared helper (Eq.3)
    I00 = sum(j0);
    I01 = sum(j1);
    I11 = sum(j2);
end

function opts = pl_opts()
%PL_OPTS  Shared optimiser options for profile-likelihood inner maximisation.
%   Base optimset only (no toolbox). Used by lr_confidence and the
%   reliability-at-confidence units (Mode A/B, planner).  [addendum LR / RAC]
    opts = optimset('TolX', 1e-8, 'TolFun', 1e-10, 'MaxFunEvals', 1e4, 'MaxIter', 1e4);
end

function res = plan_prep(params, R, C, cfg)
%PLAN_PREP  Pre-lab planner: how many parts to prepare + where to start.
%   res = PLAN_PREP(params, R, C) prints a plain-language prep summary and returns
%   the numbers (see plan_prep_numbers). C defaults to settings().confidence_level.
%   Run this at home BEFORE printing parts. It gives the parts count and the first
%   height only -- the tool picks every height after that. [addendum PREP]
    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if nargin < 3 || isempty(C), C = cfg.confidence_level; end
    res = plan_prep_numbers(params, R, C, cfg);
    fprintf('\n--- Before you start: parts & first height ---\n');
    fprintf('Prepare about %d parts.\n', res.n_parts);
    fprintf('  (Never fewer than %d - %s)\n', res.n_floor, res.floor_reason);
    fprintf('Start your first drop at %.4g mm  (the midpoint of your guess).\n', res.start_height);
    fprintf('Target: %.4g%% of parts, %.4g%% confidence.\n', 100*res.R, 100*res.C);
    fprintf('For contrast, counting failures directly would need about %d parts.\n', res.n_bogey);
    fprintf('This is the count and starting height only - the tool picks every height after that.\n\n');
end

function msg = plan_prep_message(pr, u)
%PLAN_PREP_MESSAGE  Plain-language popup text for the pre-test planner.
%   msg = PLAN_PREP_MESSAGE(pr, u) turns a plan_prep_numbers result `pr` into a
%   friendly message: how many test specimens to prepare and the first gap, with
%   the brute-force contrast as reassurance. Pure. [compiled-app]
    if nargin < 2 || isempty(u), u = 'mm'; end
    if isfield(pr, 'main_articles')
        if isfield(pr, 'reliability_instruction_supported') && ...
                ~pr.reliability_instruction_supported
            if strcmp(pr.reliability_instruction_status, ...
                    'exploratory_confidence')
                reliability_note = [ ...
                    'Reliability instruction: exploratory only\n' ...
                    'At 50%% confidence or less, the app will not issue a ' ...
                    'safety-supported operating setting.\n'];
            else
                reliability_note = [ ...
                    'Reliability instruction: outside recorded validation\n' ...
                    'Above 95%% confidence, the app will calculate an estimate ' ...
                    'but will not issue a safety-supported operating setting.\n'];
            end
        else
            reliability_note = sprintf([ ...
                'Reliability safety rule: %d independent articles\n' ...
                'The smaller main study may estimate the middle gap and overall variation.\n' ...
                'A supported reliability result is withheld until this safety total is reached.\n'], ...
                pr.reliability_validation_floor_articles);
        end
        msg = sprintf([ ...
            'Pre-test estimate\n\n' ...
            'Main study: %d articles\n' ...
            'This is the quantity expected for the starting assumptions.\n\n' ...
            'Reserve group 1: %d articles\n' ...
            'Use only after the main-study checkpoint asks for them.\n\n' ...
            'Reserve group 2: %d articles\n' ...
            'Use only after the next declared checkpoint asks for them.\n\n' ...
            'Total to prepare: %d articles\n\n' ...
            '%s' ...
            'Reserve articles are not used automatically. You decide at each checkpoint.\n\n' ...
            'First requested gap: %.2f %s\n' ...
            'This is the closest reachable gap to the starting middle estimate.\n\n' ...
            'Important: this is a planning estimate, not a reliability guarantee.'], ...
            pr.main_articles, pr.reserve_1_articles, pr.reserve_2_articles, ...
            pr.total_articles, reliability_note, pr.starting_gap_mm, u);
        return;
    end
    msg = sprintf([ ...
        'Prepare %d test specimens.\n\n' ...
        'Build the first gap at %.2f %s (the middle of your guess).\n\n' ...
        'This targets %.4g%% reliability at %.4g%% confidence.\n' ...
        'A direct counting approach would need about %d specimens for the same goal, ' ...
        'so the method uses the available tests efficiently.'], ...
        pr.n_parts, pr.start_height, u, 100*pr.R, 100*pr.C, pr.n_bogey);
end

function res = plan_prep_numbers(params, R, C, cfg)
%PLAN_PREP_NUMBERS  Pure core of the pre-lab planner: parts count + first height.
%   res = PLAN_PREP_NUMBERS(params, R, C, cfg) returns how many parts to prepare
%   for reliability R at confidence C, and the height of the first drop -- with NO
%   printing. Reuses plan_samples (the verified engine) so the sample-size math has
%   a single home. The V1.10 planner call is PLAN_PREP_NUMBERS(clean, model),
%   where clean is validated planner input and model is a reachable-gap model.
%   The older four-argument call remains available only for compatibility with
%   recorded compatibility tests while the user interface uses the guided planner.
    if nargin >= 2 && isstruct(params) && isfield(params, 'mode') && ...
            isstruct(R) && isfield(R, 'gaps_mm')
        res = estimate_study_plan(params, R);
        return;
    end
    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if ~(isfield(params, 'avg_low') && isfield(params, 'avg_high'))
        error('plan_prep_numbers:missingField', 'params needs avg_low and avg_high.');
    end
    lo = params.avg_low; hi = params.avg_high;
    if ~(isscalar(lo) && isscalar(hi) && isreal(lo) && isreal(hi) ...
         && isfinite(lo) && isfinite(hi) && lo < hi)
        error('plan_prep_numbers:badBounds', ...
              'need finite avg_low (%.4g) < avg_high (%.4g).', lo, hi);
    end
    p = plan_samples('break', R, C, cfg, struct('sigma', 1));   % sigma cancels
    res = struct('n_parts', p.n_recommended, ...
                 'start_height', (lo + hi) / 2, ...
                 'R', R, 'C', C, ...
                 'n_floor', p.n_floor, 'n_bogey', p.n_bogey, ...
                 'floor_reason', p.floor_reason);
end

function res = plan_samples(tail, R, C, cfg, basis)
%PLAN_SAMPLES  Estimate how many parts to test for a reliability at a confidence.
%   res = PLAN_SAMPLES(tail, R, C, cfg, basis)
%     tail  : 'break' or 'survive' (affects only wording; the count is symmetric)
%     R, C  : reliability and confidence, each in (0,1)
%     basis : struct('sigma',s,'accuracy_mm',a)  -> absolute gap accuracy
%             struct('sigma', s)                 -> legacy fraction-of-sigma route
%             struct('n',N,'level',L,'se',SE)    -> refined, exact 1/sqrt(N) scaling
%   Returns struct:
%     .n_recommended  max(floor, raw), rounded up
%     .n_needed_raw   the model-based estimate before the floor
%     .n_floor        cfg.sample_floor
%     .floor_reason   plain-language "why the floor" text (source-tagged reasons)
%     .n_bogey        brute-force zero-failure demonstration count (contrast only)
%     .basis          'banerjee' (up-front) or 'scaled' (refined)
%     .caveat         "estimate, not a guarantee" note
%   Model-based only; the bogey count is shown for contrast, never used to test.
%   [PAPER Banerjee variances + 1/sqrt(N) scaling; PUBLISHED bogey formula;
%    RECOMMENDATION conservative covariance + precision target (settings)]
    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    tail = lower(tail);
    if ~any(strcmp(tail, {'break','survive'}))
        error('plan_samples:badTail', 'tail must be ''break'' or ''survive''.');
    end
    if ~(isscalar(R) && isreal(R) && R > 0 && R < 1)
        error('plan_samples:badR', 'reliability R must be a single number in (0,1).');
    end
    if ~(isscalar(C) && isreal(C) && C > 0 && C < 1)
        error('plan_samples:badC', 'confidence C must be a single number in (0,1).');
    end

    k  = shape_model(R, 'quantile');
    zc = shape_model(C, 'quantile');
    nfloor = cfg.sample_floor;
    n_bogey = ceil(log(1 - C) / log(R));

    reason = sprintf(['Floored at %d tests: the likelihood-ratio confidence bounds are a ' ...
        'large-sample approximation that published sensitivity-testing simulation finds ' ...
        'dependable only around 20 tests; results must first overlap for any fit to exist ' ...
        '(Silvapulle); and the average/spread estimates keep settling until ~18-20 tests.'], nfloor);
    caveat = 'This is an estimate; the true number depends on the real spread, known only after testing.';

    if isfield(basis, 'sigma') && isfield(basis, 'accuracy_mm')
        sg = basis.sigma;
        accuracy_mm = basis.accuracy_mm;
        if ~(isscalar(sg) && isreal(sg) && isfinite(sg) && sg > 0)
            error('plan_samples:badSigma', 'basis.sigma must be a positive number.');
        end
        if ~(isscalar(accuracy_mm) && isreal(accuracy_mm) && ...
                isfinite(accuracy_mm) && accuracy_mm > 0)
            error('plan_samples:badAccuracy', ...
                'basis.accuracy_mm must be a positive number.');
        end
        % Published large-sample starting relationships:
        %   sd(mu)    ~= sigma / sqrt(0.392*N)
        %   sd(sigma) ~= sigma / sqrt(0.507*(N-15))
        % The sum is the conservative no-covariance-information limit for
        % q = mu +/- k*sigma. It is a planning estimate until simulation.
        protection_z = max(zc, 0);
        n_raw = required_count_for_accuracy(sg, abs(k), protection_z, ...
            accuracy_mm, nfloor);
        target = accuracy_mm;
        basisname = 'absolute_gap_accuracy_n_minus_15';
    elseif isfield(basis, 'sigma')
        sg = basis.sigma;
        if ~(isscalar(sg) && isreal(sg) && sg > 0)
            error('plan_samples:badSigma', 'basis.sigma must be a positive number.');
        end
        % Banerjee asymptotic variances (App.B), conservative covariance term:
        %   var_q(N) = sg^2/N * ( 1/0.392 + k^2/0.507 + 2|k|*sqrt(1/(0.392*0.507)) )
        % Target is a fraction of sigma (the natural unit these variances are
        % expressed in): using the level's full distance-from-centre (k*sigma)
        % as the target instead would let the target grow alongside the
        % numerator and mask the extra samples that extreme R genuinely needs.
        a = 1/0.392 + k^2/0.507 + 2*abs(k)*sqrt(1/(0.392*0.507));
        target   = cfg.plan_rel_precision * sg;      % distance-from-centre scale
        n_raw    = ceil( (zc*sqrt(a)*sg / target)^2 );
        basisname = 'banerjee';
    elseif all(isfield(basis, {'n','level','se'}))
        margin_now = zc * basis.se;
        target     = cfg.plan_rel_precision * max(abs(basis.level), eps);
        n_raw      = ceil( basis.n * (margin_now / target)^2 );
        basisname  = 'scaled';
    else
        error('plan_samples:badBasis', ...
              'basis must have field ''sigma'' (up-front) or ''n''/''level''/''se'' (refined).');
    end

    res = struct('n_recommended', max(nfloor, n_raw), 'n_needed_raw', n_raw, ...
                 'n_floor', nfloor, 'floor_reason', reason, 'n_bogey', n_bogey, ...
                 'basis', basisname, 'caveat', caveat);
end

function required_count = required_count_for_accuracy(sigma, absolute_k, ...
        protection_z, accuracy_mm, sample_floor)
    first_count = max(sample_floor, 16);
    if protection_z == 0
        required_count = first_count;
        return;
    end
    margin = @(count) protection_z * sigma * ( ...
        sqrt(1 ./ (0.392 .* count)) + ...
        absolute_k ./ sqrt(0.507 .* (count - 15)));
    if margin(first_count) <= accuracy_mm
        required_count = first_count;
        return;
    end
    lower_count = first_count;
    upper_count = first_count;
    while margin(upper_count) > accuracy_mm
        lower_count = upper_count;
        upper_count = upper_count * 2;
        if upper_count > 1e8
            error('plan_samples:quantityTooLarge', ...
                ['The requested accuracy would require more than 100 million ' ...
                 'articles under the planning approximation.']);
        end
    end
    while upper_count - lower_count > 1
        middle_count = floor((lower_count + upper_count) / 2);
        if margin(middle_count) <= accuracy_mm
            upper_count = middle_count;
        else
            lower_count = middle_count;
        end
    end
    required_count = upper_count;
end

function h = plot_result(result, cfg, savepath)
%PLOT_RESULT  Draw the interaction-probability and transition-gap views.
%
%   h = PLOT_RESULT(result, cfg) draws the bell curve implied by the estimate
%   (result.mu, result.sigma), shades +/-1 spread, marks the all-fire and
%   no-fire levels and their confidence bounds, and returns the figure handle.
%   Opens a new figure each call (repeated calls do not overlay).
%   h = PLOT_RESULT(result, cfg, savepath) also writes a PNG to savepath.
%   Uses only base plotting (works in MATLAB and Octave).  [addendum LR]
    if nargin < 2 || isempty(cfg), cfg = neyer_settings(); end   % cfg reserved for future styling; not used yet
    if ~result.has_overlap || isnan(result.mu)
        error('plot_result:noResult', 'No result to plot (results have not overlapped).');
    end

    h  = figure('Position',[100 100 1000 850]);
    layout=tiledlayout(h,2,1,'TileSpacing','compact','Padding','compact');
    probabilityAxes=nexttile(layout,1);
    draw_interaction_curve(probabilityAxes,result,cfg);
    distributionAxes=nexttile(layout,2);
    draw_distribution(distributionAxes,result,cfg);

    if nargin >= 3 && ~isempty(savepath)
        print(h, savepath, '-dpng');
    end
end

function selected_plan = pretest_planner_ui()
%PRETEST_PLANNER_UI Guided preparation worksheet for a Neyer gap study.
% Calculations live in tested pure functions. This window only collects
% answers, explains their meaning, and presents the review.

    if ~(isdeployed || usejava('desktop'))
        error('pretest_planner_ui:noDisplay', ...
            'The Pre-Test Planner needs the MATLAB desktop.');
    end

    color.graphite = [33 49 58] / 255;
    color.blue = [35 108 142] / 255;
    color.teal = [47 125 109] / 255;
    color.amber = [181 117 25] / 255;
    color.rust = [164 61 53] / 255;
    color.white = [247 249 250] / 255;
    color.soft = [232 238 241] / 255;

    state.current_plan = [];
    state.selected_plan = [];

    figure_handle = uifigure('Name', 'Neyer Pre-Test Planner', ...
        'Position', [90 45 1180 790], 'Color', color.white);
    page = uigridlayout(figure_handle, [4 2]);
    page.RowHeight = {38, 58, '1x', 58};
    page.ColumnWidth = {620, '1x'};
    page.Padding = [26 20 26 20];
    page.RowSpacing = 12;
    page.ColumnSpacing = 22;

    progress = uilabel(page, 'Text', ...
        'Plan  >  Prepare  >  Test  >  Check  >  Finish', ...
        'FontSize', 13, 'FontWeight', 'bold', ...
        'FontColor', color.blue, 'HorizontalAlignment', 'left');
    progress.Layout.Row = 1;
    progress.Layout.Column = [1 2];

    title_label = uilabel(page, 'Text', ...
        'Plan the articles and gaps before the laboratory', ...
        'FontSize', 20, 'FontWeight', 'bold', 'FontColor', color.graphite);
    title_label.Layout.Row = 2;
    title_label.Layout.Column = [1 2];

    input_panel = uipanel(page, 'Title', 'Your planning answers', ...
        'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', color.graphite, ...
        'BackgroundColor', color.white, 'Scrollable', 'on');
    input_panel.Layout.Row = 3;
    input_panel.Layout.Column = 1;
    inputs = uigridlayout(input_panel, [38 2]);
    inputs.RowHeight = repmat({'fit'}, 1, 38);
    inputs.ColumnWidth = {'1x', 220};
    inputs.Padding = [18 14 18 18];
    inputs.RowSpacing = 7;
    inputs.ColumnSpacing = 14;

    row = 1;
    add_section('How would you like to plan?');
    mode = add_dropdown('Planning question', ...
        {'Requirements first', 'Articles available first'}, ...
        {'requirements_first', 'available_articles_first'}, ...
        'Choose requirements first to calculate a preparation quantity.');
    mode.ValueChangedFcn = @(~, ~) update_mode_visibility();

    [available_count, available_label, available_help, ...
        available_question_row, available_help_row] = add_number( ...
        'Maximum articles available', 100, ...
        'How many separate destructive articles can be prepared.');
    [fixed_choice, fixed_label, fixed_help, ...
        fixed_question_row, fixed_help_row] = add_dropdown( ...
        'Keep this requirement fixed', ...
        {'Reliability', 'Confidence'}, {'reliability', 'confidence'}, ...
        'The planner estimates the other value; it never invents both.');

    add_section('What result do you need?');
    outcome = add_dropdown('Required physical result', ...
        {'Choose...', 'Interaction', 'No interaction'}, ...
        {'', 'interaction', 'no_interaction'}, ...
        'The physical result you need the final operating gap to produce.');
    reliability = add_number('Reliability (%)', 99, ...
        'The minimum fraction of similar articles expected to give that result.');
    confidence = add_number('Confidence (%)', 95, ...
        'How strongly the completed evidence must support the reliability.');
    accuracy = add_number('Required gap accuracy (+/- mm)', 0.10, ...
        'How close the calculated gap needs to be in millimetres.');

    add_section('What do you know?');
    interaction_gap = add_number('Almost-always Interaction gap (mm)', 1.00, ...
        'A smaller gap where Interaction is expected almost every time.');
    no_interaction_gap = add_number('Almost-always No-interaction gap (mm)', 10.00, ...
        'A larger gap where No interaction is expected almost every time.');
    previous_information = add_dropdown('Earlier information', ...
        {'No, this is my first study', 'Results change suddenly', ...
         'Results change gradually'}, ...
        {'first_study', 'sudden', 'gradual'}, ...
        'First-study endpoints are treated as at least 95%, not as certainty.');

    add_section('What can you build?');
    minimum_gap = add_number('Minimum permitted gap (mm)', 0.00, ...
        'The smallest permitted physical gap, including no spacers.');
    maximum_gap = add_number('Maximum permitted gap (mm)', 10.00, ...
        'The largest useful gap; larger obvious No-interaction gaps add no value.');
    physical_mode = add_dropdown('Physical setup method', ...
        {'Regular increments', 'Measured printed-spacer combinations', ...
         'Confirmed reachable-gap list'}, ...
        {'regular', 'combinations', 'list'}, ...
        ['Foil recipes are unavailable until stack measurements and a ' ...
         'practical layer limit are confirmed.']);
    physical_mode.ValueChangedFcn = @(~, ~) update_physical_visibility();
    [regular_increment, regular_label, regular_help, ...
        regular_question_row, regular_help_row] = add_number( ...
        'Regular increment (mm)', 0.10, ...
        'Use this only when every multiple can genuinely be built.');
    [confirmed_list, list_label, list_help, ...
        list_question_row, list_help_row] = add_text( ...
        'Confirmed gaps (mm)', '0, 0.5, 1, 2, 10', ...
        'Enter only measured buildable gaps, separated by commas.');

    component_label = uilabel(inputs, 'Text', ...
        'Measured printed spacers and maximum count', 'FontSize', 14, ...
        'FontWeight', 'bold', 'FontColor', color.graphite);
    component_label.Layout.Row = row;
    component_label.Layout.Column = [1 2];
    component_label_row = row;
    row = row + 1;
    component_table = uitable(inputs, 'ColumnName', ...
        {'Component', 'Measured mm', 'Maximum count'}, ...
        'ColumnEditable', [true true true], ...
        'ColumnFormat', {'char', 'numeric', 'numeric'}, ...
        'Data', {'Printed spacer 1', NaN, 0; 'Printed spacer 2', NaN, 0; ...
                 'Printed spacer 3', NaN, 0; 'Printed spacer 4', NaN, 0}, ...
        'RowName', [], 'FontSize', 12);
    component_table.Layout.Row = row;
    component_table.Layout.Column = [1 2];
    inputs.RowHeight{row} = 116;
    component_table_row = row;

    review_panel = uipanel(page, 'Title', 'Plan review', ...
        'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', color.graphite, ...
        'BackgroundColor', [1 1 1]);
    review_panel.Layout.Row = 3;
    review_panel.Layout.Column = 2;
    review_grid = uigridlayout(review_panel, [3 1]);
    review_grid.RowHeight = {42, '1x', 34};
    review_grid.Padding = [18 14 18 16];
    review_heading = uilabel(review_grid, 'Text', ...
        'Complete the questions, then select Review plan.', ...
        'FontSize', 14, 'FontWeight', 'bold', 'FontColor', color.blue, ...
        'WordWrap', 'on');
    review_text = uitextarea(review_grid, 'Editable', 'off', ...
        'FontSize', 13, 'Value', { ...
        'Nothing has been calculated yet.', ...
        '', ...
        'Every quantity will be shown as an estimate with its assumptions.'});
    review_status = uilabel(review_grid, 'Text', 'Not reviewed', ...
        'FontSize', 12, 'FontColor', color.amber);

    buttons = uigridlayout(page, [1 4]);
    buttons.Layout.Row = 4;
    buttons.Layout.Column = [1 2];
    buttons.ColumnWidth = {'1x', '1x', 180, 130};
    buttons.Padding = [0 5 0 0];
    buttons.ColumnSpacing = 12;
    review_button = uibutton(buttons, 'Text', 'Review plan', ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', color.blue, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~, ~) review_plan());
    save_button = uibutton(buttons, 'Text', 'Save plan', ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', color.teal, 'FontColor', [1 1 1], ...
        'Enable', 'off', 'ButtonPushedFcn', @(~, ~) save_plan());
    uilabel(buttons, 'Text', '');
    uibutton(buttons, 'Text', 'Close', 'FontSize', 15, ...
        'ButtonPushedFcn', @(~, ~) close_planner());

    figure_handle.CloseRequestFcn = @(~, ~) close_planner();
    update_mode_visibility();
    update_physical_visibility();
    uiwait(figure_handle);
    selected_plan = state.selected_plan;
    if isvalid(figure_handle), delete(figure_handle); end

    function add_section(text_value)
        label = uilabel(inputs, 'Text', text_value, 'FontSize', 16, ...
            'FontWeight', 'bold', 'FontColor', color.blue);
        label.Layout.Row = row;
        label.Layout.Column = [1 2];
        row = row + 1;
    end

    function [control, question_label, help_label, question_row, help_row] = add_number( ...
            question, default_value, help_text)
        question_row = row;
        question_label = uilabel(inputs, 'Text', question, 'FontSize', 14, ...
            'FontWeight', 'bold', 'FontColor', color.graphite, 'WordWrap', 'on');
        question_label.Layout.Row = row;
        question_label.Layout.Column = 1;
        control = uieditfield(inputs, 'numeric', 'Value', default_value, ...
            'FontSize', 14);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        row = row + 1;
        help_row = row;
        help_label = uilabel(inputs, 'Text', help_text, 'FontSize', 12, ...
            'FontColor', [0.32 0.39 0.43], 'WordWrap', 'on');
        help_label.Layout.Row = row;
        help_label.Layout.Column = [1 2];
        row = row + 1;
    end

    function [control, question_label, help_label, question_row, help_row] = add_text( ...
            question, default_value, help_text)
        question_row = row;
        question_label = uilabel(inputs, 'Text', question, 'FontSize', 14, ...
            'FontWeight', 'bold', 'FontColor', color.graphite, 'WordWrap', 'on');
        question_label.Layout.Row = row;
        question_label.Layout.Column = 1;
        control = uieditfield(inputs, 'text', 'Value', default_value, ...
            'FontSize', 14);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        row = row + 1;
        help_row = row;
        help_label = uilabel(inputs, 'Text', help_text, 'FontSize', 12, ...
            'FontColor', [0.32 0.39 0.43], 'WordWrap', 'on');
        help_label.Layout.Row = row;
        help_label.Layout.Column = [1 2];
        row = row + 1;
    end

    function [control, question_label, help_label, question_row, help_row] = add_dropdown( ...
            question, item_names, item_data, help_text)
        question_row = row;
        question_label = uilabel(inputs, 'Text', question, 'FontSize', 14, ...
            'FontWeight', 'bold', 'FontColor', color.graphite, 'WordWrap', 'on');
        question_label.Layout.Row = row;
        question_label.Layout.Column = 1;
        control = uidropdown(inputs, 'Items', item_names, ...
            'ItemsData', item_data, 'FontSize', 14);
        control.Layout.Row = row;
        control.Layout.Column = 2;
        row = row + 1;
        help_row = row;
        help_label = uilabel(inputs, 'Text', help_text, 'FontSize', 12, ...
            'FontColor', [0.32 0.39 0.43], 'WordWrap', 'on');
        help_label.Layout.Row = row;
        help_label.Layout.Column = [1 2];
        row = row + 1;
    end

    function update_mode_visibility()
        show_available = strcmp(mode.Value, 'available_articles_first');
        available_count.Visible = matlab.lang.OnOffSwitchState(show_available);
        available_label.Visible = matlab.lang.OnOffSwitchState(show_available);
        available_help.Visible = matlab.lang.OnOffSwitchState(show_available);
        fixed_choice.Visible = matlab.lang.OnOffSwitchState(show_available);
        fixed_label.Visible = matlab.lang.OnOffSwitchState(show_available);
        fixed_help.Visible = matlab.lang.OnOffSwitchState(show_available);
    end

    function update_physical_visibility()
        regular_increment.Visible = matlab.lang.OnOffSwitchState( ...
            strcmp(physical_mode.Value, 'regular'));
        regular_label.Visible = regular_increment.Visible;
        regular_help.Visible = regular_increment.Visible;
        confirmed_list.Visible = matlab.lang.OnOffSwitchState( ...
            strcmp(physical_mode.Value, 'list'));
        list_label.Visible = confirmed_list.Visible;
        list_help.Visible = confirmed_list.Visible;
        show_components = strcmp(physical_mode.Value, 'combinations');
        component_label.Visible = matlab.lang.OnOffSwitchState(show_components);
        component_table.Visible = matlab.lang.OnOffSwitchState(show_components);
    end

    function review_plan()
        try
            physical_setup = collect_physical_setup();
            raw = struct('mode', mode.Value, 'outcome', outcome.Value, ...
                'reliability', reliability.Value, 'confidence', confidence.Value, ...
                'accuracy_mm', accuracy.Value, ...
                'interaction_gap_mm', interaction_gap.Value, ...
                'no_interaction_gap_mm', no_interaction_gap.Value, ...
                'minimum_gap_mm', minimum_gap.Value, ...
                'maximum_gap_mm', maximum_gap.Value, ...
                'previous_information', previous_information.Value, ...
                'available_articles', available_count.Value, ...
                'physical_setup', physical_setup);
            [clean, input_messages] = validate_plan_inputs(raw);
            reachable = reachable_gap_model(physical_setup, ...
                clean.minimum_gap_mm, clean.maximum_gap_mm);

            if strcmp(clean.mode, 'requirements_first')
                plan = estimate_study_plan(clean, reachable);
                state.current_plan = plan;
                lines = plan_review_lines(plan, input_messages);
            else
                estimate = estimate_supported_targets(clean, reachable, ...
                    fixed_choice.Value);
                [plan, lines] = available_review(clean, reachable, estimate, ...
                    input_messages);
                state.current_plan = plan;
            end
            review_text.Value = cellstr(lines);
            if isempty(state.current_plan)
                save_button.Enable = 'off';
                review_status.Text = 'No saveable plan yet';
                review_status.FontColor = color.amber;
            elseif state.current_plan.feasible
                save_button.Enable = 'on';
                review_status.Text = 'Planning estimate ready for review';
                review_status.FontColor = color.teal;
            else
                save_button.Enable = 'on';
                review_status.Text = 'Review the cautions before saving';
                review_status.FontColor = color.amber;
            end
            review_heading.Text = 'What the current answers mean';
        catch calculation_error
            state.current_plan = [];
            save_button.Enable = 'off';
            review_status.Text = 'Please correct the highlighted planning issue';
            review_status.FontColor = color.rust;
            uialert(figure_handle, calculation_error.message, ...
                'Please check this answer', 'Icon', 'warning');
        end
    end

    function setup = collect_physical_setup()
        switch physical_mode.Value
            case 'regular'
                setup = struct('mode', 'regular', ...
                    'increment_mm', regular_increment.Value);
            case 'list'
                pieces = regexp(strtrim(confirmed_list.Value), ...
                    '[,;\s]+', 'split');
                pieces = pieces(~cellfun('isempty', pieces));
                gaps = cellfun(@str2double, pieces);
                setup = struct('mode', 'list', 'gaps_mm', gaps);
            otherwise
                data = component_table.Data;
                keep = false(size(data, 1), 1);
                for data_row = 1:size(data, 1)
                    keep(data_row) = isnumeric(data{data_row, 2}) && ...
                        isfinite(data{data_row, 2}) && data{data_row, 2} > 0 && ...
                        isnumeric(data{data_row, 3}) && ...
                        isfinite(data{data_row, 3}) && data{data_row, 3} >= 0;
                end
                data = data(keep, :);
                if isempty(data)
                    error('pretest_planner_ui:noComponents', ...
                        ['Enter at least one measured printed-spacer thickness ' ...
                         'and its maximum count.']);
                end
                setup = validate_planner_components(data(:,1)', ...
                    cell2mat(data(:,2))',cell2mat(data(:,3))');
        end
    end

    function lines = plan_review_lines(plan, input_messages)
        if plan.reliability_instruction_supported
            reliability_lines = [ ...
                "RELIABILITY SAFETY RULE"; ...
                sprintf([ ...
                    '%d independent articles before a supported reliability result.'], ...
                    plan.reliability_validation_floor_articles); ...
                "The main study can still estimate the middle gap and overall variation."];
        elseif strcmp(plan.reliability_instruction_status, ...
                'exploratory_confidence')
            reliability_lines = [ ...
                "EXPLORATORY CONFIDENCE"; ...
                "At 50% confidence or less, no safety-supported operating setting is issued."];
        else
            reliability_lines = [ ...
                "ABOVE RECORDED VALIDATION"; ...
                "Above 95% confidence, an estimate may be calculated but no safety-supported operating setting is issued."];
        end
        lines = [ ...
            "MAIN STUDY"; ...
            sprintf('%d separate articles', plan.main_articles); ...
            "Expected starting conditions."; ""; ...
            "RESERVE GROUP 1"; ...
            sprintf('%d articles - use only if the main checkpoint asks.', ...
                plan.reserve_1_articles); ""; ...
            "RESERVE GROUP 2"; ...
            sprintf('%d articles - use only if the next checkpoint asks.', ...
                plan.reserve_2_articles); ""; ...
            "TOTAL TO PREPARE"; ...
            sprintf('%d articles', plan.total_articles); ""; ...
            reliability_lines; ...
            "Reserve articles are not used automatically; you decide at each checkpoint."; ""; ...
            "FIRST REQUESTED GAP"; ...
            sprintf('%.2f mm', plan.starting_gap_mm); ""; ...
            "WHAT THESE ANSWERS ASSUME"; ...
            input_messages(:); plan.assumptions(:); ""; ...
            "WHAT TO REVIEW"; plan.suggestions(:); ""; ...
            "This is a pre-test estimate, not a reliability guarantee."];
    end

    function [plan, lines] = available_review(clean, reachable, estimate, input_messages)
        if isnan(estimate.best_reliability) || isnan(estimate.best_confidence)
            plan = [];
            lines = ["CURRENT ARTICLES"; ...
                sprintf('%d separate articles', clean.available_articles); ""; ...
                estimate.messages(:); ""; string(estimate.statement)];
            return;
        end
        requirements = clean;
        requirements.mode = 'requirements_first';
        requirements.reliability = estimate.best_reliability;
        requirements.confidence = estimate.best_confidence;
        plan = estimate_study_plan(requirements, reachable);
        plan.mode = 'available_articles_first';
        plan.available_articles = clean.available_articles;
        plan.fixed_kind = estimate.fixed_kind;
        plan.fixed_value = estimate.fixed_value;
        lines = [ ...
            "CURRENT ARTICLES"; sprintf('%d separate articles', clean.available_articles); ""; ...
            "PRE-TEST EXPECTATION"; ...
            sprintf('Reliability: %.1f%%', 100 * estimate.best_reliability); ...
            sprintf('Confidence: %.1f%%', 100 * estimate.best_confidence); ""; ...
            input_messages(:); estimate.messages(:); ""; string(estimate.statement)];
    end

    function save_plan()
        if isempty(state.current_plan), return; end
        [filename, folder] = uiputfile('*.json', 'Save study plan as');
        if isequal(filename, 0), return; end
        exact_path = fullfile(folder, filename);
        confirmation = uiconfirm(figure_handle, sprintf([ ...
            'This exact file will be created:\n\n%s\n\n' ...
            'An existing file will not be replaced.'], exact_path), ...
            'Confirm study-plan location', ...
            'Options', {'Create this plan', 'Choose again'}, ...
            'DefaultOption', 1, 'CancelOption', 2);
        if ~strcmp(confirmation, 'Create this plan'), return; end
        try
            saved_path = save_study_plan(state.current_plan, exact_path);
            state.selected_plan = state.current_plan;
            review_status.Text = ['Saved: ' saved_path];
            review_status.FontColor = color.teal;
            uialert(figure_handle, ['Study plan saved at:' newline saved_path], ...
                'Plan saved', 'Icon', 'success');
        catch save_error
            uialert(figure_handle, save_error.message, ...
                'Plan was not saved', 'Icon', 'warning');
        end
    end

    function close_planner()
        if isempty(state.selected_plan) && ~isempty(state.current_plan)
            state.selected_plan = state.current_plan;
        end
        uiresume(figure_handle);
    end
end

function L = prof_quantile(levels, successes, q, ksig, sigma0)
%PROF_QUANTILE  Profiled log-likelihood with the level q = mu + ksig*sigma held
%   fixed: substitute mu = q - ksig*sigma and maximise over sigma>0 (via log sigma).
%   Shared by lr_confidence and the reliability-at-confidence units.  [addendum LR]
    f = @(t) -loglik(levels, successes, q - ksig*exp(t), exp(t));
    that = fminsearch(f, log(sigma0), pl_opts());
    L = -f(that);
end

function model = reachable_gap_model(setup, minimum_gap_mm, maximum_gap_mm)
%REACHABLE_GAP_MODEL List the physical gaps the equipment can construct.
% The returned gaps retain their real numerical values. User-facing build
% instructions show two decimal places and, for combinations, retain the
% spacer/foil recipe so a rounded display does not lose the construction.

    validate_bounds(minimum_gap_mm, maximum_gap_mm);
    if ~isstruct(setup) || ~isfield(setup, 'mode')
        error('reachable_gap_model:badSetup', ...
            'Choose regular increments, spacer combinations, or a confirmed list.');
    end
    mode = lower(strtrim(char(string(setup.mode))));
    numerical_tolerance = 1e-10;

    switch mode
        case 'regular'
            require_fields(setup, {'increment_mm'});
            increment_mm = setup.increment_mm;
            if ~positive_scalar(increment_mm)
                error('reachable_gap_model:badIncrement', ...
                    'The regular gap increment must be one positive number.');
            end
            if abs(increment_mm * 100 - round(increment_mm * 100)) > ...
                    numerical_tolerance
                error('reachable_gap_model:badIncrementPrecision', ...
                    ['A regular gap step must be a whole hundredth so every ' ...
                     'build request can be shown accurately with two decimals. ' ...
                     'Use 0.05, 0.10, 0.15, 0.50 mm, or a confirmed list.']);
            end
            first_multiple = ceil((minimum_gap_mm - numerical_tolerance) / ...
                increment_mm);
            last_multiple = floor((maximum_gap_mm + numerical_tolerance) / ...
                increment_mm);
            multiple_numbers = (first_multiple:last_multiple)';
            gaps_mm = multiple_numbers * increment_mm;
            gaps_mm(abs(gaps_mm) < numerical_tolerance) = 0;
            instructions = compose("Set the gap to %.2f mm", gaps_mm);
            description = sprintf('Every %.4g mm from %.4g to %.4g mm', ...
                increment_mm, minimum_gap_mm, maximum_gap_mm);

        case 'list'
            require_fields(setup, {'gaps_mm'});
            supplied_gaps = setup.gaps_mm(:);
            if ~isnumeric(supplied_gaps) || ~isreal(supplied_gaps) || ...
                    any(~isfinite(supplied_gaps))
                error('reachable_gap_model:badList', ...
                    'Every confirmed reachable gap must be a finite number.');
            end
            supplied_gaps = supplied_gaps(supplied_gaps >= minimum_gap_mm - ...
                numerical_tolerance & supplied_gaps <= maximum_gap_mm + ...
                numerical_tolerance);
            gaps_mm = unique_with_tolerance(supplied_gaps, numerical_tolerance);
            instructions = compose("Use the confirmed %.2f mm setup", gaps_mm);
            description = sprintf('%d confirmed reachable gaps', numel(gaps_mm));

        case 'combinations'
            require_fields(setup, {'component_names', 'component_mm', ...
                'maximum_counts'});
            component_mm = setup.component_mm(:)';
            maximum_counts = setup.maximum_counts(:)';
            component_names = setup.component_names;
            if isstring(component_names), component_names = cellstr(component_names); end
            if ~(iscell(component_names) && numel(component_names) == ...
                    numel(component_mm) && numel(component_mm) == ...
                    numel(maximum_counts))
                error('reachable_gap_model:badComponents', ...
                    'Each physical component needs a name, measured thickness, and maximum count.');
            end
            if any(~isfinite(component_mm)) || any(component_mm <= 0) || ...
                    any(~isfinite(maximum_counts)) || any(maximum_counts < 0) || ...
                    any(maximum_counts ~= floor(maximum_counts))
                error('reachable_gap_model:badComponents', ...
                    'Component thicknesses must be positive and maximum counts must be whole numbers.');
            end
            count_rows = enumerate_counts(maximum_counts);
            all_gaps = count_rows * component_mm(:);
            keep = all_gaps >= minimum_gap_mm - numerical_tolerance & ...
                all_gaps <= maximum_gap_mm + numerical_tolerance;
            all_gaps = all_gaps(keep);
            count_rows = count_rows(keep, :);
            [all_gaps, order] = sort(all_gaps);
            count_rows = count_rows(order, :);
            keep_unique = [true; diff(all_gaps) > numerical_tolerance];
            gaps_mm = all_gaps(keep_unique);
            count_rows = count_rows(keep_unique, :);
            instructions = strings(numel(gaps_mm), 1);
            for row_number = 1:numel(gaps_mm)
                recipe = describe_recipe(count_rows(row_number, :), component_names);
                instructions(row_number) = sprintf('%.2f mm target: %s', ...
                    gaps_mm(row_number), recipe);
            end
            description = sprintf('%d reachable spacer/foil combinations', ...
                numel(gaps_mm));

        otherwise
            error('reachable_gap_model:badMode', ...
                'Physical setup mode must be regular, combinations, or list.');
    end

    if isempty(gaps_mm)
        error('reachable_gap_model:noReachableGaps', ...
            'No physical gap can be built inside the permitted range.');
    end

    model = struct('mode', mode, 'gaps_mm', gaps_mm(:), ...
        'instructions', instructions(:), 'description', description, ...
        'minimum_gap_mm', minimum_gap_mm, ...
        'maximum_gap_mm', maximum_gap_mm, ...
        'comparison_tolerance_mm', numerical_tolerance);
end

function validate_bounds(minimum_gap_mm, maximum_gap_mm)
    if ~(isnumeric(minimum_gap_mm) && isscalar(minimum_gap_mm) && ...
            isreal(minimum_gap_mm) && isfinite(minimum_gap_mm) && ...
            isnumeric(maximum_gap_mm) && isscalar(maximum_gap_mm) && ...
            isreal(maximum_gap_mm) && isfinite(maximum_gap_mm) && ...
            maximum_gap_mm > minimum_gap_mm)
        error('reachable_gap_model:badBounds', ...
            'The maximum permitted gap must be greater than the minimum gap.');
    end
end

function require_fields(value, fields)
    for field_number = 1:numel(fields)
        if ~isfield(value, fields{field_number})
            error('reachable_gap_model:missingSetupAnswer', ...
                'The physical setup answer "%s" is missing.', fields{field_number});
        end
    end
end

function yes = positive_scalar(value)
    yes = isnumeric(value) && isscalar(value) && isreal(value) && ...
        isfinite(value) && value > 0;
end

function values = unique_with_tolerance(values, tolerance)
    values = sort(values(:));
    if isempty(values), return; end
    values = values([true; diff(values) > tolerance]);
end

function count_rows = enumerate_counts(maximum_counts)
    bases = maximum_counts + 1;
    number_of_rows = prod(bases);
    count_rows = zeros(number_of_rows, numel(maximum_counts));
    for row_number = 0:number_of_rows - 1
        remaining = row_number;
        for component_number = 1:numel(maximum_counts)
            count_rows(row_number + 1, component_number) = ...
                mod(remaining, bases(component_number));
            remaining = floor(remaining / bases(component_number));
        end
    end
end

function recipe = describe_recipe(counts, names)
    pieces = strings(0, 1);
    for component_number = 1:numel(counts)
        count = counts(component_number);
        if count == 0, continue; end
        name = char(string(names{component_number}));
        if count == 1
            pieces(end + 1, 1) = "1 " + string(name); %#ok<AGROW>
        else
            pieces(end + 1, 1) = string(count) + " " + string(name) + "s"; %#ok<AGROW>
        end
    end
    if isempty(pieces)
        recipe = 'no spacers or foil';
    else
        recipe = char(strjoin(pieces, ' + '));
    end
end

function res = reliability_at_height(levels, successes, tail, x, C)
%RELIABILITY_AT_HEIGHT  Mode B: reliability at a fixed height, with a conservative
%   lower bound at confidence C.
%   res = RELIABILITY_AT_HEIGHT(levels, successes, tail, x, C)
%     tail : 'break'   -> fraction that BREAK at/above height x
%            'survive' -> fraction that SURVIVE below height x
%     x    : the height (any finite real; may sit outside the tested range)
%     C    : confidence in (0,1)
%   Returns struct with, for the point estimate and the conservative bound:
%     .reliability, .bound            (fractions in [0,1])
%     .percent, .bound_percent        (0-100)
%     .one_in_n, .bound_one_in_n      (1/(1-r); NaN when reliability <= 0.5)
%     .bound_floored                  (true if the bound hit the 1-in-a-million floor)
%     .tail, .x, .C
%   Same profile engine as Mode A, root-found over the standardised distance k
%   instead of over the height.  NaN on non-overlap.
%   [PUBLISHED likelihood-ratio profile of a monotone function of the fitted quantile]
    levels    = levels(:);
    successes = logical(successes(:));
    tail = lower(tail);
    if ~any(strcmp(tail, {'break','survive'}))
        error('reliability_at_height:badTail', 'tail must be ''break'' or ''survive''.');
    end
    if ~(isscalar(x) && isreal(x) && isfinite(x))
        error('reliability_at_height:badX', 'height x must be a single finite number.');
    end
    if ~(isscalar(C) && isreal(C) && C > 0 && C < 1)
        error('reliability_at_height:badC', 'confidence C must be a single number in (0,1).');
    end

    res = struct('reliability', NaN, 'bound', NaN, 'percent', NaN, 'bound_percent', NaN, ...
                 'one_in_n', NaN, 'bound_one_in_n', NaN, 'bound_floored', false, ...
                 'tail', tail, 'x', x, 'C', C);
    if ~has_overlap(levels, successes), return; end

    [mu, sigma, Lmax] = best_fit(levels, successes, mean(levels), fit_sigma0(levels));
    khat = (x - mu) / sigma;               % larger k means a larger physical gap
    c1   = one_sided_profile_threshold(C);
    kfl  = shape_model(1e-6, 'quantile');  % 1-in-a-million floor (~ -4.7534)
    Rk   = @(k) 2*(Lmax - prof_quantile(levels, successes, x, k, sigma));

    if strcmp(tail, 'break')
        % Legacy 'break' means Interaction in the gap application. Because
        % Interaction becomes less likely as the gap grows, a cautious lower
        % probability is found by searching toward a LARGER k.
        res.reliability = phi_cdf(khat);
        cap = -kfl - khat;                            % floor occurs at k = -kfl
        kb  = find_root(Rk, khat, +1, c1, cap, +Inf);
        if isnan(kb), res.bound = 1e-6; res.bound_floored = true;
        else          res.bound = phi_cdf(kb); end
    else
        % Legacy 'survive' means No interaction. No interaction becomes less
        % likely as the gap shrinks, so its cautious lower probability is
        % found by searching toward a SMALLER k.
        res.reliability = phi_cdf(-khat);
        cap = khat - kfl;                             % floor occurs at k = kfl
        kb  = find_root(Rk, khat, -1, c1, cap, -Inf);
        if isnan(kb), res.bound = 1e-6; res.bound_floored = true;
        else          res.bound = phi_cdf(-kb); end
    end

    res.percent        = 100 * res.reliability;
    res.bound_percent  = 100 * res.bound;
    res.one_in_n       = one_in_n(res.reliability);
    res.bound_one_in_n = one_in_n(res.bound);
end

function p = phi_cdf(z)
%PHI_CDF  Standard-normal CDF via the shape swap-point (no toolbox).
    p = shape_model(z, 0, 1).Phi;
end

function m = one_in_n(r)
%ONE_IN_N  "1 in m" for reliability r; NaN when r <= 0.5 (a "1 in 1" is meaningless).
    if r > 0.5 && r < 1
        m = 1 / (1 - r);
    else
        m = NaN;
    end
end

function q = reliability_query(result, tail, action, value, C)
%RELIABILITY_QUERY  Plain-language gap, probability, and confidence calculator.
%   Interactive:  reliability_query(result)         -- guided menu.
%   Scriptable:   q = reliability_query(result, tail, action, value, C)
%     tail   : 'break' or 'survive'
%     action : 'height_for'     value = reliability R  -> Mode A (height)
%              'reliability_at' value = height x       -> Mode B (reliability)
%              'plan'           value = reliability R  -> sample-size planner
%     C      : confidence in (0,1); defaults to settings().confidence_level.
%   Reads levels/successes/mu/sigma off `result` (the 'plan' action uses result.sigma).
%   [addendum RAC]
    cfg = neyer_settings();
    if nargin < 2
        q = run_menu(result, cfg);        % interactive path (thin I/O shell)
        return;
    end
    if nargin < 5 || isempty(C), C = cfg.confidence_level; end

    target = lower(tail);
    if strcmp(target,'interaction')
        legacy_tail='break';
    elseif strcmp(target,'no_interaction')
        legacy_tail='survive';
    elseif any(strcmp(target,{'break','survive'}))
        legacy_tail=target; % temporary compatibility for inherited callers
    else
        error('reliability_query:badTarget', ...
              'target must be ''interaction'' or ''no_interaction''.');
    end
    levels = result.levels; successes = result.successes;

    switch lower(action)
        case {'gap_for','height_for'}
            q = height_for_reliability(levels, successes, legacy_tail, value, C);
            q.gap=q.height;
            q.target=target;
            q.raw_bound=q.bound;
            q.permitted_range=[cfg.min_level cfg.max_level];
            q.bound_established=isfinite(q.raw_bound) && ...
                q.raw_bound>=cfg.min_level && q.raw_bound<=cfg.max_level;
            if ~q.bound_established
                q.bound=NaN;
            end
            q.gap_within_permitted_range=isfinite(q.gap) && ...
                q.gap>=cfg.min_level && q.gap<=cfg.max_level;
        case {'probability_at','reliability_at'}
            q = reliability_at_height(levels, successes, legacy_tail, value, C);
            q.probability=q.reliability;
            q.bound_probability=q.bound;
            q.gap=q.x;
            q.target=target;
        case 'plan'
            % Banerjee (point-estimate) basis from the fitted spread. This is the
            % up-front asymptotic formula, NOT the exact scaled 1/N basis --
            % report.m does the refined scaled count off n/level/se.
            q = plan_samples(legacy_tail, value, C, cfg, struct('sigma', result.sigma));
        otherwise
            error('reliability_query:badAction', ...
                  'action must be ''gap_for'', ''probability_at'', or ''plan''.');
    end
end

% ---- interactive menu (never called by the test suite) --------------------
% All prompts read text with input(...,'s') and validate via the local helpers
% ask_int_in_set / ask_num_in_range, which loop until the entry is good. A stray
% letter becomes NaN (str2double) and is simply re-asked, never a raw Octave
% error, so a human running the menu cannot crash it or be silently mis-defaulted.
function q = run_menu(result, cfg)
    fprintf('\n--- Reliability calculator ---\n');
    fprintf('  [1] Cautious gap for a target chance\n');
    fprintf('  [2] Chance at a physical gap\n');
    fprintf('For article planning, use the main Pre-Test Planner.\n');
    mode = ask_int_in_set('Choose 1 or 2: ', [1 2]);
    t = ask_int_in_set([ ...
        'Which outcome should be likely? [1] Interaction  [2] No interaction: '], ...
        [1 2]);
    tail = 'break'; if t == 2, tail = 'survive'; end

    if mode == 2
        x = ask_num_in_range('Physical gap (mm): ', -Inf, Inf);
        C = ask_confidence(cfg);
        q = reliability_query(result, tail, 'probability_at', x, C);
    else
        R = ask_reliability(cfg);
        C = ask_confidence(cfg);
        q = reliability_query(result, tail, 'gap_for', R, C);
    end
    print_answer(q, tail, cfg);
end

function R = ask_reliability(cfg)
    pr = cfg.reliability_presets;
    fprintf('Reliability?\n');
    for i = 1:numel(pr)
        fprintf('  [%d] 1 in %s  (%.4g%%)\n', i, thousands(1/(1-pr(i))), 100*pr(i));
    end
    own = numel(pr) + 1;
    fprintf('  [%d] type my own %%\n', own);
    c = ask_int_in_set('Choose: ', 1:own);
    if c == own
        pct = ask_num_in_range('Reliability percent (e.g. 99.5): ', 0, 100); % strictly (0,100)
        R = pct / 100;
    else
        R = pr(c);
    end
end

function C = ask_confidence(cfg)
    % Empty (Enter) keeps the default; anything else must be a percent in (0,100).
    while true
        s = input(sprintf('Confidence %% [Enter for %g]: ', 100*cfg.confidence_level), 's');
        if isempty(s), C = cfg.confidence_level; return; end
        v = str2double(s);
        if isscalar(v) && isfinite(v) && v > 0 && v < 100, C = v / 100; return; end
        fprintf('  Please enter a percentage between 0 and 100 (or press Enter for %g).\n', ...
                100*cfg.confidence_level);
    end
end

% ---- input helpers: loop on input() until the entry validates --------------
function v = ask_int_in_set(prompt, allowed)
%ASK_INT_IN_SET  Re-ask until the reply is an integer in the allowed set.
    while true
        x = str2double(input(prompt, 's'));   % 's' so a stray letter -> NaN, not an error
        if isscalar(x) && isfinite(x) && x == round(x) && any(x == allowed)
            v = x; return;
        end
        fprintf('  Please enter one of: %s\n', num2str(allowed));
    end
end

function v = ask_num_in_range(prompt, lo, hi)
%ASK_NUM_IN_RANGE  Re-ask until the reply parses to a number strictly in (lo,hi).
%   lo/hi may be -Inf/+Inf to leave a side open; the bound is always exclusive.
    while true
        x = str2double(input(prompt, 's'));
        if isscalar(x) && isfinite(x) && x > lo && x < hi
            v = x; return;
        end
        if isfinite(lo) && isfinite(hi)
            fprintf('  Please enter a number between %g and %g.\n', lo, hi);
        else
            fprintf('  Please enter a number.\n');
        end
    end
end

function print_answer(q, tail, cfg)
    % Minimal plain-language echo; report.m carries the detailed phrasing.
    fprintf('\n');
    if isfield(q, 'height')
        outcome = 'Interaction'; direction = 'at or below';
        if strcmp(tail,'survive')
            outcome = 'No interaction'; direction = 'at or above';
        end
        fprintf([ ...
            'At %.4g%% confidence, the %.4g%% %s setting is %.2f mm %s.\n'], ...
            100*q.C, 100*q.R, outcome, q.bound, direction);
    elseif isfield(q, 'reliability')
        outcome = 'Interaction';
        if strcmp(tail,'survive'), outcome = 'No interaction'; end
        fprintf([ ...
            'At %.2f mm and %.4g%% confidence, the supported chance of %s is at least %.4g%%.\n'], ...
            q.x, 100*q.C, outcome, q.bound_percent);
    elseif isfield(q, 'n_recommended')
        fprintf('Formula-only starting estimate: %d articles. %s\n', ...
            q.n_recommended, q.caveat);
        fprintf('(Why at least %d: %s)\n', q.n_floor, q.floor_reason);
        fprintf(['Use the main Pre-Test Planner before preparing articles; ' ...
            'it applies the recorded safety rules.\n']);
    end
end

function s = thousands(x)
%THOUSANDS  Format a number with comma separators (e.g. 1000000 -> 1,000,000).
    s = sprintf('%.0f', x);
    out = '';
    n = numel(s);
    for i = 1:n
        out = [out, s(i)];
        r = n - i;
        if r > 0 && mod(r,3) == 0, out = [out, ',']; end
    end
    s = out;
end

function result = report(record, cfg)
%REPORT  Worker #9 â€” present the final middle gap, overall variation, and confidence.
%
%   result = REPORT(record, cfg) takes the finished run (from run_loop) and
%   produces the headline answer: the best-fit middle gap and width over all
%   tests, plus the confidence (standard error) in each.  [brief sec.4 worker
%   #9; App.A Eqs.5-6]
%
%   Confidence comes from the Fisher information matrix at the final estimate
%   (summed over every level tested):
%       det(I) = I00*I11 - I01^2
%       var(mu)    = I11 / det(I)        (Eq.5)
%       var(sigma) = I00 / det(I)        (Eq.6)
%   and the standard error of each is the square root of its variance.
%
%   Inputs
%     record   struct from run_loop (.levels, .successes, .est_mu, .est_sigma).
%     cfg      settings struct (optional; defaults to settings()).
%
%   Output struct result:
%     .mu, .sigma            final estimate (MLE, clamped by worker #5).
%     .var_mu, .var_sigma    variances from Eqs.5-6.
%     .se_mu, .se_sigma      standard errors (sqrt of the variances).
%     .tail_fraction, .tail_k  the strictness used (e.g. 0.999) and its z-distance k.
%     .all_fire, .se_all_fire  the "nearly all break" level (mu+k*sigma) and its std err.
%     .no_fire,  .se_no_fire   the "nearly all survive" level (mu-k*sigma) and its std err.
%     .confidence_level      the LR confidence level used (e.g. 0.95).
%     .mu_lo/.mu_hi, .sigma_lo/.sigma_hi   two-sided LR confidence intervals (addendum LR).
%     .all_fire_cbound, .no_fire_cbound    one-sided LR bounds on the tail levels.
%     .has_overlap           whether a real answer exists at all.
%     .n                     number of tests used.
%   A formatted summary is also printed.

    if nargin < 2 || isempty(cfg), cfg = neyer_settings(); end

    % Display unit is a label only (no conversion). Guard if missing/empty.
    if isfield(cfg, 'unit') && ~isempty(cfg.unit), u = cfg.unit; else, u = ''; end

    levels    = record.levels(:);
    successes = logical(record.successes(:));
    n         = numel(levels);

    if isfield(record,'status'), run_status=record.status; else, run_status='complete'; end
    if isfield(record,'stop_reason'), stop_reason=record.stop_reason; else, stop_reason=''; end

    result = struct('mu', NaN, 'sigma', NaN, ...
                    'unit', u, ...
                    'status', run_status, 'stop_reason', stop_reason, ...
                    'var_mu', NaN, 'var_sigma', NaN, ...
                    'se_mu', NaN, 'se_sigma', NaN, ...
                    'tail_fraction', NaN, 'tail_k', NaN, ...
                    'all_fire', NaN, 'se_all_fire', NaN, ...
                    'no_fire', NaN, 'se_no_fire', NaN, ...
                    'high_interaction_gap', NaN, ...
                    'negligible_interaction_gap', NaN, ...
                    'se_high_interaction_gap', NaN, ...
                    'se_negligible_interaction_gap', NaN, ...
                    'high_interaction_cbound', NaN, ...
                    'negligible_interaction_cbound', NaN, ...
                    'confidence_level', NaN, ...
                    'mu_lo', NaN, 'mu_hi', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
                    'all_fire_cbound', NaN, 'no_fire_cbound', NaN, ...
                    'has_overlap', false, 'n', n, 'levels', levels, 'successes', successes);

    % No overlap -> no real answer exists yet (Silvapulle). Report honestly.
    if ~has_overlap(levels, successes)
        result.has_overlap = false;
        if strcmp(run_status,'paused')
            fprintf('\n=== Neyer gap study: PAUSED - REVIEW REQUIRED ===\n');
            fprintf('The completed test data are saved, but the boundary result conflicts\n');
            fprintf('with the expected gap behavior. Do not continue automatically.\n');
            fprintf('Reason: %s.\n\n',strrep(stop_reason,'_',' '));
        else
            fprintf('\n=== Neyer sensitivity test: NO RESULT ===\n');
            fprintf('Results have not yet overlapped, so the middle gap and overall variation\n');
            fprintf('cannot be estimated yet. More test results are needed.\n\n');
        end
        return;
    end
    result.has_overlap = true;

    % Final best-fit (warm-started from the last going-in estimate) then clamp.
    mu0    = record.est_mu(end);
    sigma0 = record.est_sigma(end);
    [mu, sigma] = best_fit(levels, successes, mu0, sigma0);
    [mu, sigma] = sanity_clamp(mu, sigma, levels, cfg);

    % Information matrix at the final estimate, over all levels (Eq.4).
    [j0, j1, j2] = info_terms(levels, mu, sigma);
    I00 = sum(j0);
    I01 = sum(j1);
    I11 = sum(j2);
    detI = I00 * I11 - I01^2;

    var_mu    = I11 / detI;     % Eq.5
    var_sigma = I00 / detI;     % Eq.6

    result.mu        = mu;
    result.sigma     = sigma;
    result.var_mu    = var_mu;
    result.var_sigma = var_sigma;
    result.se_mu     = sqrt(var_mu);
    result.se_sigma  = sqrt(var_sigma);

    % --- Tail levels: all-fire / no-fire (addendum B1) --------------------
    % all-fire  = the level where cfg.tail_fraction of items BREAK.
    % no-fire   = the level where that same fraction SURVIVE.
    % The +/- figures come from the delta method on quantities already
    % computed above (Eqs.5-6 plus the 2x2 inverse: cov(mu,sigma) = -I01/det).
    % No new estimation machinery -- just post-processing. [PAPER for q=mu+k*sigma
    % and its variance; RECOMMENDATION for surfacing it]
    p_tail = cfg.tail_fraction;
    % The dial must keep all-fire on the UPPER tail: p in (0.5, 1). A clear
    % error beats silently swapping all-fire and no-fire if it's mis-set.
    if ~(isscalar(p_tail) && isreal(p_tail) && isfinite(p_tail) && p_tail > 0.5 && p_tail < 1)
        error('report:badTailFraction', ...
              ['cfg.tail_fraction (%.6g) must be a single number strictly between 0.5 and 1 ' ...
               '(e.g. 0.999 = the all-fire level that 99.9%% of items reach).'], p_tail);
    end
    k      = shape_model(p_tail, 'quantile');   % how many spreads out (worker #1)
    cov_ms = -I01 / detI;                         % covariance of mu-hat and sigma-hat
    var_all = var_mu + k^2 * var_sigma + 2*k * cov_ms;
    var_no  = var_mu + k^2 * var_sigma - 2*k * cov_ms;

    result.tail_fraction = p_tail;
    result.tail_k        = k;
    result.all_fire      = mu + k * sigma;
    result.no_fire       = mu - k * sigma;
    result.se_all_fire   = sqrt(max(var_all, 0)); % max(.,0) guards tiny numeric negatives
    result.se_no_fire    = sqrt(max(var_no,  0));
    result.high_interaction_gap = mu - k * sigma;
    result.negligible_interaction_gap = mu + k * sigma;
    result.se_high_interaction_gap = sqrt(max(var_no,0));
    result.se_negligible_interaction_gap = sqrt(max(var_all,0));

    % --- Likelihood-Ratio confidence bounds (addendum LR) ----------------
    Cc = cfg.confidence_level;
    if ~(isscalar(Cc) && isreal(Cc) && isfinite(Cc) && Cc > 0 && Cc < 1)
        error('report:badConfidence', ...
              'cfg.confidence_level (%.6g) must be a single number strictly between 0 and 1.', Cc);
    end
    ci = lr_confidence(levels, successes, mu, sigma, cfg);
    result.confidence_level = ci.confidence_level;
    result.mu_lo = ci.mu_lo;             result.mu_hi = ci.mu_hi;
    result.sigma_lo = ci.sigma_lo;       result.sigma_hi = ci.sigma_hi;
    result.all_fire_cbound = ci.all_fire_cbound;
    result.no_fire_cbound  = ci.no_fire_cbound;
    result.high_interaction_cbound = ci.no_fire_cbound;
    result.negligible_interaction_cbound = ci.all_fire_cbound;

    pc  = 100 * p_tail;         % strictness, e.g. 99.9
    cc  = 100 * result.confidence_level;   % confidence, e.g. 95
    fprintf('\n=== Neyer sensitivity test: RESULT (%d tests) ===\n\n', n);
    fprintf('MIDDLE GAP (about 50%% interaction): %.4f %s\n', mu, u);
    fprintf('  %.4g%% confident the true middle is between %.4f and %.4f %s.\n\n', ...
            cc, result.mu_lo, result.mu_hi, u);
    fprintf('OVERALL VARIATION: %.4f %s\n', sigma, u);
    fprintf('  Smaller means a sharper change; larger means a more gradual change.\n');
    fprintf('  %.4g%% confident the true overall variation is between %.4f and %.4f %s.\n\n', ...
            cc, result.sigma_lo, result.sigma_hi, u);
    fprintf('HIGH-INTERACTION gap (about %.4g%% interaction): %.4f %s\n', ...
            pc, result.high_interaction_gap, u);
    if isfinite(result.high_interaction_cbound) && ...
            result.high_interaction_cbound >= cfg.min_level && ...
            result.high_interaction_cbound <= cfg.max_level
        fprintf('  %.4g%% confidence boundary: gaps at or below %.4f %s.\n', ...
                cc, result.high_interaction_cbound, u);
    else
        fprintf('  Confidence boundary not established within the permitted %.2f-%.2f %s range.\n', ...
                cfg.min_level,cfg.max_level,u);
    end
    fprintf('\n');
    fprintf('NEGLIGIBLE-INTERACTION gap (about %.4g%% no interaction): %.4f %s\n', ...
            pc, result.negligible_interaction_gap, u);
    if isfinite(result.negligible_interaction_cbound) && ...
            result.negligible_interaction_cbound >= cfg.min_level && ...
            result.negligible_interaction_cbound <= cfg.max_level
        fprintf('  %.4g%% confidence boundary: gaps at or above %.4f %s.\n', ...
                cc, result.negligible_interaction_cbound, u);
    else
        fprintf('  Confidence boundary not established within the permitted %.2f-%.2f %s range.\n', ...
                cfg.min_level,cfg.max_level,u);
    end
    fprintf('\nNote: the edge gaps are less certain than the middle gap.\n\n');
end

function summary = result_decision_summary(result)
%RESULT_DECISION_SUMMARY Turn a fitted result into a safe, plain-language decision.
% A fitted curve alone is an estimate. A usable operating instruction is shown
% only when a saved plan is attached, its checkpoint is complete, and the
% confidence boundary can be rounded safely to a reachable physical gap.

    unit = 'mm';
    if isstruct(result) && isfield(result, 'unit') && ~isempty(result.unit)
        unit = char(string(result.unit));
    end
    summary = empty_summary(unit);

    if ~isstruct(result) || ~isfield(result, 'has_overlap') || ...
            ~result.has_overlap || ~isfield(result, 'mu') || ...
            ~isfinite(result.mu)
        summary.status = 'no_estimate';
        summary.explanation = [ ...
            'A usable middle gap has not been established from both outcomes.'];
        return;
    end

    summary.middle_gap_mm = result.mu;
    summary.middle_range_mm = [field_or_nan(result, 'mu_lo'), ...
        field_or_nan(result, 'mu_hi')];
    summary.overall_variation_mm = field_or_nan(result, 'sigma');
    summary.overall_variation_explanation = [ ...
        'Overall variation describes how much the entire tested process varies ' ...
        'from article to article around the middle gap.'];

    if ~isfield(result, 'study_plan') || isempty(result.study_plan)
        summary.status = 'estimate_only';
        summary.explanation = [ ...
            'This fitted result is not linked to a saved plan, so it is an ' ...
            'estimate only and not a supported operating instruction.'];
        return;
    end

    plan = result.study_plan;
    required = {'outcome', 'reliability', 'confidence', ...
        'minimum_gap_mm', 'maximum_gap_mm', 'reachable_model', ...
        'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~isstruct(plan) || ~all(isfield(plan, required))
        summary.status = 'plan_incomplete';
        summary.explanation = [ ...
            'The attached plan is missing required safety information, so no ' ...
            'operating instruction can be supported.'];
        return;
    end
    [safe_plan, safety_message] = validate_study_plan_safety(plan);
    if ~safe_plan
        summary.status = 'plan_incomplete';
        summary.explanation = safety_message;
        return;
    end

    outcome = lower(strtrim(char(string(plan.outcome))));
    summary.outcome = outcome;
    summary.reliability = plan.reliability;
    summary.confidence = plan.confidence;

    if ~plan.reliability_instruction_supported
        summary.status = 'outside_validation_envelope';
        summary.explanation = [ ...
            'The fitted curve can still be reviewed, but this confidence is ' ...
            'not safety-supported by the recorded validation. No operating ' ...
            'instruction is shown.'];
        return;
    end
    if ~isfield(result, 'n') || ...
            result.n < plan.reliability_validation_floor_articles
        summary.status = 'article_floor_not_reached';
        summary.explanation = sprintf([ ...
            'The fitted curve can still be reviewed, but the supported ' ...
            'reliability instruction requires %d independent articles.'], ...
            plan.reliability_validation_floor_articles);
        return;
    end

    try
        boundary = reliability_query(result, outcome, 'gap_for', ...
            plan.reliability, plan.confidence);
        raw_gap_mm = boundary.raw_bound;
    catch err
        summary.status = 'boundary_not_established';
        summary.explanation = sprintf( ...
            'The requested confidence boundary could not be calculated: %s', ...
            err.message);
        return;
    end
    summary.raw_confidence_boundary_mm = raw_gap_mm;

    inside_permitted_range = isfinite(raw_gap_mm) && ...
        raw_gap_mm >= plan.minimum_gap_mm && ...
        raw_gap_mm <= plan.maximum_gap_mm;
    if ~inside_permitted_range
        summary.status = 'outside_permitted_range';
        summary.explanation = sprintf([ ...
            'The requested reliability boundary is not established inside the ' ...
            'permitted range of %.2f to %.2f %s. No usable setting is shown.'], ...
            plan.minimum_gap_mm, plan.maximum_gap_mm, unit);
        return;
    end

    [reachable_gap_mm, reachable_status] = select_operating_gap( ...
        raw_gap_mm, outcome, plan.reachable_model);
    if ~strcmp(reachable_status.code, 'ok')
        summary.status = 'no_safe_reachable_gap';
        summary.explanation = reachable_status.message;
        return;
    end
    summary.reachable_gap_mm = reachable_gap_mm;
    summary.display_gap = string(sprintf('%.2f %s', reachable_gap_mm, unit));
    summary.physical_build_instruction = string(reachable_status.instruction);

    checkpoint_complete = isfield(result, 'checkpoint_decision') && ...
        isstruct(result.checkpoint_decision) && ...
        isfield(result.checkpoint_decision, 'status') && ...
        strcmp(result.checkpoint_decision.status, 'complete');
    if ~checkpoint_complete
        summary.status = 'checkpoint_incomplete';
        summary.explanation = [ ...
            'The saved plan checkpoint is not complete. Keep this as an estimate; ' ...
            'do not use it as a supported operating instruction.'];
        summary.display_gap = "Not established";
        summary.reachable_gap_mm = NaN;
        summary.physical_build_instruction = "";
        return;
    end

    summary.supported = true;
    summary.status = 'supported';
    if strcmp(outcome, 'interaction')
        direction_words = 'or smaller';
        outcome_words = 'Interaction';
    else
        direction_words = 'or larger';
        outcome_words = 'No interaction';
    end
    summary.operating_instruction = sprintf([ ...
        'Use %.2f %s %s for the planned %.4g%% %s target at %.4g%% confidence.'], ...
        reachable_gap_mm, unit, direction_words, 100 * plan.reliability, ...
        outcome_words, 100 * plan.confidence);
    summary.explanation = [ ...
        'The completed saved plan supports this physically reachable setting. ' ...
        'It includes one extra reachable step in the safe direction for a new build.'];
end

function summary = empty_summary(unit)
    summary = struct( ...
        'supported', false, ...
        'status', 'no_estimate', ...
        'display_gap', "Not established", ...
        'reachable_gap_mm', NaN, ...
        'raw_confidence_boundary_mm', NaN, ...
        'operating_instruction', '', ...
        'physical_build_instruction', "", ...
        'explanation', '', ...
        'outcome', '', ...
        'reliability', NaN, ...
        'confidence', NaN, ...
        'middle_gap_mm', NaN, ...
        'middle_range_mm', [NaN NaN], ...
        'overall_variation_mm', NaN, ...
        'overall_variation_explanation', [ ...
            'Overall variation describes how much the entire tested process varies ' ...
            'from article to article around the middle gap.'], ...
        'unit', unit);
end

function value = field_or_nan(value_struct, field_name)
    value = NaN;
    if isfield(value_struct, field_name) && ...
            isnumeric(value_struct.(field_name)) && ...
            isscalar(value_struct.(field_name)) && ...
            isfinite(value_struct.(field_name))
        value = value_struct.(field_name);
    end
end

function paths = result_output_paths(base)
%RESULT_OUTPUT_PATHS  Return the CSV and HTML paths for a chosen base name.
%   A user may choose a name with or without an extension. The tool always
%   creates one CSV data file and one self-contained HTML report beside it.
    [folder, name, ~] = fileparts(base);
    if isempty(name)
        name = 'gap-study-results';
    end
    paths = struct('csv', fullfile(folder, [name '.csv']), ...
                   'html', fullfile(folder, [name '.html']));
end

function available = result_save_available(result)
%RESULT_SAVE_AVAILABLE True when at least one completed test can be saved.
    available = isstruct(result) && isfield(result, 'levels') && ...
        isfield(result, 'successes') && isnumeric(result.levels) && ...
        (isnumeric(result.successes) || islogical(result.successes)) && ...
        ~isempty(result.levels) && ...
        numel(result.levels) == numel(result.successes);
end

function txt = results_to_csv_text(result)
%RESULTS_TO_CSV_TEXT  Build a CSV report (as text) from a run's result struct.
%   txt = RESULTS_TO_CSV_TEXT(result) returns spreadsheet-friendly CSV text:
%   a per-drop table (test #, height, broke/survived) then a summary block
%   (average, spread, 95%% range, safe/breaks-above heights). Data only -- no
%   code. Pure (no file IO); save_results_files writes it. [compiled-app]
    u = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit), u = result.unit; end
    lv = result.levels(:);
    sc = logical(result.successes(:));
    n  = numel(lv);
    pc = 99.9;   % tail percentage, from the run's settings (default 99.9)
    if isfield(result, 'tail_fraction') && ~isempty(result.tail_fraction), pc = 100 * result.tail_fraction; end

    L = {};
    isPhysical=isfield(result,'requested_levels') && ...
        isfield(result,'measurements') && numel(result.requested_levels)==n && ...
        numel(result.measurements)==n;
    if isPhysical
        L{end+1}=sprintf(['test,internal target (%s),build request (%s),' ...
            'actual measured gap (%s),measurement count,outcome'],u,u,u);
        requested=result.requested_levels(:);
        if isfield(result,'raw_requested_levels') && ...
                numel(result.raw_requested_levels)==n
            rawRequested=result.raw_requested_levels(:);
        else
            % Older physical records did not store the pre-rounding target.
            rawRequested=requested;
        end
        for k=1:n
            if sc(k), o='interaction'; else, o='no interaction'; end
            L{end+1}=sprintf('%d,%s,%.2f,%s,1,%s', ...
                k,csv_number(rawRequested(k)),requested(k),csv_number(lv(k)), ...
                o);
        end
    else
        L{end+1} = sprintf('test,gap (%s),outcome', u);
        for k = 1:n
            if sc(k), o = 'interaction'; else, o = 'no interaction'; end
            L{end+1} = sprintf('%d,%.2f,%s', k, lv(k), o);
        end
    end
    L{end+1} = '';
    L{end+1} = 'summary,value,unit';
    L{end+1} = sprintf('Middle gap,%.4f,%s', csv_field(result,'mu',NaN), u);
    L{end+1} = sprintf('Overall variation,%.4f,%s', csv_field(result,'sigma',NaN), u);
    L{end+1} = sprintf('95%% middle-gap low,%.4f,%s', csv_field(result,'mu_lo',NaN), u);
    L{end+1} = sprintf('95%% middle-gap high,%.4f,%s', csv_field(result,'mu_hi',NaN), u);
    L{end+1} = sprintf('High-interaction gap (~%.4g%% interaction),%.4f,%s', ...
        pc,csv_field(result,'high_interaction_gap',NaN),u);
    L{end+1} = sprintf('Negligible-interaction gap (~%.4g%% no interaction),%.4f,%s', ...
        pc,csv_field(result,'negligible_interaction_gap',NaN),u);
    L{end+1} = sprintf('Tests,%d,', n);
    if isfield(result,'usable_resolution') && ~isempty(result.usable_resolution)
        L{end+1}=sprintf('Usable resolution,%.4f,%s', ...
            result.usable_resolution,u);
    end
    if isfield(result,'foil_thickness') && ~isempty(result.foil_thickness)
        L{end+1}=sprintf('Foil thickness,%.4f,%s',result.foil_thickness,u);
    end
    if isfield(result,'resolution_sigma_floor') && ...
            ~isempty(result.resolution_sigma_floor)
        L{end+1}=sprintf('Stage-2 planning variation floor,%.4f,%s', ...
            result.resolution_sigma_floor,u);
    end

    txt = strjoin(L, sprintf('\n'));
end

function v = csv_field(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name)) && ~isnan(s.(name)), v = s.(name);
    else, v = dflt; end
end

function text = csv_number(value)
%CSV_NUMBER Shortest clean decimal that recreates the same MATLAB double.
% This keeps ordinary readings such as 3.67 readable without losing the
% uncommon 16th or 17th digit needed by some valid numeric values.
    for significantDigits=1:17
        candidate=sprintf(['%.' num2str(significantDigits) 'g'],value);
        if isequal(str2double(candidate),value)
            text=candidate;
            return;
        end
    end
    text=sprintf('%.17g',value);
end

function txt = results_to_html(result, img_b64)
%RESULTS_TO_HTML Build a self-contained report, including unfinished studies.
% The report always preserves completed physical tests. A fitted estimate is
% shown only when the data support one; missing limits are described in words.
    if nargin < 2 || isempty(img_b64), img_b64 = ''; end
    unit = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit)
        unit = char(string(result.unit));
    end
    levels = field_vector(result, 'levels');
    successes = logical(field_vector(result, 'successes'));
    if numel(levels) ~= numel(successes)
        error('results_to_html:recordLengthMismatch', ...
            'Every completed gap must have one Interaction or No interaction result.');
    end
    number_of_tests = numel(levels);
    confidence = scalar_field(result, 'confidence_level', 0.95);
    has_estimate = isfield(result, 'has_overlap') && result.has_overlap && ...
        isfield(result, 'mu') && isscalar(result.mu) && isfinite(result.mu);
    decision = result_decision_summary(result);
    unit_html = html_escape(unit);

    if decision.supported
        decision_class = 'supported';
        decision_title = 'Supported operating instruction';
        decision_text = html_escape(decision.operating_instruction);
        build_text = sprintf('<p><strong>Physical build:</strong> %s</p>', ...
            html_escape(char(decision.physical_build_instruction)));
    else
        decision_class = 'not-supported';
        decision_title = 'Operating instruction not established';
        decision_text = html_escape(decision.explanation);
        build_text = '';
    end

    if has_estimate
        middle_range = format_confidence_range(confidence, ...
            scalar_field(result, 'mu_lo', NaN), ...
            scalar_field(result, 'mu_hi', NaN), unit);
        variation = scalar_field(result, 'sigma', NaN);
        variation_range = format_confidence_range(confidence, ...
            scalar_field(result, 'sigma_lo', NaN), ...
            scalar_field(result, 'sigma_hi', NaN), unit);
        if isfinite(variation)
            variation_text = sprintf('%.2f %s', variation, unit);
        else
            variation_text = 'Not established from these results';
        end
        fitted_section = strjoin({ ...
            sprintf('<p class="big">Middle gap (about 50%% interaction): %.2f %s</p>', ...
                result.mu, unit_html), ...
            '<p>At this gap, interaction is estimated to occur in about half of similar articles. It is not a reliable operating gap by itself.</p>', ...
            sprintf('<p>%s. Based on %d completed tests.</p>', ...
                html_escape(middle_range), number_of_tests), ...
            sprintf(['<div class="fact"><strong>Overall variation: %s.</strong> ' ...
                'This describes how much the entire tested process changes from ' ...
                'article to article around the middle gap.<br>%s.</div>'], ...
                html_escape(variation_text), html_escape(variation_range)), ...
            '<p>Smaller gaps make interaction more likely. Larger gaps make interaction less likely. Estimates far from the middle gap are less certain.</p>'}, ...
            sprintf('\n'));
        if isempty(img_b64)
            image_tag = '<p><em>The chart image was not available when this file was saved.</em></p>';
        else
            image_tag = sprintf(['<img alt="fitted interaction curve" ' ...
                'src="data:image/png;base64,%s">'], img_b64);
        end
        chart_section = sprintf('<h2>Fitted result</h2>%s', image_tag);
    else
        fitted_section = strjoin({ ...
            '<section class="no-fit"><h2>No fitted middle gap has been established</h2>', ...
            sprintf(['<p>The %d completed tests are preserved below. The results ' ...
                'did not contain both outcomes close enough together to calculate ' ...
                'a middle gap and overall variation honestly.</p>'], number_of_tests), ...
            '<p>This is not a lost test record. Save it, review the actual outcomes, and decide separately whether another study is justified.</p></section>'}, ...
            sprintf('\n'));
        chart_section = '';
    end

    test_table = completed_test_table(result, levels, successes, unit);
    txt = strjoin({ ...
        '<!doctype html><html><head><meta charset="utf-8">', ...
        '<title>Neyer gap-study results</title>', ...
        ['<style>body{font-family:system-ui,Arial,sans-serif;max-width:980px;margin:2rem auto;' ...
         'padding:0 1rem;color:#243039}h1{font-size:1.7rem}h2{margin-top:1.6rem}' ...
         '.decision,.no-fit{border-radius:10px;padding:1rem 1.2rem;margin:1rem 0}' ...
         '.supported{background:#eaf5ee;border:2px solid #2a7040}' ...
         '.not-supported,.no-fit{background:#fff4df;border:2px solid #a56c16}' ...
         '.big{font-size:1.3rem;font-weight:bold}.fact{background:#f3f6f7;border-left:5px solid #54717d;padding:.75rem 1rem}' ...
         'table{width:100%;border-collapse:collapse;margin:1rem 0}th,td{padding:.6rem;border:1px solid #ccd5d8;text-align:left;vertical-align:top}' ...
         'th{background:#e8eef0}tbody tr:nth-child(even){background:#f7f9fa}img{max-width:100%;border:1px solid #ccd5d8;border-radius:8px}' ...
         '.note{background:#eef4f7;padding:.8rem 1rem;border-radius:8px}</style>'], ...
        '</head><body>', ...
        '<h1>Neyer gap-study results</h1>', ...
        sprintf('<section class="decision %s"><h2>%s</h2><p>%s</p>%s</section>', ...
            decision_class, decision_title, decision_text, build_text), ...
        fitted_section, ...
        '<p class="note"><strong>Direct-test reminder:</strong> the number entered at the start is the maximum number of destructive tests allowed. Without a saved plan, it is not a promise that a chosen confidence level will be reached.</p>', ...
        '<h2>Completed physical tests</h2>', ...
        '<p>Each row contains the one measured gap used in the calculation.</p>', ...
        test_table, ...
        chart_section, ...
        '<hr><p style="color:#66737a;font-size:.85rem">Generated by the Neyer Gap Test using the Neyer (1994) D-optimal sensitivity method.</p>', ...
        '</body></html>'}, sprintf('\n'));
end

function table_html = completed_test_table(result, levels, successes, unit)
    number_of_tests = numel(levels);
    if number_of_tests == 0
        table_html = '<p>No completed physical tests were recorded.</p>';
        return;
    end
    requested = levels;
    if isfield(result, 'requested_levels') && ...
            isnumeric(result.requested_levels) && ...
            numel(result.requested_levels) == number_of_tests
        requested = result.requested_levels(:);
    end
    measurements = cell(number_of_tests, 1);
    if isfield(result, 'measurements') && iscell(result.measurements)
        supplied = result.measurements(:);
        supplied_count = min(number_of_tests, numel(supplied));
        measurements(1:supplied_count) = supplied(1:supplied_count);
    end
    rows = cell(number_of_tests, 1);
    unit_html = html_escape(unit);
    for test_number = 1:number_of_tests
        measured_text = 'Not recorded';
        measured_gap = measurements{test_number};
        if isnumeric(measured_gap) && isscalar(measured_gap) && ...
                isfinite(measured_gap)
            measured_text = html_number(measured_gap);
        end
        if successes(test_number)
            outcome_text = 'Interaction';
        else
            outcome_text = 'No interaction';
        end
        rows{test_number} = sprintf([ ...
            '<tr><td>%d</td><td>%.2f %s</td><td>%s %s</td>' ...
            '<td>%s</td></tr>'], ...
            test_number, requested(test_number), unit_html, ...
            html_escape(measured_text), unit_html, ...
            outcome_text);
    end
    table_html = strjoin({ ...
        '<table><thead><tr><th>Test</th><th>Requested build gap</th>', ...
        '<th>Actual measured gap</th><th>Outcome</th></tr></thead><tbody>', ...
        strjoin(rows, sprintf('\n')), '</tbody></table>'}, sprintf('\n'));
end

function text = html_number(value)
%HTML_NUMBER Shortest readable decimal that recreates the stored value.
    for significant_digits = 1:17
        candidate = sprintf(['%.' num2str(significant_digits) 'g'], value);
        if isequal(str2double(candidate), value)
            text = candidate;
            return;
        end
    end
    text = sprintf('%.17g', value);
end

function text = html_escape(text)
    text = strrep(char(string(text)), '&', '&amp;');
    text = strrep(text, '<', '&lt;');
    text = strrep(text, '>', '&gt;');
    text = strrep(text, '"', '&quot;');
end

function value = scalar_field(value_struct, field_name, default_value)
    value = default_value;
    if isfield(value_struct, field_name) && ...
            isnumeric(value_struct.(field_name)) && ...
            isscalar(value_struct.(field_name)) && ...
            ~isempty(value_struct.(field_name))
        value = value_struct.(field_name);
    end
end

function values = field_vector(value_struct, field_name)
    values = zeros(0, 1);
    if isfield(value_struct, field_name) && ...
            (isnumeric(value_struct.(field_name)) || ...
             islogical(value_struct.(field_name)))
        values = value_struct.(field_name)(:);
    end
end

function [gap_mm, status] = round_reachable_gap(raw_gap_mm, outcome, model, previous_gap_mm)
%ROUND_REACHABLE_GAP Move a mathematical limit to a physically safe setting.
% Interaction moves down (same gap or smaller). No interaction moves up
% (same gap or larger). A previously used setting is excluded when supplied.

    if nargin < 4, previous_gap_mm = []; end
    if ~(isnumeric(raw_gap_mm) && isscalar(raw_gap_mm) && ...
            isreal(raw_gap_mm) && isfinite(raw_gap_mm))
        error('round_reachable_gap:badGap', ...
            'The mathematical gap must be one finite number.');
    end
    if ~isstruct(model) || ~all(isfield(model, ...
            {'gaps_mm', 'instructions', 'comparison_tolerance_mm'}))
        error('round_reachable_gap:badModel', ...
            'A reachable-gap model is required before safe rounding.');
    end
    target = lower(strtrim(char(string(outcome))));
    tolerance = model.comparison_tolerance_mm;
    gaps = model.gaps_mm(:);

    if strcmp(target, 'interaction')
        safe = gaps <= raw_gap_mm + tolerance;
    elseif strcmp(target, 'no_interaction')
        safe = gaps >= raw_gap_mm - tolerance;
    else
        error('round_reachable_gap:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end
    had_safe_setting = any(safe);

    if ~isempty(previous_gap_mm)
        if ~(isnumeric(previous_gap_mm) && isscalar(previous_gap_mm) && ...
                isreal(previous_gap_mm) && isfinite(previous_gap_mm))
            error('round_reachable_gap:badPreviousGap', ...
                'The previous requested gap must be one finite number.');
        end
        safe = safe & abs(gaps - previous_gap_mm) > tolerance;
    end

    candidate_rows = find(safe);
    if isempty(candidate_rows)
        gap_mm = NaN;
        if had_safe_setting && ~isempty(previous_gap_mm)
            code = 'no_different_setting';
            message = ['No different reachable and safe setting remains. ' ...
                'Review the physical setup before continuing.'];
        else
            code = 'no_safe_setting';
            message = ['The confidence limit has no safely rounded reachable ' ...
                'setting inside the permitted range.'];
        end
        status = struct('code', code, 'message', message, ...
            'display_gap', "Not established", 'instruction', "", ...
            'raw_gap_mm', raw_gap_mm);
        return;
    end

    [~, nearest_position] = min(abs(gaps(candidate_rows) - raw_gap_mm));
    chosen_row = candidate_rows(nearest_position);
    gap_mm = gaps(chosen_row);
    status = struct('code', 'ok', 'message', ...
        'A reachable setting was selected in the safe direction.', ...
        'display_gap', string(sprintf('%.2f mm', gap_mm)), ...
        'instruction', model.instructions(chosen_row), ...
        'raw_gap_mm', raw_gap_mm);
end

function d = run_demo()
%RUN_DEMO Replay Neyer's published example in decreasing-gap terminology.
%   The paper's increasing-response outcomes are mirrored so true means
%   interaction at a smaller gap. This preserves the published test levels and
%   fitted gate (5.3922 / 1.0412) while exercising the final gap direction.
%   Returns a struct: .result (the run), .expected_mu, .expected_sigma,
%   .got_mu, .got_sigma, .is_match, .tol. [compiled-app]
    paperOutcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    fixed = ~paperOutcomes;
    params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
    result = run_test(params, 20, @(level, k) fixed(k));

    tol = 1e-3;                       % published values are 4 d.p.
    d = struct();
    d.result         = result;
    d.expected_mu    = 5.3922;
    d.expected_sigma = 1.0412;
    d.got_mu         = result.mu;
    d.got_sigma      = result.sigma;
    d.tol            = tol;
    d.is_match       = abs(result.mu - d.expected_mu) <= tol && ...
                       abs(result.sigma - d.expected_sigma) <= tol;
end

function record = run_loop(params, num_parts, outcome_fn, cfg)
%RUN_LOOP  Worker #8 â€” the conductor of the test.
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
            useful_interval=[];
            if est.stage==2
                physical_interactions=requested_levels(1:k-1);
                physical_interactions=physical_interactions(successes(1:k-1));
                physical_no_interactions=requested_levels(1:k-1);
                physical_no_interactions=physical_no_interactions(~successes(1:k-1));
                physical_hi_interaction=max(physical_interactions);
                physical_lo_no=min(physical_no_interactions);
                if physical_hi_interaction > physical_lo_no + tolerance
                    status='paused';
                    stop_reason='requested_outcome_order_conflict';
                    last_k=k-1;
                    fprintf([ ...
                        '  PAUSED - REVIEW REQUIRED: requested gaps and measured gaps\n' ...
                        '  give different outcome orderings. Completed data are kept.\n']);
                    break;
                end
                if physical_hi_interaction > physical_lo_no
                    shared_boundary=(physical_hi_interaction+physical_lo_no)/2;
                    physical_hi_interaction=shared_boundary;
                    physical_lo_no=shared_boundary;
                end
                useful_interval=[physical_hi_interaction,physical_lo_no];
            end
            [x, reachable_status] = select_reachable_request(x, ...
                cfg.reachable_model, requested_levels(1:k-1), allow_repeat, ...
                useful_interval);
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

        % Obtain the binary outcome. A physical operator path also returns one
        % measured gap for the newly built setup. That measurement is the level
        % used by the statistics; the requested setting remains traceable.
        response = outcome_fn(requested_x,k);
        if isstruct(response)
            if ~isfield(response,'outcome')
                error('run_loop:badPhysicalResponse', ...
                    'Physical response must contain an outcome.');
            end
            if ~isfield(response,'measurements')
                error('run_loop:badPhysicalResponse', ...
                    'Every new setup requires one measured gap.');
            end
            readings=response.measurements(:)';
            if ~(isnumeric(readings) && isscalar(readings) && ...
                    isreal(readings) && all(isfinite(readings)) && ...
                    all(readings >= 0))
                error('run_loop:badMeasurements', ...
                    'Provide exactly one finite, nonnegative measured gap.');
            end
            measured_x=readings;
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

function [result, record] = run_physical_test(params, num_parts, outcome_fn, cfg)
%RUN_PHYSICAL_TEST Run a gap test using an explicitly chosen usable resolution.
%
%   Physical mode deliberately has no default usable resolution. New callers
%   provide .usable_resolution; .level_increment remains accepted for older
%   scripts. Foil thickness never controls rounding or the sigma floor.
%   OUTCOME_FN must return a struct containing the binary .outcome and exactly
%   one finite, nonnegative .measurements value for that newly built setup. The
%   existing RUN_TEST entry point remains available for synthetic simulations.

    if nargin < 4 || ~isstruct(cfg)
        error('run_physical_test:badLevelIncrement', ...
            ['Physical testing requires a positive usable gap step ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    if isfield(cfg,'usable_resolution') && ~isempty(cfg.usable_resolution)
        usable_resolution=cfg.usable_resolution;
    elseif isfield(cfg,'level_increment') && ~isempty(cfg.level_increment)
        usable_resolution=cfg.level_increment;
    else
        usable_resolution=[];
    end
    if ~(isnumeric(usable_resolution) && isreal(usable_resolution) && ...
            isscalar(usable_resolution) && isfinite(usable_resolution) && ...
            usable_resolution > 0)
        error('run_physical_test:badLevelIncrement', ...
            ['Physical testing requires a positive usable gap step ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    has_reachable_model = isfield(cfg, 'reachable_model') && ...
        ~isempty(cfg.reachable_model);
    if ~has_reachable_model && ...
            abs(usable_resolution*100-round(usable_resolution*100)) > 1e-10
        error('run_physical_test:badUsableResolution', ...
            ['The usable gap step must support two-decimal build requests. ' ...
             'Foil thickness is separate construction information.']);
    end
    cfg.usable_resolution=usable_resolution;
    cfg.level_increment=usable_resolution;
    if nargin < 3 || ~isa(outcome_fn,'function_handle')
        error('run_physical_test:badOutcomeFn', ...
            'Physical testing requires an operator response function.');
    end
    % Physical mode uses the approved two-resolution Stage-2 protection.
    % Synthetic studies may compare other factors through RUN_TEST, but a
    % physical caller cannot silently weaken this rule.
    cfg.resolution_sigma_floor_factor = 2;

    [result, record] = run_test(params, num_parts, @physical_response, cfg);
    record.resolution_sigma_floor_factor = cfg.resolution_sigma_floor_factor;
    record.usable_resolution = usable_resolution;
    if isfield(cfg,'foil_thickness')
        record.foil_thickness=cfg.foil_thickness;
    else
        record.foil_thickness=[];
    end
    record.resolution_sigma_floor = usable_resolution * ...
        cfg.resolution_sigma_floor_factor;
    record.measurement_count=ones(numel(record.measurements),1);
    result.raw_requested_levels=record.raw_requested_levels;
    result.requested_levels=record.requested_levels;
    result.requested_instructions=record.requested_instructions;
    result.measurements=record.measurements;
    result.usable_resolution=record.usable_resolution;
    result.foil_thickness=record.foil_thickness;
    result.resolution_sigma_floor_factor=record.resolution_sigma_floor_factor;
    result.resolution_sigma_floor=record.resolution_sigma_floor;
    result.measurement_count=record.measurement_count;
    result.checkpoint_decisions=record.checkpoint_decisions;

    function response = physical_response(gap, k)
        response = outcome_fn(gap, k);
        if ~isstruct(response) || ~isfield(response,'measurements')
            error('run_physical_test:measurementsRequired', ...
                ['Physical testing requires an outcome and exactly one ' ...
                 'measured gap for every new spacer build.']);
        end
    end
end

function [result, record] = run_test(params, num_parts, outcome_fn, cfg)
%RUN_TEST  The only entry point: check -> run -> report.
%
%   [result, record] = RUN_TEST(params, num_parts, outcome_fn, cfg) runs a Neyer
%   D-optimal sensitivity test end to end. It is pure glue: it validates the
%   inputs (worker #7), runs the loop (worker #8), and reports the answer
%   (worker #9).  [brief sec.5]
%
%   Inputs
%     params      starting guess: .avg_low, .avg_high, .spread_guess.
%     num_parts   item budget (number of destructive tests).
%     outcome_fn  (optional) result = outcome_fn(level, k): true for interaction,
%                 false for no interaction. If omitted, the operator is prompted at
%                 the console for each item.
%     cfg         (optional) settings struct; defaults to settings().
%
%   Outputs
%     result   struct from report (.mu, .sigma, .se_mu, .se_sigma, ...).
%     record   struct from run_loop (the full trajectory).
%
%   Example (reproduce Neyer Table 1):
%     fixed  = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
%     params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
%     run_test(params, 20, @(level,k) fixed(k));


    if nargin < 4 || isempty(cfg),        cfg = neyer_settings();          end
    if nargin < 3 || isempty(outcome_fn), outcome_fn = @ask_operator; end

    check_inputs(params, num_parts);               % #7
    % Adapter: the user builds params with plain-English field names; convert to
    % the internal names the sacred core (choose_stage) expects, untouched.
    internal = struct('mu_min', params.avg_low, 'mu_max', params.avg_high, ...
                      'sigma_guess', params.spread_guess);
    record = run_loop(internal, num_parts, outcome_fn, cfg);   % #8; choose_stage still sees mu_min/mu_max/sigma_guess
    result = report(record, cfg);                  % #9
end

% -------------------------------------------------------------------------
function r = ask_operator(level, k)
%ASK_OPERATOR  Default interactive outcome source: prompt the operator.
    prompt = sprintf('Test %d - set gap to %.4f. Interaction? (1=yes / 0=no): ', ...
                     k, level);
    r = logical(input(prompt));
end

function result = run_test_ui(cfg0, loaded_plan)
%RUN_TEST_UI  Run a Neyer test through large, readable pop-up windows (MATLAB
%   desktop only): settings, then the reachable gap, one measured gap, and
%   interaction outcome for each test. Physical validation lives in
%   parse_run_inputs and run_physical_test.
    if ~(isdeployed || usejava('desktop'))
        error('run_test_ui:noDisplay', ...
              'run_test_ui needs the MATLAB desktop; in a script use run_test instead.');
    end
    if nargin < 2, loaded_plan = []; end
    parsed = ask_settings_ui(loaded_plan);
    if isempty(parsed), fprintf('run_test_ui: cancelled.\n'); result = []; return; end
    if nargin >= 1 && ~isempty(cfg0)
        parsed.cfg = apply_run_configuration_overrides(parsed.cfg, cfg0);
    end
    try
        result = run_physical_test(parsed.params, parsed.num_parts, ...
            @(level,k)gap_popup(level,k,parsed.num_parts, ...
                reachable_model_or_empty(parsed.cfg)), ...
                parsed.cfg);
    catch e
        if strcmp(e.identifier, 'run_test_ui:aborted')
            fprintf('run_test_ui: cancelled during testing.\n'); result = []; return;
        end
        rethrow(e);
    end
    try
        if ~isempty(loaded_plan)
            result.study_plan = loaded_plan;
            if isfield(result, 'checkpoint_decisions') && ...
                    ~isempty(result.checkpoint_decisions)
                result.checkpoint_decision = result.checkpoint_decisions{end};
            else
                result.checkpoint_decision = check_study_checkpoint( ...
                    result, loaded_plan, 'main');
            end
        end
        show_result(result);
    catch result_error
        warning('run_test_ui:resultDisplayFailed', ...
            'The tests finished, but the results window did not open: %s', ...
            result_error.message);
        show_result_error_notice(result_error);
    end

end

% =================================================================================
function parsed = ask_settings_ui(loaded_plan)
%ASK_SETTINGS_UI  Large, readable settings window. Returns a parsed struct or [].
    labels = {'Low guess for the middle gap (mm):', ...
              'High guess for the middle gap (mm):', ...
              'Rough guess of the overall variation (mm):', ...
              'Maximum allowed number of destructive tests:', ...
              'Minimum permitted gap (mm):', ...
              'Maximum permitted gap (mm):', ...
              'Gap unit:', ...
              'Usable gap step for this study (mm):', ...
              'Approximate foil thickness (mm, information only):'};
    defs = {'0','10','1','20','0','10','mm','0.05','0.015'};
    planned_message = [ ...
        'No Pre-Test Planner is used. The article number is the maximum ' ...
        'allowed, not a confidence-based stopping promise.'];
    if nargin >= 1 && ~isempty(loaded_plan)
        if all(isfield(loaded_plan, {'interaction_gap_mm', ...
                'no_interaction_gap_mm', 'estimated_sigma_mm', ...
                'main_articles', 'minimum_gap_mm'}))
            defs{1} = sprintf('%.6g', loaded_plan.interaction_gap_mm);
            defs{2} = sprintf('%.6g', loaded_plan.no_interaction_gap_mm);
            defs{3} = sprintf('%.6g', loaded_plan.estimated_sigma_mm);
            defs{4} = sprintf('%d', loaded_plan.main_articles);
            defs{5} = sprintf('%.6g', loaded_plan.minimum_gap_mm);
            planned_message = sprintf('Planned checkpoint: Main study - %d articles', ...
                loaded_plan.main_articles);
            if isfield(loaded_plan, 'maximum_gap_mm')
                defs{6} = sprintf('%.6g', loaded_plan.maximum_gap_mm);
            end
            defs{8} = sprintf('%.6g', usable_resolution_for_plan( ...
                loaded_plan, str2double(defs{8})));
        end
    end

    fig = uifigure('Name', 'Neyer gap test - inputs', 'Position', [280 45 720 750]);
    gl  = uigridlayout(fig, [11 2]);
    gl.RowHeight     = {70, 46, 46, 46, 46, 46, 46, 46, 46, 46, 54};
    gl.ColumnWidth   = {'1x', 190};
    gl.Padding       = [28 24 28 24];
    gl.RowSpacing    = 12;
    gl.ColumnSpacing = 16;

    ttl = uilabel(gl, 'Text', ['Run a Test directly  |  ' planned_message], ...
        'FontSize', 17, 'FontWeight', 'bold', 'WordWrap', 'on');
    ttl.Layout.Row = 1; ttl.Layout.Column = [1 2];

    edits = gobjects(1, 9);
    for i = 1:9
        lb = uilabel(gl, 'Text', labels{i}, 'FontSize', 15, 'WordWrap', 'on');
        lb.Layout.Row = i + 1; lb.Layout.Column = 1;
        edits(i) = uieditfield(gl, 'text', 'Value', defs{i}, 'FontSize', 16);
        edits(i).Layout.Row = i + 1; edits(i).Layout.Column = 2;
    end

    bp = uigridlayout(gl, [1 2]);
    bp.Layout.Row = 11; bp.Layout.Column = [1 2];
    bp.ColumnWidth = {'1x', '1x'}; bp.Padding = [0 6 0 0]; bp.ColumnSpacing = 16;
    uibutton(bp, 'Text', 'Start test', 'FontSize', 16, 'FontWeight', 'bold', ...
             'BackgroundColor', [0.20 0.42 0.40], 'FontColor', [1 1 1], ...
             'ButtonPushedFcn', @(~,~) startTest());
    uibutton(bp, 'Text', 'Cancel', 'FontSize', 16, 'ButtonPushedFcn', @(~,~) cancelTest());

    store = struct('parsed', []);
    fig.CloseRequestFcn = @(~,~) cancelTest();
    uiwait(fig);
    parsed = store.parsed;
    if isvalid(fig), delete(fig); end

    function startTest()
        answers = cell(1, 9);
        for j = 1:9, answers{j} = edits(j).Value; end
        try
            store.parsed = parse_run_inputs(answers);
            if ~isempty(loaded_plan)
                store.parsed.loaded_plan = loaded_plan;
                store.parsed.num_parts = loaded_plan.total_articles;
                store.parsed.cfg.study_plan = loaded_plan;
                store.parsed.cfg.reserve_decision_fn = @ask_reserve_ui;
                if isfield(loaded_plan, 'maximum_gap_mm')
                    store.parsed.cfg.max_level = loaded_plan.maximum_gap_mm;
                end
                if isfield(loaded_plan, 'reachable_model')
                    store.parsed.cfg.reachable_model = loaded_plan.reachable_model;
                end
            end
            uiresume(fig);
        catch e
            uialert(fig, e.message, 'Please fix your inputs');
        end
    end
    function cancelTest()
        store.parsed = [];
        uiresume(fig);
    end
end

function approved = ask_reserve_ui(decision)
%ASK_RESERVE_UI Obtain explicit permission before consuming a reserve group.
    prompt_figure = uifigure('Name', 'Study checkpoint', ...
        'Position', [420 260 520 230], 'Visible', 'on');
    cleanup_figure = onCleanup(@() delete_if_valid(prompt_figure));
    missing_text = strjoin(cellstr(decision.missing_conditions), newline);
    choice = uiconfirm(prompt_figure, sprintf([ ...
        '%s\n\nWhat is still missing:\n%s\n\nUse %s now?'], ...
        decision.plain_explanation, missing_text, ...
        strrep(decision.next_checkpoint, '_', ' ')), ...
        'Planned checkpoint', ...
        'Options', {'Use this reserve group', 'Stop and review'}, ...
        'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
    approved = strcmp(choice, 'Use this reserve group');
    clear cleanup_figure;
end

function delete_if_valid(figure_handle)
    if isvalid(figure_handle), delete(figure_handle); end
end

function show_result_error_notice(result_error)
    try
        notice = uifigure('Name', 'Neyer result notice', ...
            'Position', [460 300 520 180]);
        message = sprintf([ ...
            'The tests finished, but the results window could not open.\n\n' ...
            'Return to the main menu and select Review latest results.\n\n' ...
            'Reason: %s'], result_error.message);
        uialert(notice, message, 'Results not shown', 'Icon', 'warning', ...
            'CloseFcn', @(~, ~) delete_if_valid(notice));
    catch notice_error
        warning('run_test_ui:resultNoticeFailed', ...
            'The result notice could not open: %s', notice_error.message);
    end
end

% =================================================================================
function response = gap_popup(level, k, N, reachable_model)
%GAP_POPUP Show one reachable setting and collect its physical result.
    if nargin < 4, reachable_model = []; end
    fig = uifigure('Name', 'Neyer gap test', 'Position', [300 170 650 440]);
    gl  = uigridlayout(fig, [5 2]);
    gl.RowHeight     = {'fit', 90, 54, 54, 64};
    gl.ColumnWidth   = {'1x', '1x'};
    gl.Padding       = [30 24 30 24];
    gl.RowSpacing    = 16;
    gl.ColumnSpacing = 16;

    l1 = uilabel(gl, 'Text', sprintf('Test %d of %d', k, N), ...
                 'FontSize', 16, 'FontColor', [0.38 0.38 0.38], 'HorizontalAlignment', 'center');
    l1.Layout.Row = 1; l1.Layout.Column = [1 2];
    requested_text = format_requested_gap(level,'mm');
    if ~isempty(reachable_model)
        [distance, recipe_row] = min(abs(reachable_model.gaps_mm(:) - level));
        if distance <= reachable_model.comparison_tolerance_mm
            requested_text = sprintf('%s\n%s', requested_text, ...
                char(reachable_model.instructions(recipe_row)));
        end
    end
    l2 = uilabel(gl, 'Text', requested_text, ...
                 'FontSize', 22, 'FontWeight', 'bold', 'WordWrap', 'on', 'HorizontalAlignment', 'center');
    l2.Layout.Row = 2; l2.Layout.Column = [1 2];

    prompt=uilabel(gl,'Text','Enter the measured gap:', ...
        'FontSize',15,'HorizontalAlignment','right');
    prompt.Layout.Row=3; prompt.Layout.Column=1;
    reading_edit=uieditfield(gl,'text','FontSize',16, ...
        'Placeholder','Example: 2.507');
    reading_edit.Layout.Row=3; reading_edit.Layout.Column=2;
    note_text=['Measure this new setup once. That measured gap will be used ' ...
        'in the calculation.'];
    note=uilabel(gl,'Text',note_text,'FontSize',14,'WordWrap','on', ...
        'HorizontalAlignment','center');
    note.Layout.Row=4; note.Layout.Column=[1 2];

    store = struct('response', []);
    bI = uibutton(gl, 'Text', 'Interaction', 'FontSize', 18, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.80 0.45 0.38], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) submitResult(true));
    bI.Layout.Row = 5; bI.Layout.Column = 1;
    bN = uibutton(gl, 'Text', 'No interaction', 'FontSize', 18, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.30 0.55 0.42], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) submitResult(false));
    bN.Layout.Row = 5; bN.Layout.Column = 2;

    fig.CloseRequestFcn = @(~,~) cancelResult();
    uiwait(fig);
    response = store.response;
    if isvalid(fig), delete(fig); end
    if isempty(response), error('run_test_ui:aborted', 'cancelled by operator.'); end

    function submitResult(outcome)
        try
            store.response=parse_physical_response(reading_edit.Value,outcome);
        catch e
            uialert(fig,e.message,'Please check the measurements');
            return;
        end
        uiresume(fig);
    end
    function cancelResult()
        store.response=[];
        uiresume(fig);
    end
end

function model = reachable_model_or_empty(cfg)
    if isfield(cfg, 'reachable_model')
        model = cfg.reachable_model;
    else
        model = [];
    end
end

function [mu_c, sigma_c] = sanity_clamp(mu, sigma, levels, cfg)
%SANITY_CLAMP  Worker #5 â€” rein in wild best-fits on few results.
%
%   [mu_c, sigma_c] = SANITY_CLAMP(mu, sigma, levels, cfg) keeps an estimate
%   physically sensible when only a handful of results are in:
%     * the average is kept inside the range of levels actually tested, and
%     * the spread is kept no wider than that range (max - min tested level).
%   [brief sec.4 worker #5; sec.6 (both MLE clips); sec.8 #3 -- Neyer specifies
%   exactly this]
%
%   Inputs
%     mu, sigma  the raw best-fit (e.g. straight from worker #2).
%     levels     the test levels run so far (defines the sensible range).
%     cfg        settings struct (optional; defaults to settings()). Honours
%                cfg.clip_mu_to_tested_range and cfg.clip_sigma_to_tested_range
%                so each clip can be turned off independently.
%
%   Outputs
%     mu_c, sigma_c  the clamped estimate.
%
%   Example (acceptance table, going into test 12): the raw MLE from tests
%   1..11 is mu=4.2995, sigma=0.1932; the tested range is [1.00, 4.28], so mu
%   clamps to 4.28 and sigma is left as 0.19 -- the table's "clipped MLE".

    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end

    levels = levels(:);

    mu_c    = mu;
    sigma_c = sigma;

    if isempty(levels)
        return;   % nothing tested yet -> no range to clamp against
    end

    lo  = min(levels);
    hi  = max(levels);
    rng = hi - lo;

    % Average kept within the tested level range.
    if cfg.clip_mu_to_tested_range
        mu_c = min(max(mu, lo), hi);
    end

    % Spread kept no wider than the tested range (only meaningful if the
    % levels actually span a range; a positive spread is never clamped to 0).
    if cfg.clip_sigma_to_tested_range && rng > 0
        sigma_c = min(sigma, rng);
    end
end

function paths = save_results_files(base, csv_text, html_text)
%SAVE_RESULTS_FILES  Write CSV + HTML report text to <base>.csv / <base>.html.
%   paths = SAVE_RESULTS_FILES(base, csv_text, html_text) writes the two files
%   next to each other, sharing the base name the user chose. Returns a struct
%   with .csv and .html full paths. Existing files are never replaced.
%   Base-MATLAB file IO. [compiled-app]
    paths = result_output_paths(base);
    existing = {};
    if isfile(paths.csv), existing{end+1} = paths.csv; end %#ok<AGROW>
    if isfile(paths.html), existing{end+1} = paths.html; end %#ok<AGROW>
    if ~isempty(existing)
        error('save_results_files:alreadyExists', ...
            ['Nothing was saved because this file already exists:\n%s\n\n' ...
             'Choose a different name so no earlier result is replaced.'], ...
            strjoin(existing, newline));
    end
    write_text(paths.csv,  csv_text);
    write_text(paths.html, html_text);
end

function write_text(p, txt)
    fid = fopen(p, 'w');
    if fid < 0, error('save_results_files:cannotWrite', 'Cannot write %s', p); end
    fwrite(fid, txt);
    fclose(fid);
end

function saved_path = save_study_plan(plan, selected_path)
%SAVE_STUDY_PLAN Save a human-readable study plan without replacing a file.
% The caller chooses the complete destination. The exact path is returned so
% the interface can show where the plan was saved.

    if ~isstruct(plan) || ~all(isfield(plan, {'schema_version', 'mode', ...
            'outcome', 'main_articles', 'reserve_1_articles', ...
            'reserve_2_articles', 'total_articles', 'reachable_model', ...
            'reliability_validation_floor_articles', ...
            'reliability_instruction_supported', ...
            'reliability_instruction_status'}))
        error('save_study_plan:badPlan', ...
            'The study plan is incomplete and cannot be saved.');
    end
    [safe_plan, safety_message] = validate_study_plan_safety(plan);
    if ~safe_plan
        error('save_study_plan:badPlan', ...
            'The study plan cannot be saved safely: %s', safety_message);
    end
    saved_path = absolute_save_path(selected_path);
    [folder, ~, extension] = fileparts(saved_path);
    if ~strcmpi(extension, '.json')
        error('save_study_plan:badExtension', ...
            'Choose a filename ending in .json for the study plan.');
    end
    if ~isfolder(folder)
        error('save_study_plan:folderNotFound', ...
            'The selected save folder does not exist: %s', folder);
    end
    if isfile(saved_path)
        error('save_study_plan:alreadyExists', ...
            ['A file already exists at this location. Choose a new name; ' ...
             'the existing plan was not replaced: %s'], saved_path);
    end

    saved_plan = plan;
    saved_plan.saved_at = char(datetime('now', 'TimeZone', 'local'), ...
        'yyyy-MM-dd HH:mm:ss Z');
    try
        json_text = jsonencode(saved_plan, 'PrettyPrint', true);
    catch encode_error
        error('save_study_plan:encodeFailed', ...
            'The study plan could not be converted to JSON: %s', ...
            encode_error.message);
    end

    file_id = fopen(saved_path, 'wt', 'n', 'UTF-8');
    if file_id < 0
        error('save_study_plan:cannotOpen', ...
            'MATLAB could not create the selected plan file: %s', saved_path);
    end
    try
        written_count = fprintf(file_id, '%s\n', json_text);
        if written_count < strlength(string(json_text))
            error('save_study_plan:writeFailed', ...
                'MATLAB could not finish writing the selected plan file.');
        end
        fclose(file_id);
        file_id = -1;
    catch write_error
        if file_id >= 0
            fclose(file_id);
        end
        if isfile(saved_path)
            delete(saved_path);
        end
        if startsWith(write_error.identifier, 'save_study_plan:')
            rethrow(write_error);
        end
        error('save_study_plan:writeFailed', ...
            'MATLAB could not finish writing the selected plan file: %s', ...
            write_error.message);
    end
end

function path = absolute_save_path(selected_path)
    if isstring(selected_path) && isscalar(selected_path)
        path = char(selected_path);
    elseif ischar(selected_path) && isrow(selected_path)
        path = selected_path;
    else
        error('save_study_plan:badPath', ...
            'Choose one complete filename for the study plan.');
    end
    path = strtrim(path);
    if isempty(path)
        error('save_study_plan:badPath', ...
            'Choose one complete filename for the study plan.');
    end
    is_windows_absolute = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
    is_unc = startsWith(path, '\\');
    if ~(is_windows_absolute || is_unc)
        path = fullfile(pwd, path);
    end
end

function [requested_gap_mm, status] = select_reachable_request( ...
        raw_gap_mm, reachable_model, previous_requested_gaps, allow_repeat, ...
        strict_outside_interval)
%SELECT_REACHABLE_REQUEST Choose the nearest different buildable test gap.
% This is for sequential Neyer requests, where the outcome is not known yet.
% Direction-safe operating-limit rounding is handled separately.

    if nargin < 3 || isempty(previous_requested_gaps)
        previous_requested_gaps = zeros(0, 1);
    end
    if nargin < 4, allow_repeat = false; end
    if nargin < 5, strict_outside_interval = []; end
    if ~(isscalar(raw_gap_mm) && isnumeric(raw_gap_mm) && isreal(raw_gap_mm) && ...
            isfinite(raw_gap_mm))
        error('select_reachable_request:badGap', ...
            'The requested mathematical gap must be one finite number.');
    end
    if ~isstruct(reachable_model) || ~all(isfield(reachable_model, ...
            {'gaps_mm', 'instructions', 'comparison_tolerance_mm'}))
        error('select_reachable_request:badModel', ...
            'A reachable physical-gap model is required.');
    end
    candidates = reachable_model.gaps_mm(:);
    allowed = true(size(candidates));
    tolerance = reachable_model.comparison_tolerance_mm;
    if ~isempty(strict_outside_interval)
        if ~(isnumeric(strict_outside_interval) && ...
                numel(strict_outside_interval)==2 && ...
                all(isfinite(strict_outside_interval)) && ...
                strict_outside_interval(1) <= strict_outside_interval(2))
            error('select_reachable_request:badUsefulInterval', ...
                'The useful-setting interval must contain two ordered finite gaps.');
        end
        hi_interaction=strict_outside_interval(1);
        lo_no=strict_outside_interval(2);
        allowed = allowed & (candidates < hi_interaction-tolerance | ...
            candidates > lo_no+tolerance);
    end
    if ~allow_repeat && ~isempty(previous_requested_gaps)
        % Avoid an immediate duplicate request, but permit returning to an
        % older useful gap with a new independent article.
        previous_gap_mm = previous_requested_gaps(end);
        allowed = allowed & abs(candidates - previous_gap_mm) > tolerance;
    end
    rows = find(allowed);
    if isempty(rows)
        requested_gap_mm = NaN;
        status = struct('code', 'no_different_gap', ...
            'message', ['No different reachable and useful gap remains. Review the ' ...
                'physical gap capability before continuing the destructive study.'], ...
            'raw_gap_mm', raw_gap_mm, 'requested_gap_mm', NaN, ...
            'display_gap', "Not established", 'instruction', "");
        return;
    end
    [~, nearest_position] = min(abs(candidates(rows) - raw_gap_mm));
    chosen_row = rows(nearest_position);
    requested_gap_mm = candidates(chosen_row);
    status = struct('code', 'ok', ...
        'message', 'The nearest different reachable gap was selected.', ...
        'raw_gap_mm', raw_gap_mm, ...
        'requested_gap_mm', requested_gap_mm, ...
        'display_gap', string(sprintf('%.2f mm', requested_gap_mm)), ...
        'instruction', reachable_model.instructions(chosen_row));
end

function [gap_mm, status] = select_operating_gap(raw_boundary_mm, outcome, model)
%SELECT_OPERATING_GAP Add one reachable physical step in the safe direction.
% The confidence boundary is first rounded in the safe direction. The final
% instruction then moves to the next reachable setting in that same direction
% to protect a newly built setup from small build-to-build differences.

    [first_safe_gap, first_status] = round_reachable_gap( ...
        raw_boundary_mm, outcome, model, []);
    if ~strcmp(first_status.code, 'ok')
        gap_mm = NaN;
        status = first_status;
        return;
    end

    [gap_mm, status] = round_reachable_gap(raw_boundary_mm, outcome, ...
        model, first_safe_gap);
    if ~strcmp(status.code, 'ok')
        gap_mm = NaN;
        status.code = 'no_buffered_setting';
        status.message = [ ...
            'The confidence boundary can be rounded, but no extra reachable ' ...
            'setting remains in the safe direction. No operating instruction is shown.'];
        status.display_gap = "Not established";
        status.instruction = "";
        return;
    end
    status.message = [ ...
        'One extra reachable setting was added in the safe direction to ' ...
        'protect against differences in a newly built spacer setup.'];
end

function s = shape_model(x, mu, sigma)
%SHAPE_MODEL  Worker #1 â€” the bell curve (the ONLY place the shape lives).
%
%   s = SHAPE_MODEL(x, mu, sigma) evaluates the assumed response shape at one
%   or more physical gaps x, for interaction thresholds that follow a bell
%   curve (normal distribution) with middle gap mu and width sigma.
%
%   It returns the interaction chance at each gap, plus the standard-normal
%   building blocks every other worker needs (z, phi, Phi, Q). Because the
%   shape assumption is quarantined here, swapping the bell curve for another
%   shape (e.g. the logistic) is a single-file change.  [brief sec.4, worker #1]
%
%   Alternate call (inverse):  z = SHAPE_MODEL(p, 'quantile')  goes the other
%   way -- given a probability p in (0,1), it returns how many spreads from the
%   centre that interaction chance sits at (the z with Phi(z) = p). report (#9) uses
%   this to turn a strictness like 99.9% into an all-fire / no-fire level. See
%   the "Inverse (quantile) mode" block below.  [addendum B1]
%
%   Inputs
%     x      physical gap(s); scalar or array of any shape.
%     mu     middle gap, where interaction chance is 50%, scalar.
%     sigma  overall variation, scalar, must be > 0.
%
%   Output struct s, every field the same size as x:
%     s.z    standardised gap, z = (mu - x) / sigma
%     s.phi  standard-normal pdf at z, phi(z)                   [brief App.A]
%     s.Phi  standard-normal cdf at z = P(interaction)
%     s.Q    upper tail, Q(z) = 1 - Phi(z) = P(no interaction)
%     s.p    probability of interaction at this gap = s.Phi
%
%   Source: normal distribution is PAPER (Neyer 1994); the pdf/cdf are their
%   standard mathematical definitions. Phi and Q are computed separately via
%   erfc rather than as 1 - Phi, so both tails stay accurate far from centre
%   (relevant to numerical hazard #1 in the brief, sec.8).

    % --- Inverse (quantile) mode: z = shape_model(p, 'quantile') ----------
    % Given a probability p in (0,1), return the standardised level z with
    % Phi(z) = p. This is the exact inverse of the forward Phi computed below,
    % so ALL bell-curve maths stays in this one file (the shape swap-point).
    % erfinv is a base function in both Octave and MATLAB (no toolbox).
    % Used by report (#9) to turn a strictness like 99.9% into a distance.
    % [addendum B1; RECOMMENDATION for the one-file route]
    if nargin == 2 && ischar(mu)
        if ~strcmpi(mu, 'quantile')
            error('shape_model:badMode', ...
                  'Unknown mode "%s"; the only extra mode is ''quantile''.', mu);
        end
        p = x;
        if ~isreal(p) || any(~isfinite(p(:))) || any(p(:) <= 0) || any(p(:) >= 1)
            error('shape_model:badProb', ...
                  'quantile probability must be real and strictly inside (0,1).');
        end
        s = sqrt(2) .* erfinv(2 .* p - 1);     % z such that Phi(z) = p
        return;
    end

    % Spread must be positive â€” z divides by it. Defensive guard; full input
    % validation is worker #7 (check_inputs).  [brief sec.8 item 4]
    if ~(isscalar(mu) && isscalar(sigma))
        error('shape_model:scalarParams', 'mu and sigma must be scalars.');
    end
    if ~(sigma > 0) || ~isfinite(sigma)
        error('shape_model:badSigma', 'sigma must be a finite positive number.');
    end

    % Gap model: interaction becomes less likely as the gap increases.
    z = (mu - x) ./ sigma;

    % Standard-normal pdf:  phi(z) = exp(-z^2/2) / sqrt(2*pi)
    phi = exp(-0.5 .* z.^2) ./ sqrt(2*pi);

    % Standard-normal cdf and upper tail, each from erfc for tail accuracy:
    %   Phi(z) = 0.5 * erfc(-z / sqrt(2))
    %   Q(z)   = 0.5 * erfc( z / sqrt(2))
    r2  = sqrt(2);
    Phi = 0.5 .* erfc(-z ./ r2);
    Q   = 0.5 .* erfc( z ./ r2);

    s = struct('z', z, 'phi', phi, 'Phi', Phi, 'Q', Q, 'p', Phi);
end

function show_manual()
%SHOW_MANUAL Show the embedded gap-study operator guide.
    f=uifigure('Name','Neyer Gap Test - Help','Position',[340 180 720 620]);
    gl=uigridlayout(f,[1 1]); gl.Padding=[10 10 10 10];
    ta=uitextarea(gl,'Value',manual_lines(),'Editable','off');
    ta.FontName='Consolas';
end

function lines=manual_lines()
    lines={
      'NEYER GAP TEST - OPERATOR GUIDE'
      ''
      'PURPOSE'
      'This tool estimates how interaction changes as the physical gap changes.'
      'Smaller gaps make interaction more likely. Larger gaps make it less likely.'
      'The main results are the middle gap (about 50% interaction) and the'
      'overall variation (how gradual or sudden that change is).'
      ''
      'BEFORE STARTING'
      '- Enter low and high guesses for the middle gap.'
      '- Enter a rough overall-variation guess.'
      '- Enter the number of destructive tests available.'
      '- Enter the permitted minimum gap and the usable gap step for this study.'
      '- Foil thickness is construction information; it does not set the safety floor.'
      '- Foil recipes are unavailable until measured stacks and a practical layer limit are confirmed.'
      '- Use 0 to 10 mm as the study boundaries unless the approved setup changes.'
      ''
      'FOR EVERY TEST'
      '1. Build a new spacer setup at the requested reachable gap.'
      '2. Measure the completed setup once.'
      '3. Enter that measured gap; it is used by the statistical calculation.'
      '4. Perform one test and select Interaction or No interaction.'
      '5. The spacer setup is not reused after the destructive test.'
      ''
      'IMPORTANT DISTINCTION'
      'The requested build gap is always shown with two decimal places.'
      'The one measured gap is the actual gap used in the statistical model.'
      'If the same reachable gap is requested again, build and measure a new setup.'
      'The Stage-2 planning width cannot fall below two usable gap steps.'
      ''
      'BOUNDARY PROTECTION'
      'An unexpected outcome at 0 or 10 mm is repeated once for confirmation.'
      'If it happens twice, the study pauses and saves the data for review.'
      'A boundary pause does not mean that the specimen test failed.'
      ''
      'READING THE RESULTS'
      '- Middle gap: the estimated gap with about 50% interaction chance.'
      '- Overall variation: how much the full tested process varies around the middle.'
      '- High-interaction gap: a smaller-gap reliability point.'
      '- Negligible-interaction gap: a larger-gap reliability point.'
      '- Values outside 0 to 10 mm are outside the tested range, not build settings.'
      ''
      'CONFIDENCE AND PROBABILITY'
      'Probability describes the expected outcome at a gap.'
      'Confidence describes how certain the estimate is from the available data.'
      'These are different quantities and should be reported separately.'
      ''
      'RECORDED SUPPORT LIMITS'
      '- The main study can estimate the middle gap and overall variation.'
      '- A safety-supported reliability setting needs at least 400 independent articles.'
      '- Reserve articles are used only after the user approves each checkpoint.'
      '- Confidence of 50% or less is exploratory; no supported setting is issued.'
      '- Confidence above 95% can be calculated but is outside recorded validation.'
      ''
      'SELF-CHECK'
      'Run the published example. It must report middle 5.3922 and overall variation 1.0412 - MATCH.'
      ''
      'Method: Neyer (1994) D-optimal sensitivity test.'
    };
end

function h = show_result(result)
%SHOW_RESULT Decision-first results window with two complementary charts.
% The bell-shaped chart explains article-to-article variation. The probability
% chart answers how interaction chance changes as the physical gap changes.

    if ~(isdeployed || usejava('desktop'))
        error('show_result:noDisplay', 'The results window needs the MATLAB desktop.');
    end

    unit = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit)
        unit = char(string(result.unit));
    end
    has_estimate = isfield(result, 'has_overlap') && result.has_overlap && ...
        isfield(result, 'mu') && isfinite(result.mu);
    decision = result_decision_summary(result);

    confidence = 0.95;
    if isfield(result, 'confidence_level') && isfinite(result.confidence_level)
        confidence = result.confidence_level;
    end

    h = uifigure('Name', 'Neyer gap-study results', ...
        'Position', [60 50 1240 760], 'Color', [0.96 0.97 0.97]);
    layout = uigridlayout(h, [3 3]);
    layout.RowHeight = {118, '1x', 190};
    layout.ColumnWidth = {340, '1x', '1x'};
    layout.Padding = [14 14 14 14];
    layout.RowSpacing = 10;
    layout.ColumnSpacing = 10;

    decisionPanel = uipanel(layout, 'Title', 'Decision', 'FontWeight', 'bold');
    decisionPanel.Layout.Row = 1;
    decisionPanel.Layout.Column = [1 3];
    if decision.supported
        decisionPanel.BackgroundColor = [0.91 0.97 0.93];
        decisionTitle = 'Supported operating instruction';
        decisionText = decision.operating_instruction;
        if strlength(decision.physical_build_instruction) > 0
            decisionText = sprintf('%s\nPhysical build: %s', decisionText, ...
                decision.physical_build_instruction);
        end
        decisionColor = [0.10 0.38 0.20];
    else
        decisionPanel.BackgroundColor = [1.00 0.96 0.87];
        decisionTitle = 'Supported operating instruction: Not established';
        decisionText = decision.explanation;
        decisionColor = [0.52 0.31 0.06];
    end
    decisionLayout = uigridlayout(decisionPanel, [2 1]);
    decisionLayout.RowHeight = {32, '1x'};
    decisionLayout.Padding = [12 4 12 8];
    uilabel(decisionLayout, 'Text', decisionTitle, 'FontSize', 19, ...
        'FontWeight', 'bold', 'FontColor', decisionColor);
    uilabel(decisionLayout, 'Text', decisionText, 'FontSize', 12, ...
        'WordWrap', 'on', 'FontColor', [0.18 0.22 0.24]);

    factsPanel = uipanel(layout, 'Title', 'What the fitted result means', ...
        'FontWeight', 'bold');
    factsPanel.Layout.Row = 2;
    factsPanel.Layout.Column = 1;
    if has_estimate
        gA = uigridlayout(factsPanel, [9 1]);
        gA.RowHeight   = {54, 30, 42, 30, 8, 55, 74, '1x', 4};
        gA.Padding = [10 10 10 8];
        gA.RowSpacing = 3;
        uilabel(gA, 'Text', sprintf( ...
            'Middle gap (about 50%% interaction): %.2f %s', result.mu, unit), ...
            'FontSize', 17, 'FontWeight', 'bold', 'WordWrap', 'on');
        uilabel(gA, 'Text', format_confidence_range(confidence, ...
            result.mu_lo, result.mu_hi, unit), ...
            'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', sprintf('Overall variation: %.2f %s', ...
            result.sigma, unit), 'FontSize', 16, 'FontWeight', 'bold');
        uilabel(gA, 'Text', format_confidence_range(confidence, ...
            result.sigma_lo, result.sigma_hi, unit), ...
            'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', '');
        uilabel(gA, 'Text', [ ...
            'Overall variation describes how much the entire tested process ' ...
            'varies from article to article around the middle gap.'], ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.25 0.30 0.32]);
        uilabel(gA, 'Text', [ ...
            'Important: the middle gap is a 50/50 estimate. It is not the ' ...
            'reliable operating gap shown in the decision above.'], ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.52 0.31 0.06]);
        uilabel(gA, 'Text', sprintf([ ...
            'Direction: smaller gaps make Interaction more likely; larger ' ...
            'gaps make No interaction more likely. Based on %d tests.'], ...
            result.n), 'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', '');
    else
        gA = uigridlayout(factsPanel, [1 1]);
        uilabel(gA, 'Text', [ ...
            'No fitted middle gap has been established from these results. ' ...
            'Both outcomes must occur close enough to show the change. You ' ...
            'can still save every completed test and review it later.'], ...
            'FontSize', 15, 'FontWeight', 'bold', 'WordWrap', 'on');
    end

    distributionAxes = uiaxes(layout);
    distributionAxes.Layout.Row = 2;
    distributionAxes.Layout.Column = 2;
    probabilityAxes = uiaxes(layout);
    probabilityAxes.Layout.Row = 2;
    probabilityAxes.Layout.Column = 3;
    if has_estimate
        try
            compactSettings = neyer_settings();
            compactSettings.compact = true;
            draw_distribution(distributionAxes, result, compactSettings);
        catch
            title(distributionAxes, 'Variation chart unavailable');
        end
        try
            curveSettings = neyer_settings();
            if isfield(result, 'study_plan') && isstruct(result.study_plan)
                if isfield(result.study_plan, 'minimum_gap_mm')
                    curveSettings.min_level = result.study_plan.minimum_gap_mm;
                end
                if isfield(result.study_plan, 'maximum_gap_mm')
                    curveSettings.max_level = result.study_plan.maximum_gap_mm;
                end
            end
            draw_interaction_curve(probabilityAxes, result, curveSettings);
        catch
            title(probabilityAxes, 'Probability chart unavailable');
        end
    else
        title(distributionAxes, 'No result yet');
        title(probabilityAxes, 'No result yet');
    end

    calculatorPanel = uipanel(layout, 'Title', ...
        'Chance of an outcome at one physical gap', 'FontWeight', 'bold');
    calculatorPanel.Layout.Row = 3;
    calculatorPanel.Layout.Column = [1 3];
    calculatorLayout = uigridlayout(calculatorPanel, [2 1]);
    calculatorLayout.RowHeight = {'fit', 'fit'};
    calculatorLayout.Padding = [10 8 10 8];
    calculatorLayout.RowSpacing = 8;
    uilabel(calculatorLayout, 'Text', [ ...
        'This does not change the planned operating instruction. Enter a gap ' ...
        'to see the best estimated chance and its cautious confidence-backed minimum.'], ...
        'FontSize', 12, 'WordWrap', 'on');

    controls = uigridlayout(calculatorLayout, [1 7]);
    controls.ColumnWidth = {55, 90, 40, 125, 100, 120, '1x'};
    controls.Padding = [0 4 0 4];
    controls.ColumnSpacing = 8;
    uilabel(controls, 'Text', 'Gap:', 'HorizontalAlignment', 'right');
    defaultGap = 0;
    if has_estimate, defaultGap = round(result.mu, 2); end
    gapEdit = uieditfield(controls, 'numeric', 'Value', defaultGap);
    uilabel(controls, 'Text', unit);
    outcomeDrop = uidropdown(controls, ...
        'Items', {'Interaction', 'No interaction'});
    calculateButton = uibutton(controls, 'Text', 'Calculate');
    saveButton = uibutton(controls, 'Text', 'Save results...');
    outputLabel = uilabel(controls, 'Text', '', 'WordWrap', 'on');
    saveButton.Layout.Column = 6;
    outputLabel.Layout.Column = 7;

    if has_estimate
        calculateButton.ButtonPushedFcn = @(~, ~) calculate_probability( ...
            result, unit, confidence, gapEdit, outcomeDrop, outputLabel);
    else
        calculateButton.Enable = 'off';
    end
    if result_save_available(result)
        saveButton.ButtonPushedFcn = @(~, ~) save_from_window(result, h);
    else
        saveButton.Enable = 'off';
    end
    if ~has_estimate && result_save_available(result)
        outputLabel.Text = 'No fitted answer yet. The completed test data can still be saved.';
    elseif ~has_estimate
        outputLabel.Text = 'No completed tests are available to save.';
    end
end

function calculate_probability(result, unit, confidence, gapEdit, outcomeDrop, outputLabel)
    try
        gap = gapEdit.Value;
        if strcmp(outcomeDrop.Value, 'Interaction')
            target = 'interaction';
        else
            target = 'no_interaction';
        end
        answer = reliability_query(result, target, 'probability_at', ...
            gap, confidence);
        if isnan(answer.bound_percent) || isnan(answer.percent)
            outputLabel.Text = 'No estimate yet - more useful test results are needed.';
            return;
        end
        cautious = min(answer.bound_percent, answer.percent);
        outputLabel.Text = sprintf([ ...
            'At %.2f %s: best estimated chance %.4g%%; cautious minimum %.4g%% ' ...
            'at %.4g%% confidence.'], gap, unit, answer.percent, cautious, ...
            100 * confidence);
    catch err
        outputLabel.Text = sprintf('Could not calculate: %s', err.message);
    end
end

function save_from_window(result, parentFigure)
    [fileName, folder] = uiputfile( ...
        {'*.html', 'Report + data (HTML/CSV)'}, 'Save results as', ...
        'gap-study-results.html');
    if isequal(fileName, 0), return; end
    base = fullfile(folder, fileName);
    paths = result_output_paths(base);
    if isfile(paths.csv) || isfile(paths.html)
        uialert(parentFigure, sprintf([ ...
            'Nothing was saved because a result file already exists.\n\n' ...
            'Choose a different name so no earlier result is replaced.\n\n' ...
            'CSV: %s\nHTML: %s'], paths.csv, paths.html), ...
            'Name already in use', 'Icon', 'warning');
        return;
    end
    choice = uiconfirm(parentFigure, sprintf([ ...
        'The app will save these two files:\n\nData: %s\nReport: %s\n\nContinue?'], ...
        paths.csv, paths.html), 'Confirm save location', ...
        'Options', {'Save', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
    if ~strcmp(choice, 'Save'), return; end

    imageText = '';
    imagePath = [tempname '.png'];
    try
        exportapp(parentFigure, imagePath);
        fileId = fopen(imagePath, 'r');
        cleanupFile = onCleanup(@() close_and_delete(fileId, imagePath)); %#ok<NASGU>
        imageBytes = fread(fileId, Inf, '*uint8');
        imageText = matlab.net.base64encode(imageBytes);
    catch
        if isfile(imagePath), delete(imagePath); end
    end

    try
        savedPaths = save_results_files(base, results_to_csv_text(result), ...
            results_to_html(result, imageText));
        uialert(parentFigure, sprintf('Saved:\n%s\n%s', ...
            savedPaths.csv, savedPaths.html), 'Results saved', 'Icon', 'success');
    catch err
        uialert(parentFigure, err.message, 'Results not saved', 'Icon', 'error');
    end
end

function close_and_delete(fileId, imagePath)
    if fileId >= 0, fclose(fileId); end
    if isfile(imagePath), delete(imagePath); end
end

function usable_resolution_mm = usable_resolution_for_plan(plan, default_mm)
%USABLE_RESOLUTION_FOR_PLAN Choose a two-decimal test step for a loaded plan.
% Component thicknesses and irregular reachable gaps do not prove the test
% equipment can control their smallest numerical difference. Those plans keep
% the visible provisional default so the operator can confirm or change it.

    if nargin < 2, default_mm = 0.05; end
    if ~is_two_decimal_step(default_mm)
        error('usable_resolution_for_plan:badDefault', ...
            'The default usable gap step must be a positive whole hundredth.');
    end
    usable_resolution_mm = default_mm;
    if ~isstruct(plan) || ~isfield(plan, 'physical_setup') || ...
            ~isstruct(plan.physical_setup) || ...
            ~isfield(plan.physical_setup, 'mode')
        return;
    end
    setup = plan.physical_setup;
    if strcmpi(char(string(setup.mode)), 'regular')
        if ~isfield(setup, 'increment_mm') || ...
                ~is_two_decimal_step(setup.increment_mm)
            error('usable_resolution_for_plan:badRegularStep', ...
                ['A regular gap step must be a positive whole hundredth, ' ...
                 'for example 0.05, 0.10, 0.15, or 0.50 mm.']);
        end
        usable_resolution_mm = double(setup.increment_mm);
    end
end

function yes = is_two_decimal_step(value)
    yes = isnumeric(value) && isscalar(value) && isreal(value) && ...
        isfinite(value) && value > 0 && ...
        abs(value * 100 - round(value * 100)) <= 1e-10;
end

function setup = validate_planner_components(component_names,component_mm,maximum_counts)
%VALIDATE_PLANNER_COMPONENTS Validate measured printed-spacer recipes.
% Foil recipes are intentionally unavailable until measured stacks and a
% practical maximum layer count have been supplied.

if ~iscell(component_names) || numel(component_names) ~= numel(component_mm) || ...
        numel(component_mm) ~= numel(maximum_counts) || isempty(component_mm) || ...
        any(~isfinite(component_mm)) || any(component_mm <= 0) || ...
        any(~isfinite(maximum_counts)) || any(maximum_counts < 0) || ...
        any(maximum_counts ~= floor(maximum_counts))
    error('validate_planner_components:badComponents', ...
        ['Enter measured printed-spacer thicknesses and whole-number ' ...
         'maximum counts.']);
end

names = string(component_names);
if any(contains(lower(names),'foil'))
    error('validate_planner_components:foilNotReady', ...
        ['Foil recipes are unavailable until foil stacks are measured and ' ...
         'a practical maximum layer count is confirmed.']);
end

setup = struct('mode','combinations', ...
    'component_names',{cellstr(names(:)')}, ...
    'component_mm',component_mm(:)', ...
    'maximum_counts',maximum_counts(:)');
end

function [is_valid, message] = validate_study_plan_safety(plan)
%VALIDATE_STUDY_PLAN_SAFETY Check the fixed v1.10 reliability safeguards.
% A missing or edited safeguard must never turn into permission to issue an
% operating instruction.

    is_valid = false;
    message = '';
    required = {'reliability', 'confidence', ...
        'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~isstruct(plan) || ~all(isfield(plan, required))
        message = [ ...
            'The study plan is missing the v1.10 reliability safety rules.'];
        return;
    end

    floor_articles = plan.reliability_validation_floor_articles;
    if ~(isnumeric(floor_articles) && isscalar(floor_articles) && ...
            isreal(floor_articles) && isfinite(floor_articles) && ...
            floor_articles == 400)
        message = [ ...
            'The reliability safety floor must remain 400 independent articles.'];
        return;
    end

    confidence = plan.confidence;
    if ~(isnumeric(confidence) && isscalar(confidence) && ...
            isreal(confidence) && isfinite(confidence) && ...
            confidence >= 0.10 && confidence <= 0.999)
        message = 'The saved confidence is outside the permitted planning range.';
        return;
    end

    reliability = plan.reliability;
    if ~(isnumeric(reliability) && isscalar(reliability) && ...
            isreal(reliability) && isfinite(reliability) && ...
            reliability >= 0.10 && reliability <= 0.999)
        message = 'The saved reliability is outside the permitted 10% to 99.9% range.';
        return;
    end

    support_flag = plan.reliability_instruction_supported;
    if ~(islogical(support_flag) && isscalar(support_flag))
        message = 'The reliability-support decision in the plan is invalid.';
        return;
    end

    if confidence <= 0.50
        expected_support = false;
        expected_status = 'exploratory_confidence';
    elseif confidence > 0.95
        expected_support = false;
        expected_status = 'above_recorded_validation';
    else
        expected_support = true;
        expected_status = 'supported_after_final_checkpoint';
    end
    status_text = char(string(plan.reliability_instruction_status));
    if support_flag ~= expected_support || ~strcmp(status_text, expected_status)
        message = [ ...
            'The saved confidence and reliability-support decision do not agree.'];
        return;
    end

    is_valid = true;
end

function [clean, messages] = validate_plan_inputs(input)
%VALIDATE_PLAN_INPUTS Check and normalize the pre-test planner answers.
% Percentages may be entered as 95 or 0.95. Returned percentages are
% fractions, so 95% is returned as 0.95.

    required_fields = {'mode', 'outcome', 'reliability', 'confidence', ...
        'accuracy_mm', 'interaction_gap_mm', 'no_interaction_gap_mm', ...
        'minimum_gap_mm', 'maximum_gap_mm', 'previous_information', ...
        'available_articles', 'physical_setup'};
    for field_number = 1:numel(required_fields)
        field_name = required_fields{field_number};
        if ~isstruct(input) || ~isfield(input, field_name)
            error('validate_plan_inputs:missingAnswer', ...
                'The planner answer "%s" is missing. Please complete that question.', ...
                field_name);
        end
    end

    clean = input;
    clean.mode = normalized_text(input.mode);
    if ~any(strcmp(clean.mode, {'requirements_first', ...
            'available_articles_first'}))
        error('validate_plan_inputs:badMode', ...
            'Choose whether to plan from requirements or from the articles available.');
    end

    clean.outcome = normalized_text(input.outcome);
    if isempty(clean.outcome)
        error('validate_plan_inputs:missingOutcome', ...
            'Choose Interaction or No interaction before calculating the plan.');
    end
    if ~any(strcmp(clean.outcome, {'interaction', 'no_interaction'}))
        error('validate_plan_inputs:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end

    clean.reliability = normalize_percentage(input.reliability, ...
        'validate_plan_inputs:badReliability', 'Reliability');
    clean.confidence = normalize_percentage(input.confidence, ...
        'validate_plan_inputs:badConfidence', 'Confidence');

    numeric_fields = {'accuracy_mm', 'interaction_gap_mm', ...
        'no_interaction_gap_mm', 'minimum_gap_mm', 'maximum_gap_mm'};
    for field_number = 1:numel(numeric_fields)
        field_name = numeric_fields{field_number};
        value = input.(field_name);
        if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
            error('validate_plan_inputs:badNumber', ...
                '%s must be one finite number in millimetres.', ...
                readable_field_name(field_name));
        end
        clean.(field_name) = double(value);
    end

    if clean.maximum_gap_mm <= clean.minimum_gap_mm
        error('validate_plan_inputs:badPermittedRange', ...
            'The maximum permitted gap must be greater than the minimum gap.');
    end
    if clean.interaction_gap_mm >= clean.no_interaction_gap_mm
        error('validate_plan_inputs:reversedExpectations', ...
            ['The almost-always Interaction gap must be smaller than the ' ...
             'almost-always No-interaction gap for this application.']);
    end
    if clean.interaction_gap_mm < clean.minimum_gap_mm || ...
            clean.no_interaction_gap_mm > clean.maximum_gap_mm
        error('validate_plan_inputs:expectationOutsideRange', ...
            'Both expected gaps must be inside the permitted gap range.');
    end
    permitted_width = clean.maximum_gap_mm - clean.minimum_gap_mm;
    if clean.accuracy_mm <= 0 || clean.accuracy_mm > permitted_width
        error('validate_plan_inputs:badAccuracy', ...
            'Required gap accuracy must be positive and smaller than the permitted range.');
    end

    clean.previous_information = normalized_text(input.previous_information);
    if ~any(strcmp(clean.previous_information, {'first_study', ...
            'sudden', 'gradual', 'advanced_value'}))
        error('validate_plan_inputs:badPreviousInformation', ...
            'Choose first study, sudden change, gradual change, or an advanced value.');
    end

    if strcmp(clean.mode, 'available_articles_first')
        article_count = input.available_articles;
        if ~(isnumeric(article_count) && isscalar(article_count) && ...
                isreal(article_count) && isfinite(article_count) && ...
                article_count >= 1 && article_count == floor(article_count))
            error('validate_plan_inputs:badAvailableArticles', ...
                'The number of available articles must be a positive whole number.');
        end
        clean.available_articles = double(article_count);
    else
        clean.available_articles = [];
    end

    if ~isstruct(clean.physical_setup) || ~isfield(clean.physical_setup, 'mode')
        error('validate_plan_inputs:badPhysicalSetup', ...
            'Choose how the physical gaps can be built.');
    end

    if clean.confidence < 0.5
        confidence_message = "This confidence is exploratory only. " + ...
            "It is below 50% and is not a cautious reliability claim.";
    elseif clean.confidence == 0.5
        confidence_message = "50% confidence is the centre estimate " + ...
            "with no safety margin.";
    else
        confidence_message = "This confidence applies a cautious safety " + ...
            "margin to the result.";
    end
    messages = [confidence_message; ...
        "Almost every time is treated as at least 95%, not as 100%."];
end

function value = normalize_percentage(raw_value, error_id, label)
    if ~(isnumeric(raw_value) && isscalar(raw_value) && isreal(raw_value) && ...
            isfinite(raw_value) && raw_value > 0)
        error(error_id, '%s must be between 10%% and 99.9%%.', label);
    end
    value = double(raw_value);
    if value > 1
        value = value / 100;
    end
    endpoint_tolerance = 1e-12;
    if value < 0.10 - endpoint_tolerance || value > 0.999 + endpoint_tolerance
        error(error_id, '%s must be between 10%% and 99.9%%.', label);
    end
    value = min(max(value, 0.10), 0.999);
end

function text = normalized_text(value)
    if isstring(value) && isscalar(value)
        text = lower(strtrim(char(value)));
    elseif ischar(value) && isrow(value)
        text = lower(strtrim(value));
    else
        text = '';
    end
end

function label = readable_field_name(field_name)
    label = strrep(field_name, '_', ' ');
    label = regexprep(label, ' mm$', '');
    label(1) = upper(label(1));
end
