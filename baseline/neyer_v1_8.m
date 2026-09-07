if usejava('desktop')
    neyer_app;
end

avg_low      = 0.6;      % low end of your guess for the average breaking height (mm)
avg_high     = 1.4;      % high end of your guess (mm)
spread_guess = 0.10;     % rough guess of the part-to-part spread (mm)
num_parts    = 20;       % how many parts (destructive tests) you will run
run_my_own_test = false; % false = run the built-in demo (reproduces Neyer Table 1)
                         % true  = pop up and run YOUR real test (needs the MATLAB desktop)
cfg = neyer_settings();        % all adjustable settings live here
cfg.min_level = 0;       % your rig's minimum height (mm) - keeps suggestions >= 0
params = struct('avg_low', avg_low, 'avg_high', avg_high, 'spread_guess', spread_guess);

plan_prep(params, 0.999, 0.95);

fixed = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);   % Table 1 outcomes (demo)
if run_my_own_test && usejava('desktop')
    result = run_test_ui();                                    % your test, via pop-ups
else
    [result, record] = run_test(params, num_parts, @(level,k) fixed(k), cfg);
end

if ~isempty(result)
    if usejava('desktop')
        try, show_result(result); catch, end
    else
        try, plot_result(result); catch, end
    end
end

if ~isempty(result) && isfield(result, 'has_overlap') && result.has_overlap
    safe_height = reliability_query(result, 'break', 'height_for',     0.999, 0.95);
    rel_at_6mm  = reliability_query(result, 'break', 'reliability_at', 6.0,   0.95);
    how_many    = reliability_query(result, 'break', 'plan',           0.999, 0.95);
end

chk = run_test(struct('avg_low',0.6,'avg_high',1.4,'spread_guess',0.10), 20, ...
               @(level,k) fixed(k));
fprintf('SELF-CHECK: average %.4f (expect 5.3922), spread %.4f (expect 1.0412)\n', ...
        chk.mu, chk.sigma);


% ================= WORKERS (local functions) =================


% ==== from config/neyer_settings.m ====

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
    s.stage2_bisect_width_sigmas = 1.5;    % RECOMMENDATION (between the 2.0 and 1.0 seen in Table 1)

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
    s.min_level = -Inf;   % RECOMMENDATION (set to 0 for the drop-test rig)

    % --- Display unit for heights (label only; no conversion) ----------------
    s.unit = 'mm';   % RECOMMENDATION ('mm'/'cm'/'m'/'km' or any short label)
end


% ==== from src/math/shape_model.m ====
function s = shape_model(x, mu, sigma)
%SHAPE_MODEL  Worker #1 — the bell curve (the ONLY place the shape lives).
%
%   s = SHAPE_MODEL(x, mu, sigma) evaluates the assumed response shape at one
%   or more test levels x, for a population whose breaking points follow a
%   bell curve (normal distribution) with mean mu and spread sigma.
%
%   It returns "how likely a break is" at each level, plus the standard-normal
%   building blocks every other worker needs (z, phi, Phi, Q). Because the
%   shape assumption is quarantined here, swapping the bell curve for another
%   shape (e.g. the logistic) is a single-file change.  [brief sec.4, worker #1]
%
%   Alternate call (inverse):  z = SHAPE_MODEL(p, 'quantile')  goes the other
%   way -- given a probability p in (0,1), it returns how many spreads from the
%   centre that break-chance sits at (the z with Phi(z) = p). report (#9) uses
%   this to turn a strictness like 99.9% into an all-fire / no-fire level. See
%   the "Inverse (quantile) mode" block below.  [addendum B1]
%
%   Inputs
%     x      test level(s); scalar or array of any shape.
%     mu     assumed average breaking point (centre of the bell curve), scalar.
%     sigma  assumed spread (standard deviation), scalar, must be > 0.
%
%   Output struct s, every field the same size as x:
%     s.z    standardised level, z = (x - mu) / sigma          [brief App.A]
%     s.phi  standard-normal pdf at z, phi(z)                   [brief App.A]
%     s.Phi  standard-normal cdf at z, Phi(z) = P(break)        [brief App.A]
%     s.Q    upper tail, Q(z) = 1 - Phi(z) = P(survive)         [brief App.A]
%     s.p    probability of a break at this level = s.Phi (alias for clarity)
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

    % Spread must be positive — z divides by it. Defensive guard; full input
    % validation is worker #7 (check_inputs).  [brief sec.8 item 4]
    if ~(isscalar(mu) && isscalar(sigma))
        error('shape_model:scalarParams', 'mu and sigma must be scalars.');
    end
    if ~(sigma > 0) || ~isfinite(sigma)
        error('shape_model:badSigma', 'sigma must be a finite positive number.');
    end

    z = (x - mu) ./ sigma;

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


% ==== from src/math/loglik.m ====
function ll = loglik(levels, successes, mu, sigma)
%LOGLIK  Log-likelihood of the bell-curve sensitivity model (Eq.1), one home.
%
%   ll = LOGLIK(levels, successes, mu, sigma) returns
%     l(mu,sigma) = sum_{break} ln Phi(z) + sum_{survive} ln Q(z),  z=(x-mu)/sigma
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


% ==== from src/math/info_terms.m ====
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


% ==== from src/math/best_fit.m ====
function [mu, sigma, ll] = best_fit(levels, successes, mu0, sigma0)
%BEST_FIT  Worker #2 — maximum-likelihood fit of the bell-curve (mu, sigma).
%
%   [mu, sigma] = BEST_FIT(levels, successes, mu0, sigma0) returns the average
%   and spread that best explain the results so far, by maximising the
%   log-likelihood of the normal sensitivity model.  [brief sec.4, worker #2;
%   App.A Eq.1]
%
%       l(mu, sigma) = sum_{successes} ln Phi(z) + sum_{failures} ln Q(z),
%       with z = (x - mu) / sigma.
%
%   Inputs
%     levels     vector of test levels x already run.
%     successes  logical vector, same length as levels:
%                  true  = break  (success), uses Phi(z)
%                  false = survive (failure), uses Q(z)
%     mu0, sigma0  starting guess for the optimiser (e.g. the current
%                  estimate). sigma0 must be > 0.
%
%   Outputs
%     mu, sigma  the maximum-likelihood estimate.
%     ll         the maximised log-likelihood (handy for diagnostics).
%
%   Notes tied to the brief:
%     * The bell curve is NOT recomputed here — every probability comes from
%       worker #1 (shape_model), so the shape stays in one file. [sec.4]
%     * The optimiser searches over (mu, log sigma) so the spread can never go
%       to zero or negative — sigma = exp(theta) is positive by construction.
%       This is the "keep spread positive / reparameterise" guard. [sec.8 #4]
%     * A finite, meaningful optimum exists only once successes and failures
%       overlap (the Silvapulle condition). Detecting that and deciding when
%       to call best_fit is worker #4 / worker #6; clipping wild early fits is
%       worker #5. best_fit itself just maximises the likelihood it is given.
%       [sec.8 #2, #3]
%     * Uses base fminsearch (Nelder-Mead) — no toolbox dependency.

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


% ==== from src/math/find_root.m ====
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


% ==== from src/math/prof_quantile.m ====
function L = prof_quantile(levels, successes, q, ksig, sigma0)
%PROF_QUANTILE  Profiled log-likelihood with the level q = mu + ksig*sigma held
%   fixed: substitute mu = q - ksig*sigma and maximise over sigma>0 (via log sigma).
%   Shared by lr_confidence and the reliability-at-confidence units.  [addendum LR]
    f = @(t) -loglik(levels, successes, q - ksig*exp(t), exp(t));
    that = fminsearch(f, log(sigma0), pl_opts());
    L = -f(that);
end


% ==== from src/math/pl_opts.m ====
function opts = pl_opts()
%PL_OPTS  Shared optimiser options for profile-likelihood inner maximisation.
%   Base optimset only (no toolbox). Used by lr_confidence and the
%   reliability-at-confidence units (Mode A/B, planner).  [addendum LR / RAC]
    opts = optimset('TolX', 1e-8, 'TolFun', 1e-10, 'MaxFunEvals', 1e4, 'MaxIter', 1e4);
end


% ==== from src/math/pick_next_level.m ====
function [x_next, det_max] = pick_next_level(levels, mu, sigma, cfg, side_pref)
%PICK_NEXT_LEVEL  Worker #3 — the D-optimal picker (the method's heart).
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


% ==== from src/math/fit_sigma0.m ====
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


% ==== from src/math/lr_confidence.m ====
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
    c1  = shape_model(C,       'quantile')^2;    % one-sided threshold
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


% ==== from src/math/height_for_reliability.m ====
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
    c1  = shape_model(C, 'quantile')^2;
    cap = 5 * (max(levels) - min(levels));

    if strcmp(tail, 'break')
        res.height = mu + k*sigma;
        Rq = @(q) 2*(Lmax - prof_quantile(levels, successes, q, +k, sigma));
        res.bound  = find_root(Rq, res.height, +1, c1, cap, +Inf);
    else
        res.height = mu - k*sigma;
        Rq = @(q) 2*(Lmax - prof_quantile(levels, successes, q, -k, sigma));
        res.bound  = find_root(Rq, res.height, -1, c1, cap, -Inf);
    end
end


% ==== from src/math/reliability_at_height.m ====
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
    khat = (x - mu) / sigma;               % standardised distance of x from centre
    c1   = shape_model(C, 'quantile')^2;
    kfl  = shape_model(1e-6, 'quantile');  % 1-in-a-million floor (~ -4.7534)
    Rk   = @(k) 2*(Lmax - prof_quantile(levels, successes, x, k, sigma));

    if strcmp(tail, 'break')
        res.reliability = phi_cdf(khat);              % Phi(khat)
        cap = khat - kfl;                             % search downward toward the floor
        kb  = find_root(Rk, khat, -1, c1, cap, -Inf); % lower k -> lower reliability
        if isnan(kb), res.bound = 1e-6; res.bound_floored = true;
        else          res.bound = phi_cdf(kb); end
    else
        res.reliability = phi_cdf(-khat);             % Phi(-khat) = survive prob
        cap = -kfl - khat;                            % search upward (higher k -> lower survive)
        kb  = find_root(Rk, khat, +1, c1, cap, +Inf);
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


% ==== from src/math/plan_samples.m ====
function res = plan_samples(tail, R, C, cfg, basis)
%PLAN_SAMPLES  Estimate how many parts to test for a reliability at a confidence.
%   res = PLAN_SAMPLES(tail, R, C, cfg, basis)
%     tail  : 'break' or 'survive' (affects only wording; the count is symmetric)
%     R, C  : reliability and confidence, each in (0,1)
%     basis : struct('sigma', s)                 -> up-front, Banerjee asymptotics
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

    if isfield(basis, 'sigma')
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


% ==== from src/math/plan_prep_numbers.m ====
function res = plan_prep_numbers(params, R, C, cfg)
%PLAN_PREP_NUMBERS  Pure core of the pre-lab planner: parts count + first height.
%   res = PLAN_PREP_NUMBERS(params, R, C, cfg) returns how many parts to prepare
%   for reliability R at confidence C, and the height of the first drop -- with NO
%   printing. Reuses plan_samples (the verified engine) so the sample-size math has
%   a single home. The count is spread-independent (the target precision is a
%   fraction of sigma, so sigma cancels -- see settings.m / the spec), so a sigma=1
%   placeholder is passed. The first drop is the midpoint of the guess (Stage 1
%   starts at the centre of the bounds). [addendum PREP]
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


% ==== from src/logic/has_overlap.m ====
function tf = has_overlap(levels, successes)
%HAS_OVERLAP  Worker #4 — the Silvapulle condition (Stage 2 -> Stage 3 gate).
%
%   tf = HAS_OVERLAP(levels, successes) answers yes/no: have breaks and
%   survivals started to interleave? Until they do, there is genuinely not
%   enough information to compute a real best-fit, so the loop must stay on the
%   Stage-2 surrogate path. Once they overlap, the MLE exists and Stage 3
%   begins.  [brief sec.3 Stage 2; sec.4 worker #4; sec.8 #2 -- the Silvapulle
%   condition]
%
%   Interleave, in the brief's words, is "a lower level broke while a higher
%   one survived": a success (break) occurring at a strictly lower level than
%   some failure (survive). Equivalently:
%
%       overlap  <=>  min(success levels) < max(failure levels)
%
%   Strict inequality is deliberate: if the lowest break and the highest
%   survive sit at the same level (a boundary tie), the data is still
%   separable and the MLE diverges, so that is NOT overlap.
%
%   Inputs
%     levels     vector of test levels run so far.
%     successes  logical vector, same length: true = break, false = survive.
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

    tf = min(success_levels) < max(failure_levels);
end


% ==== from src/logic/sanity_clamp.m ====
function [mu_c, sigma_c] = sanity_clamp(mu, sigma, levels, cfg)
%SANITY_CLAMP  Worker #5 — rein in wild best-fits on few results.
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


% ==== from src/logic/choose_stage.m ====
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


% ==== from src/workflow/check_inputs.m ====
function check_inputs(params, num_parts)
%CHECK_INPUTS  Worker #7 — refuse bad starting guesses up front.
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


% ==== from src/workflow/run_loop.m ====
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

    for k = 1:num_parts
        % Estimate held going in, and the level it implies.
        [x, est] = choose_stage(levels(1:k-1), successes(1:k-1), params, cfg);

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
    end

    record = struct('levels', levels, 'successes', successes, ...
                    'est_mu', est_mu, 'est_sigma', est_sigma, ...
                    'stage', stage, 'clamped', clamped, 'params', params, 'N', num_parts);
end


% ==== from src/workflow/report.m ====
function result = report(record, cfg)
%REPORT  Worker #9 — present the final average, spread, and confidence.
%
%   result = REPORT(record, cfg) takes the finished run (from run_loop) and
%   produces the headline answer: the best-fit average and spread over all
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

    result = struct('mu', NaN, 'sigma', NaN, ...
                    'unit', u, ...
                    'var_mu', NaN, 'var_sigma', NaN, ...
                    'se_mu', NaN, 'se_sigma', NaN, ...
                    'tail_fraction', NaN, 'tail_k', NaN, ...
                    'all_fire', NaN, 'se_all_fire', NaN, ...
                    'no_fire', NaN, 'se_no_fire', NaN, ...
                    'confidence_level', NaN, ...
                    'mu_lo', NaN, 'mu_hi', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
                    'all_fire_cbound', NaN, 'no_fire_cbound', NaN, ...
                    'has_overlap', false, 'n', n, 'levels', levels, 'successes', successes);

    % No overlap -> no real answer exists yet (Silvapulle). Report honestly.
    if ~has_overlap(levels, successes)
        result.has_overlap = false;
        fprintf('\n=== Neyer sensitivity test: NO RESULT ===\n');
        fprintf('Results have not yet overlapped, so the average and spread\n');
        fprintf('cannot be estimated. Run more items.\n\n');
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

    pc  = 100 * p_tail;         % strictness, e.g. 99.9
    cc  = 100 * result.confidence_level;   % confidence, e.g. 95
    fprintf('\n=== Neyer sensitivity test: RESULT (%d tests) ===\n\n', n);
    fprintf('AVERAGE breaking point: %.4f %s\n', mu, u);
    fprintf('  The level where about half the items break.\n');
    fprintf('  %.4g%% confident the true average is between %.4f and %.4f %s.\n\n', cc, result.mu_lo, result.mu_hi, u);
    fprintf('SPREAD (how much items vary): %.4f %s\n', sigma, u);
    fprintf('  %.4g%% confident the true spread is between %.4f and %.4f %s.\n\n', cc, result.sigma_lo, result.sigma_hi, u);
    fprintf('ALL-FIRE level (%.4g%% of parts break): %.4f %s\n', pc, result.all_fire, u);
    if isfinite(result.all_fire_cbound)
        fprintf('  %.4g%% confident that %.4g%% of parts break at or above %.4f %s.\n', ...
                cc, pc, result.all_fire_cbound, u);
    else
        pa = plan_samples('break', p_tail, result.confidence_level, cfg, ...
                          struct('n', n, 'level', result.all_fire, 'se', result.se_all_fire));
        fprintf('  A trustworthy all-fire bound could not be pinned down with %d tests --\n', n);
        fprintf('  plan for about %d parts in total to establish it.\n', pa.n_recommended);
    end
    fprintf('\n');
    fprintf('NO-FIRE level (%.4g%% of parts survive): %.4f %s\n', pc, result.no_fire, u);
    if isfinite(result.no_fire_cbound) && result.no_fire_cbound >= 0
        fprintf('  %.4g%% confident that %.4g%% of parts survive below %.4f %s.\n', ...
                cc, pc, result.no_fire_cbound, u);
    else
        pn = plan_samples('survive', p_tail, result.confidence_level, cfg, ...
                          struct('n', n, 'level', result.no_fire, 'se', result.se_no_fire));
        fprintf('  A trustworthy safe (no-fire) height could not be pinned down with %d tests\n', n);
        fprintf('  (the bound came out at or below zero) -- plan for about %d parts in total.\n', pn.n_recommended);
    end
    fprintf('\n');
    fprintf('Note: the all-fire/no-fire edges are less certain than the average --\n');
    fprintf('  this test measures the whole picture, not just the far extremes.\n');
    fprintf('For other reliabilities, or the reliability at a specific height, run\n');
    fprintf('  reliability_query(result).  For the chart, run plot_result(result).\n\n');
end


% ==== from src/workflow/plot_result.m ====
function h = plot_result(result, cfg, savepath)
%PLOT_RESULT  Draw the fitted normal distribution of a finished test.
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

    h  = figure();     % a fresh figure each call, so repeated plots never overlay
    ax = axes('Parent', h);
    draw_distribution(ax, result);

    if nargin >= 3 && ~isempty(savepath)
        print(h, savepath, '-dpng');
    end
end


% ==== from src/workflow/reliability_query.m ====
function q = reliability_query(result, tail, action, value, C)
%RELIABILITY_QUERY  Plain-language reliability/height/confidence calculator.
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

    tail = lower(tail);
    if ~any(strcmp(tail, {'break','survive'}))
        error('reliability_query:badTail', 'tail must be ''break'' or ''survive''.');
    end
    levels = result.levels; successes = result.successes;

    switch lower(action)
        case 'height_for'
            q = height_for_reliability(levels, successes, tail, value, C);
        case 'reliability_at'
            q = reliability_at_height(levels, successes, tail, value, C);
        case 'plan'
            % Banerjee (point-estimate) basis from the fitted spread. This is the
            % up-front asymptotic formula, NOT the exact scaled 1/N basis --
            % report.m does the refined scaled count off n/level/se.
            q = plan_samples(tail, value, C, cfg, struct('sigma', result.sigma));
        otherwise
            error('reliability_query:badAction', ...
                  'action must be ''height_for'', ''reliability_at'', or ''plan''.');
    end
end

% ---- interactive menu (never called by the test suite) --------------------
% All prompts read text with input(...,'s') and validate via the local helpers
% ask_int_in_set / ask_num_in_range, which loop until the entry is good. A stray
% letter becomes NaN (str2double) and is simply re-asked, never a raw Octave
% error, so a human running the menu cannot crash it or be silently mis-defaulted.
function q = run_menu(result, cfg)
    fprintf('\n--- Reliability calculator ---\n');
    fprintf('  [1] Safe height for a reliability   (I have a target)\n');
    fprintf('  [2] Reliability at a height          (I am stuck with a height)\n');
    fprintf('  [3] How many parts do I need?        (planner)\n');
    mode = ask_int_in_set('Choose 1/2/3: ', [1 2 3]);
    t    = ask_int_in_set('Break or survive? [1] break  [2] survive: ', [1 2]);
    tail = 'break'; if t == 2, tail = 'survive'; end

    if mode == 2
        x = ask_num_in_range('Height (mm): ', -Inf, Inf);   % any finite height
        C = ask_confidence(cfg);
        q = reliability_query(result, tail, 'reliability_at', x, C);
    else
        R = ask_reliability(cfg);
        C = ask_confidence(cfg);
        if mode == 3
            q = reliability_query(result, tail, 'plan', R, C);
        else
            q = reliability_query(result, tail, 'height_for', R, C);
        end
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
        verb = 'break at >='; if strcmp(tail,'survive'), verb = 'survive below'; end
        fprintf('%.4g%% confident that %.4g%% of parts %s %.2f mm.\n', ...
                100*q.C, 100*q.R, verb, q.bound);
    elseif isfield(q, 'reliability')
        fprintf('At %.2f mm: %.4g%% confident at least %.4g%% of parts %s.\n', ...
                q.x, 100*q.C, q.bound_percent, tail);
    elseif isfield(q, 'n_recommended')
        fprintf('Plan for about %d parts. %s\n', q.n_recommended, q.caveat);
        fprintf('(Why at least %d: %s)\n', q.n_floor, q.floor_reason);
        fprintf('(Counting failures directly would need ~%d parts.)\n', q.n_bogey);
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


% ==== from src/workflow/parse_run_inputs.m ====
function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS  Pure core of the settings popup: strings -> validated {params,num_parts,cfg}.
%   out = PARSE_RUN_INPUTS(answers), answers a 5-cell array of strings
%   {lo, hi, spread_guess, num_parts, min_level} as inputdlg returns. Returns
%   struct with .params, .num_parts, .cfg. Validates by reusing check_inputs so
%   the popup cannot accept anything the engine would reject. Blank min_level =
%   no floor (-Inf). Throws a named error on any bad field. [addendum POPUP]
    if ~(iscell(answers) && (numel(answers) == 5 || numel(answers) == 6))
        error('parse_run_inputs:badShape', 'expected a 5-field answer.');
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
              'Minimum height must be a number (or blank for none).');
    end
    params = struct('avg_low', lo, 'avg_high', hi, 'spread_guess', sg);
    check_inputs(params, num_parts);      % reuse the engine's validation (#7)
    cfg = neyer_settings();
    cfg.min_level = ml;
    % Optional 6th field = display unit (label only). Blank = settings() default.
    if numel(answers) == 6 && ~isempty(strtrim(answers{6}))
        cfg.unit = strtrim(answers{6});
    end
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end


% ==== from src/workflow/format_result_text.m ====
function s = format_result_text(result)
%FORMAT_RESULT_TEXT  Pure: turn a report `result` into the plain-language popup text.
%   s = FORMAT_RESULT_TEXT(result) returns a multi-line char array, reusing the
%   numbers already on `result` (no re-estimation; report.m untouched). If results
%   have not overlapped, returns a single "no result" line. [addendum POPUP]
    if ~isfield(result,'has_overlap') || ~result.has_overlap || isnan(result.mu)
        s = 'No result yet - results have not overlapped. Run more parts.';
        return;
    end
    cc = 100 * result.confidence_level;
    pc = 100 * result.tail_fraction;
    lines = {
        sprintf('Tests used: %d', result.n)
        ''
        sprintf('AVERAGE breaking height: %.4f', result.mu)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.mu_lo, result.mu_hi)
        ''
        sprintf('SPREAD (part-to-part variation): %.4f', result.sigma)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.sigma_lo, result.sigma_hi)
        ''
        sprintf('ALL-FIRE height (%.4g%% break): %.4f', pc, result.all_fire)
        sprintf('NO-FIRE height (%.4g%% survive): %.4f', pc, result.no_fire)
        ''
        'For reliability at a height, run reliability_query(result).'
    };
    s = strjoin(lines, sprintf('\n'));
end


% ==== from src/workflow/draw_distribution.m ====
function draw_distribution(ax, result)
%DRAW_DISTRIBUTION  Draw the fitted bell curve + average line + all-fire/no-fire
%   markers into a given axes handle `ax`. Base plotting only (works for a normal
%   figure axes and a uiaxes). Shared by plot_result and show_result. [addendum POPUP]
    u = 'mm'; if isfield(result,'unit') && ~isempty(result.unit), u = result.unit; end
    mu = result.mu; sigma = result.sigma;
    % percentage that survives-below / breaks-above the thresholds (for callouts)
    if isfield(result,'tail_fraction') && ~isempty(result.tail_fraction) && isfinite(result.tail_fraction)
        pc = 100 * result.tail_fraction;
    else
        pc = 99.9;
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
    text(ax, mu, 1.04*ymax, sprintf('average %.2f %s', mu, u), ...
        'Color', gold, 'FontWeight', 'bold', 'FontSize', 14, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % --- (2) label the +/-1 spread band, lifted clearly above the relocated CI bracket
    text(ax, mu, 0.46*ymax, 'middle ~68% of parts (\pm1 spread)', ...
        'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.45 0.42 0.36]);

    % --- markers for all-fire / no-fire thresholds
    plot(ax, result.all_fire, 0, 'v', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
    plot(ax, result.no_fire,  0, 'v', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);

    % --- (4) threshold dashed lines (make the triangle markers into clear lines)
    if isfield(result, 'no_fire') && isfinite(result.no_fire)
        line(ax, [result.no_fire result.no_fire], [0 0.15*ymax], ...
            'Color', teal, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    if isfield(result, 'all_fire') && isfinite(result.all_fire)
        line(ax, [result.all_fire result.all_fire], [0 0.15*ymax], ...
            'Color', clay, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    % --- (4) clear filled baseline dots + readable multi-line callouts with leaders
    if isfield(result, 'no_fire') && isfinite(result.no_fire)
        yCall = 0.30*ymax;
        plot(ax, result.no_fire, 0, 'o', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [result.no_fire result.no_fire], [0 yCall], 'Color', teal, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, result.no_fire, yCall, ...
            sprintf('no-fire %.2f %s\n%.4g%% survive below here', result.no_fire, u, pc), ...
            'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', teal);
    end
    if isfield(result, 'all_fire') && isfinite(result.all_fire)
        yCall = 0.30*ymax;
        plot(ax, result.all_fire, 0, 'o', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [result.all_fire result.all_fire], [0 yCall], 'Color', clay, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, result.all_fire, yCall, ...
            sprintf('all-fire %.2f %s\n%.4g%% break above here', result.all_fire, u, pc), ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', clay);
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
        text(ax, mu, 0.18*ymax, sprintf('95%% sure the average is %.2f-%.2f %s', mu_lo, mu_hi, u), ...
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
    nf = result.no_fire; af = result.all_fire;
    if isfinite(nf) && isfinite(af)
        strip_patch(ax, xlo, nf, ys, y0, green);
        strip_patch(ax, nf,  af, ys, y0, amber);
        strip_patch(ax, af,  xhi, ys, y0, reddy);
        text(ax, (xlo+nf)/2, ys/2, 'safe',     'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.20 0.40 0.22]);
        text(ax, (nf+af)/2,  ys/2, 'expected', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.55 0.45 0.15]);
        text(ax, (af+xhi)/2, ys/2, 'fails',    'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.60 0.25 0.20]);
    end

    % --- (7) axis labels + title (enlarged text)
    xlabel(ax, sprintf('drop height (%s)', u), 'FontSize', 14);
    ylabel(ax, {'how often parts break', 'at each height (taller = more)'}, 'FontSize', 14);
    title(ax, sprintf('Fitted distribution:  average %.2f,  spread %.2f', mu, sigma), ...
        'FontSize', 15, 'FontWeight', 'bold');

    % ensure the y-lower-limit includes the strip and headroom for the raised average label
    set(ax, 'YLim', [ys*1.2 1.30*ymax]);
    set(ax, 'XLim', [xlo xhi]);

    % --- (6) legend naming the four key elements (unobtrusive)
    try
        if isempty(hCI)
            legend(ax, [hCurve hMean hBand], ...
                {'fitted spread of breaking heights', 'average', 'middle ~68% (\pm1 spread)'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        else
            legend(ax, [hCurve hMean hBand hCI], ...
                {'fitted spread of breaking heights', 'average', 'middle ~68% (\pm1 spread)', '95% range for the average'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        end
    catch
        % legend can be problematic on some uiaxes configs; the labels/text
        % above already name each element, so failing here is non-fatal.
    end

    hold(ax, 'off');
end

function strip_patch(ax, x1, x2, ylo, yhi, col)
%STRIP_PATCH  Draw one coloured band with explicit vertices (works on uiaxes).
    if ~(isfinite(x1) && isfinite(x2)) || x2 <= x1, return; end
    patch(ax, [x1 x2 x2 x1], [ylo ylo yhi yhi], col, 'EdgeColor', 'none');
end


% ==== from src/workflow/show_result.m ====
function h = show_result(result)
%SHOW_RESULT  Decision-first results window: leads with the conclusion, groups and
%   rounds the numbers, adds a plain-English interpretation, shows the fitted curve,
%   and offers an interactive "reliability at a height" tool.
%   MATLAB desktop only (uifigure). In a script, read fields off `result` instead. [addendum POPUP]
    if ~(isdeployed || usejava('desktop'))
        error('show_result:noDisplay', 'show_result needs the MATLAB desktop.');
    end

    % --- unit + a rounding helper -------------------------------------------------
    u = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit), u = result.unit; end

    has_ov = isfield(result, 'has_overlap') && result.has_overlap;

    % percentages used throughout (with sensible fallbacks)
    if isfield(result, 'tail_fraction') && ~isempty(result.tail_fraction)
        pc = 100 * result.tail_fraction;
    else
        pc = 99.9;
    end
    if isfield(result, 'confidence_level') && ~isempty(result.confidence_level)
        C  = result.confidence_level;
    else
        C  = 0.95;
    end
    cc = 100 * C;

    % --- window + master 2x2 grid -------------------------------------------------
    h  = uifigure('Name', 'Neyer - breaking-height results', 'Position', [100 100 940 640]);
    gl = uigridlayout(h, [2 2]);
    gl.RowHeight    = {'1x', 190};
    gl.ColumnWidth  = {380, '1x'};
    gl.Padding      = [12 12 12 12];
    gl.RowSpacing   = 10;
    gl.ColumnSpacing= 10;

    % =============================================================================
    %  TOP-LEFT (1,1): the answer panel
    % =============================================================================
    pAns = uipanel(gl, 'Title', 'Results', 'FontWeight', 'bold');
    pAns.Layout.Row = 1; pAns.Layout.Column = 1;

    if ~has_ov || ~isfield(result, 'mu') || isempty(result.mu) || isnan(result.mu)
        % --- no result yet: single message, skip the rest -----------------------
        gA = uigridlayout(pAns, [1 1]); gA.Padding = [10 10 10 10];
        uilabel(gA, 'Text', 'No result yet - run more parts.', ...
                'FontSize', 16, 'FontWeight', 'bold', 'WordWrap', 'on');
    else
        mu = result.mu;
        no_fire  = getf(result, 'no_fire',  NaN);
        all_fire = getf(result, 'all_fire', NaN);
        sigma    = getf(result, 'sigma',    NaN);
        mu_lo    = getf(result, 'mu_lo',    NaN);
        mu_hi    = getf(result, 'mu_hi',    NaN);
        n        = getf(result, 'n',        NaN);

        % 9 stacked labels (fixed heights keep the layout predictable)
        gA = uigridlayout(pAns, [9 1]);
        gA.RowHeight   = {34, 24, 24, 8, 20, 20, 20, 'fit', '1x'};
        gA.ColumnWidth = {'1x'};
        gA.Padding     = [10 10 10 10];
        gA.RowSpacing  = 4;

        % 1. headline
        uilabel(gA, 'Text', sprintf('Average breaking height:  %.2f %s', mu, u), ...
                'FontSize', 20, 'FontWeight', 'bold', 'WordWrap', 'on');
        % 2. safe (green)
        uilabel(gA, 'Text', sprintf('Safe: ~%.4g%% survive below %.2f %s', pc, no_fire, u), ...
                'FontColor', [0.16 0.44 0.22], 'FontWeight', 'bold');
        % 3. fails (red/clay)
        uilabel(gA, 'Text', sprintf('Fails: ~%.4g%% break above %.2f %s', pc, all_fire, u), ...
                'FontColor', [0.60 0.25 0.20], 'FontWeight', 'bold');
        % 4. thin separator gap
        uilabel(gA, 'Text', '');
        % 5-7. detail labels
        uilabel(gA, 'Text', sprintf('%.4g%% sure the average is %.2f-%.2f %s', cc, mu_lo, mu_hi, u), ...
                'FontSize', 12);
        uilabel(gA, 'Text', sprintf('Spread (how much parts vary): %.2f %s', sigma, u), ...
                'FontSize', 12);
        uilabel(gA, 'Text', sprintf('Based on %d tests', n), 'FontSize', 12);
        % 8. plain-English interpretation
        uilabel(gA, 'Text', sprintf(['In plain terms: the average part breaks around %.2f %s. Parts dropped below about ' ...
            '%.2f %s almost never break (~%.4g%% survive); above about %.2f %s they almost always break ' ...
            '(~%.4g%% break). These edges are less certain than the average.'], ...
            mu, u, no_fire, u, pc, all_fire, u, pc), ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.30 0.30 0.30]);
        % 9. plain-language "How to read the chart" block (no jargon)
        uilabel(gA, 'Text', sprintf(['How to read the chart:\n' ...
            '- The curve shows how likely a part is to break at each height.\n' ...
            '- Its highest point (the peak) is the most common breaking height - the average.\n' ...
            '- The wider the curve, the more parts differ from each other.\n' ...
            '- Below the green line almost no parts break; above the red line almost all do.\n' ...
            '- The up-down axis is relative: taller just means "more parts break around here".']), ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.20 0.20 0.20]);
    end

    % =============================================================================
    %  TOP-RIGHT (1,2): the chart
    % =============================================================================
    ax = uiaxes(gl);
    ax.Layout.Row = 1; ax.Layout.Column = 2;
    if has_ov && isfield(result, 'mu') && ~isempty(result.mu) && ~isnan(result.mu)
        try
            draw_distribution(ax, result);
        catch
            title(ax, 'Chart unavailable');
        end
    else
        title(ax, 'No result yet');
    end

    % =============================================================================
    %  BOTTOM (2, span both columns): interactive reliability tool
    % =============================================================================
    pRel = uipanel(gl, 'Title', 'Reliability at a height', 'FontWeight', 'bold');
    pRel.Layout.Row = 2; pRel.Layout.Column = [1 2];

    % two rows: a plain-language explainer on top, the controls below
    gRel = uigridlayout(pRel, [2 1]);
    gRel.RowHeight    = {'fit', 'fit'};
    gRel.ColumnWidth  = {'1x'};
    gRel.Padding      = [10 8 10 8];
    gRel.RowSpacing   = 6;

    uilabel(gRel, 'Text', sprintf([ ...
        'Reliability at a height - answer "at THIS drop height, what fraction of parts break (or survive)?"\n' ...
        '  - Type a height and pick break or survive.\n' ...
        '  - Click Calculate.\n' ...
        '  - You get the best estimate plus a confidence-backed floor ' ...
        '(e.g. "95%% confident at least 88%% break").']), ...
        'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.20 0.20 0.20]);

    gR = uigridlayout(gRel, [1 7]);
    gR.ColumnWidth = {55, 90, 40, 110, 100, 120, '1x'};
    gR.RowHeight   = {'fit'};
    gR.Padding     = [0 4 0 4];
    gR.ColumnSpacing = 8;

    uilabel(gR, 'Text', 'Height:', 'HorizontalAlignment', 'right');

    defVal = 0;
    if isfield(result, 'mu') && ~isempty(result.mu) && ~isnan(result.mu)
        defVal = round(result.mu);
    end
    hEdit = uieditfield(gR, 'numeric', 'Value', defVal);

    uilabel(gR, 'Text', u);

    hDrop = uidropdown(gR, 'Items', {'break', 'survive'});

    hBtn  = uibutton(gR, 'Text', 'Calculate');

    hOut  = uilabel(gR, 'Text', '', 'WordWrap', 'on');

    hSave = uibutton(gR, 'Text', 'Save results...');
    hSave.Layout.Column = 6;
    hOut.Layout.Column  = 7;
    if has_ov && isfield(result, 'levels') && ~isempty(result.levels)
        hSave.ButtonPushedFcn = @(~,~) save_from_window(result, ax, h);
    else
        hSave.Enable = 'off';
    end

    if has_ov && isfield(result, 'levels') && isfield(result, 'successes')
        % capture what the callback needs in a closure
        hBtn.ButtonPushedFcn = @(~, ~) do_reliability(result, u, C, hEdit, hDrop, hOut);
    else
        hBtn.Enable  = 'off';
        hOut.Text    = 'needs a completed run';
    end
end

% =================================================================================
function do_reliability(result, u, C, hEdit, hDrop, hOut)
%DO_RELIABILITY  Button callback: compute the reliability at the entered height.
    try
        x    = hEdit.Value;
        tail = hDrop.Value;
        r    = reliability_at_height(result.levels, result.successes, tail, x, C);
        if isnan(r.bound_percent) || isnan(r.percent)
            hOut.Text = 'No result yet - run more parts.';
            return;
        end
        hOut.Text = sprintf(['At %.2f %s: %.4g%% confident at least %.4g%% of parts %s ' ...
            '(best estimate %.4g%%).'], x, u, 100*C, r.bound_percent, tail, r.percent);
    catch err
        hOut.Text = sprintf('Could not calculate: %s', err.message);
    end
end

% =================================================================================
function v = getf(s, name, dflt)
%GETF  Field value with a default (guards missing/empty fields).
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end

% =================================================================================
function save_from_window(result, ax, parentFig)
%SAVE_FROM_WINDOW  Export the current result to CSV + a self-contained HTML report.
    [f, p] = uiputfile({'*.html','Report + data (HTML/CSV)'}, 'Save results as', ...
                       'drop-test-results.html');
    if isequal(f, 0), return; end
    base = fullfile(p, f);
    img_b64 = '';
    try
        tmp = [tempname '.png'];
        exportgraphics(ax, tmp, 'Resolution', 120);
        fid = fopen(tmp, 'r'); bytes = fread(fid, Inf, '*uint8'); fclose(fid);
        img_b64 = matlab.net.base64encode(bytes);
        delete(tmp);
    catch
        img_b64 = '';   % report still saves, just without the picture
    end
    csv_text  = results_to_csv_text(result);
    html_text = results_to_html(result, img_b64);
    paths = save_results_files(base, csv_text, html_text);
    uialert(parentFig, sprintf('Saved:\n%s\n%s', paths.csv, paths.html), ...
            'Results saved', 'Icon', 'success');
end


% ==== from src/workflow/plan_prep.m ====
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


% ==== from src/workflow/run_test_ui.m ====
function result = run_test_ui(cfg0)
%RUN_TEST_UI  Run a Neyer test through large, readable pop-up windows (MATLAB
%   desktop only): a settings window, then a big Break/Survive window per drop,
%   then the results window. Thin GUI shell over the unchanged engine; input
%   validation lives in parse_run_inputs. In a script use run_test instead. [addendum POPUP]
    if ~(isdeployed || usejava('desktop'))
        error('run_test_ui:noDisplay', ...
              'run_test_ui needs the MATLAB desktop; in a script use run_test instead.');
    end
    parsed = ask_settings_ui();
    if isempty(parsed), fprintf('run_test_ui: cancelled.\n'); result = []; return; end
    if nargin >= 1 && ~isempty(cfg0)
        f = fieldnames(cfg0);
        for i = 1:numel(f), parsed.cfg.(f{i}) = cfg0.(f{i}); end
    end
    try
        result = run_test(parsed.params, parsed.num_parts, @(level,k) drop_popup(level,k,parsed.num_parts), parsed.cfg);
    catch e
        if strcmp(e.identifier, 'run_test_ui:aborted')
            fprintf('run_test_ui: cancelled during testing.\n'); result = []; return;
        end
        rethrow(e);
    end
    try, show_result(result); catch, end
end

% =================================================================================
function parsed = ask_settings_ui()
%ASK_SETTINGS_UI  Large, readable settings window. Returns a parsed struct or [].
    labels = {'Low guess for the average height (mm):', ...
              'High guess for the average height (mm):', ...
              'Rough guess of the spread (mm):', ...
              'Number of parts to test:', ...
              'Rig minimum height (mm; blank = none):', ...
              'Unit for heights (mm / cm / m / km):'};
    defs = {'0.6','1.4','0.10','20','0','mm'};

    fig = uifigure('Name', 'Neyer - your inputs', 'Position', [280 170 600 520]);
    gl  = uigridlayout(fig, [8 2]);
    gl.RowHeight     = {46, 46, 46, 46, 46, 46, 46, 54};
    gl.ColumnWidth   = {'1x', 190};
    gl.Padding       = [28 24 28 24];
    gl.RowSpacing    = 12;
    gl.ColumnSpacing = 16;

    ttl = uilabel(gl, 'Text', 'Enter your test settings', 'FontSize', 20, 'FontWeight', 'bold');
    ttl.Layout.Row = 1; ttl.Layout.Column = [1 2];

    edits = gobjects(1, 6);
    for i = 1:6
        lb = uilabel(gl, 'Text', labels{i}, 'FontSize', 15, 'WordWrap', 'on');
        lb.Layout.Row = i + 1; lb.Layout.Column = 1;
        edits(i) = uieditfield(gl, 'text', 'Value', defs{i}, 'FontSize', 16);
        edits(i).Layout.Row = i + 1; edits(i).Layout.Column = 2;
    end

    bp = uigridlayout(gl, [1 2]);
    bp.Layout.Row = 8; bp.Layout.Column = [1 2];
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
        answers = cell(1, 6);
        for j = 1:6, answers{j} = edits(j).Value; end
        try
            store.parsed = parse_run_inputs(answers);
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

% =================================================================================
function r = drop_popup(level, k, N)
%DROP_POPUP  Large, readable Break/Survive window for one drop. Returns logical.
    fig = uifigure('Name', 'Neyer drop test', 'Position', [330 240 500 300]);
    gl  = uigridlayout(fig, [3 2]);
    gl.RowHeight     = {'fit', '1x', 64};
    gl.ColumnWidth   = {'1x', '1x'};
    gl.Padding       = [30 24 30 24];
    gl.RowSpacing    = 16;
    gl.ColumnSpacing = 16;

    l1 = uilabel(gl, 'Text', sprintf('Test %d of %d', k, N), ...
                 'FontSize', 16, 'FontColor', [0.38 0.38 0.38], 'HorizontalAlignment', 'center');
    l1.Layout.Row = 1; l1.Layout.Column = [1 2];
    l2 = uilabel(gl, 'Text', sprintf('Set the height to %.2f mm.\nDid the part break?', level), ...
                 'FontSize', 22, 'FontWeight', 'bold', 'WordWrap', 'on', 'HorizontalAlignment', 'center');
    l2.Layout.Row = 2; l2.Layout.Column = [1 2];

    store = struct('v', []);
    bB = uibutton(gl, 'Text', 'Break', 'FontSize', 19, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.80 0.45 0.38], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) dropPick(true));
    bB.Layout.Row = 3; bB.Layout.Column = 1;
    bS = uibutton(gl, 'Text', 'Survive', 'FontSize', 19, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.30 0.55 0.42], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) dropPick(false));
    bS.Layout.Row = 3; bS.Layout.Column = 2;

    fig.CloseRequestFcn = @(~,~) dropPick([]);
    uiwait(fig);
    v = store.v;
    if isvalid(fig), delete(fig); end
    if isempty(v), error('run_test_ui:aborted', 'cancelled by operator.'); end
    r = v;

    function dropPick(val)
        store.v = val;
        uiresume(fig);
    end
end


% ==== from src/workflow/results_to_csv_text.m ====
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
    L{end+1} = sprintf('test,height (%s),outcome', u);
    for k = 1:n
        if sc(k), o = 'break'; else, o = 'survive'; end
        L{end+1} = sprintf('%d,%.2f,%s', k, lv(k), o);
    end
    L{end+1} = '';
    L{end+1} = 'summary,value,unit';
    L{end+1} = sprintf('Average breaking height,%.4f,%s', csv_field(result,'mu',NaN), u);
    L{end+1} = sprintf('Spread,%.4f,%s',                  csv_field(result,'sigma',NaN), u);
    L{end+1} = sprintf('95%% average low,%.4f,%s',        csv_field(result,'mu_lo',NaN), u);
    L{end+1} = sprintf('95%% average high,%.4f,%s',       csv_field(result,'mu_hi',NaN), u);
    L{end+1} = sprintf('Safe below (~%.4g%% survive),%.4f,%s',  pc, csv_field(result,'no_fire',NaN), u);
    L{end+1} = sprintf('Breaks above (~%.4g%% break),%.4f,%s',  pc, csv_field(result,'all_fire',NaN), u);
    L{end+1} = sprintf('Tests,%d,', n);

    txt = strjoin(L, sprintf('\n'));
end

function v = csv_field(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name)) && ~isnan(s.(name)), v = s.(name);
    else, v = dflt; end
end


% ==== from src/workflow/results_to_html.m ====
function txt = results_to_html(result, img_b64)
%RESULTS_TO_HTML  Build a self-contained HTML results report (as text).
%   txt = RESULTS_TO_HTML(result, img_b64) returns a single HTML document with
%   the plain-language elaboration, the headline numbers, and the fitted-curve
%   chart embedded inline as a base64 PNG (img_b64, '' for none). Opens in any
%   browser; nothing external to load. Pure (no file IO). [compiled-app]
    if nargin < 2 || isempty(img_b64), img_b64 = ''; end
    u = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit), u = result.unit; end
    mu  = html_field(result,'mu',NaN);   sg = html_field(result,'sigma',NaN);
    lo  = html_field(result,'mu_lo',NaN); hi = html_field(result,'mu_hi',NaN);
    nf  = html_field(result,'no_fire',NaN); af = html_field(result,'all_fire',NaN);
    n   = numel(result.levels);
    pc  = 99.9;   % tail percentage, from the run's settings (default 99.9)
    if isfield(result, 'tail_fraction') && ~isempty(result.tail_fraction), pc = 100 * result.tail_fraction; end

    if isempty(img_b64)
        imgTag = '<p><em>(chart not available)</em></p>';
    else
        imgTag = sprintf('<img alt="fitted curve" style="max-width:100%%" src="data:image/png;base64,%s">', img_b64);
    end

    txt = strjoin({ ...
      '<!doctype html><html><head><meta charset="utf-8">', ...
      '<title>Drop-test results</title>', ...
      '<style>body{font-family:system-ui,Arial,sans-serif;max-width:760px;margin:2rem auto;padding:0 1rem;color:#222}h1{font-size:1.5rem}.big{font-size:1.3rem;font-weight:bold}.safe{color:#2a7040}.fail{color:#993f33}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:4px 8px;text-align:left}</style>', ...
      '</head><body>', ...
      '<h1>Drop-test results</h1>', ...
      sprintf('<p class="big">Average breaking height: %.2f %s</p>', mu, u), ...
      sprintf('<p class="safe">Safe: about %.4g%% of parts survive below %.2f %s.</p>', pc, nf, u), ...
      sprintf('<p class="fail">Fails: about %.4g%% of parts break above %.2f %s.</p>', pc, af, u), ...
      sprintf('<p>We are 95%% sure the true average is between %.2f and %.2f %s. The spread (how much parts vary) is about %.2f %s. Based on %d tests.</p>', lo, hi, u, sg, u, n), ...
      '<p>In plain terms: the average part breaks around the height above. Below the safe height almost nothing breaks; above the fails height almost everything breaks. The two edges are less certain than the average.</p>', ...
      '<h2>Fitted curve</h2>', imgTag, ...
      '<hr><p style="color:#777;font-size:.85rem">Generated by the D-Optimal Sensitivity Tool. Neyer (1994) D-optimal sensitivity method.</p>', ...
      '</body></html>' }, sprintf('\n'));
end

function v = html_field(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name)) && ~isnan(s.(name)), v = s.(name);
    else, v = dflt; end
end


% ==== from src/workflow/save_results_files.m ====
function paths = save_results_files(base, csv_text, html_text)
%SAVE_RESULTS_FILES  Write CSV + HTML report text to <base>.csv / <base>.html.
%   paths = SAVE_RESULTS_FILES(base, csv_text, html_text) writes the two files
%   next to each other, sharing the base name the user chose. Returns a struct
%   with .csv and .html full paths. Base-MATLAB file IO. [compiled-app]
    [d, name, ~] = fileparts(base);
    if isempty(name), name = 'drop-test-results'; end
    paths = struct('csv', fullfile(d, [name '.csv']), ...
                   'html', fullfile(d, [name '.html']));
    write_text(paths.csv,  csv_text);
    write_text(paths.html, html_text);
end

function write_text(p, txt)
    fid = fopen(p, 'w');
    if fid < 0, error('save_results_files:cannotWrite', 'Cannot write %s', p); end
    fwrite(fid, txt);
    fclose(fid);
end


% ==== from src/workflow/plan_prep_message.m ====
function msg = plan_prep_message(pr, u)
%PLAN_PREP_MESSAGE  Plain-language popup text for the pre-test planner.
%   msg = PLAN_PREP_MESSAGE(pr, u) turns a plan_prep_numbers result `pr` into a
%   friendly message: how many parts to prepare and the first drop height, with
%   the brute-force contrast as reassurance. Pure. [compiled-app]
    if nargin < 2 || isempty(u), u = 'mm'; end
    msg = sprintf([ ...
        'Prepare %d parts.\n\n' ...
        'Start your first drop at %.2f %s (the middle of your guess).\n\n' ...
        'This targets %.4g%% reliability at %.4g%% confidence.\n' ...
        'A blind trial-and-error approach would need about %d parts for the same goal, ' ...
        'so the method saves you a lot of prints.'], ...
        pr.n_parts, pr.start_height, u, 100*pr.R, 100*pr.C, pr.n_bogey);
end


% ==== from src/workflow/run_demo.m ====
function d = run_demo()
%RUN_DEMO  Replay Neyer's published 20 outcomes and self-check the result.
%   d = RUN_DEMO() runs the tool on the fixed Table-1 outcome sequence (no
%   physical testing, no input) and compares the fitted average/spread against
%   the paper's published gate (5.3922 / 1.0412). Backs the compiled app's
%   "Run a Demo (verify)" button: one press proves the .exe matches the paper.
%   Returns a struct: .result (the run), .expected_mu, .expected_sigma,
%   .got_mu, .got_sigma, .is_match, .tol. [compiled-app]
    fixed  = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
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


% ==== from src/workflow/show_manual.m ====
function show_manual()
%SHOW_MANUAL  Show the built-in user manual in a scrollable window. [compiled-app]
%   The manual text is EMBEDDED here (no external file), so Help works the same in
%   the .exe, the .mlx, and standalone use -- nothing to find on disk.
    f  = uifigure('Name', 'D-Optimal Sensitivity Tool - Help', 'Position', [340 180 680 600]);
    gl = uigridlayout(f, [1 1]); gl.Padding = [10 10 10 10];
    ta = uitextarea(gl, 'Value', manual_lines(), 'Editable', 'off');
    ta.FontName = 'Consolas';
end

function lines = manual_lines()
%MANUAL_LINES  The user manual as plain text (embedded; no file dependency).
    lines = {
      'D-OPTIMAL SENSITIVITY TOOL - USER MANUAL'
      ''
      'WHAT THIS TOOL DOES'
      'It finds the drop height at which your 3D-printed parts break. Each part is'
      'tested once and either breaks or survives. The tool picks the most informative'
      'height to test next, and from the pattern estimates two numbers: the average'
      'breaking height and the spread (how much parts vary). It also gives a "safe"'
      'height (almost nothing breaks below it) and a "breaks" height (almost everything'
      'breaks above it), each with a confidence range.'
      ''
      'THE MENU (five buttons)'
      '- Pre-Test Planner: before the lab. Enter your guesses; it tells you how many'
      '  parts to prepare and where to make the first drop.'
      '- Run a Test: the real experiment. Enter your inputs, then for each part the'
      '  tool shows the height to set; you drop it and click Break or Survive.'
      '- Reliability Calculator: after a test, ask "at this height, what fraction of'
      '  parts break/survive?"'
      '- Run a Demo (verify): replays a published example; must show 5.3922 / 1.0412'
      '  MATCH. Press it any time to trust the tool.'
      '- Help: opens this manual.'
      ''
      'YOUR INPUTS'
      '- Low / high guess for the average height (mm): a rough bracket for where'
      '  parts break.'
      '- Rough guess of the spread (mm): how much parts vary; a rough number is fine.'
      '- Number of parts to test: how many you will drop (20-30+ recommended).'
      '- Rig minimum height (mm): the lowest your rig can set (e.g. 0). Blank = none.'
      '- Unit: mm, cm, m, or km (a label only; all numbers stay in that unit).'
      ''
      'DOING THE DROPS'
      'For each part the tool shows "Test k of N - set the height to X mm". Set your'
      'rig to X, drop the part, and click Break or Survive. Cancel stops the run.'
      ''
      'READING THE RESULTS'
      '- Average breaking height: the headline number.'
      '- Safe (green): below this height, almost nothing breaks.'
      '- Fails (red): above this height, almost everything breaks.'
      '- 95% range: we are 95% sure the true average is between these two numbers.'
      '- The chart: the curve shows how likely a part is to break at each height; its'
      '  peak is the average; a wider curve means parts vary more.'
      '- Save results...: writes a CSV of every drop plus a picture-and-words HTML'
      '  report you can open in any browser or hand in.'
      ''
      'CONFIDENCE vs RELIABILITY  (they are DIFFERENT things)'
      '- RELIABILITY is about the PARTS: what fraction survive or break at a given'
      '  height (e.g. 99.9% survive). It answers "how often does the part hold?"'
      '- CONFIDENCE is about OUR ANSWER: how sure we are, given we only tested a few'
      '  parts (e.g. 95% confident). It answers "how much should you trust the number?"'
      '- Together: "95% confident at least 88% break at 6 mm" -> the 88% is'
      '  RELIABILITY, the 95% is CONFIDENCE.'
      '- Turning confidence UP gives a bigger safety margin (more certainty demanded'
      '  from limited data). Turning reliability UP pushes to a more extreme height.'
      '- One line to remember: reliability is about the parts; confidence is about us.'
      ''
      'IF YOUR PARTS ARE INCONSISTENT (the tool stays honest)'
      '3D prints vary. A part that breaks low, where a good one would survive, is DATA,'
      'not an error - the tool folds it in, and it shows up as a BIGGER SPREAD (a wide,'
      'flat curve). You will see: a large spread; a safe height pushed very low, or an'
      'honest "couldn''t pin this down - plan for about N parts" note instead of a fake'
      'number; and wider 95% ranges. What to do: print more parts (the tool says roughly'
      'how many) or improve print consistency. The tool never fakes precision on messy'
      'data - degrading truthfully is the point.'
      ''
      'VERIFY IT WORKS'
      'Press Run a Demo (verify). It must show average 5.3922, spread 1.0412 - MATCH.'
      ''
      'Method: Neyer (1994) D-optimal sensitivity test.'
    };
end


% ==== from src/workflow/neyer_app.m ====
function neyer_app()
%NEYER_APP  Launch menu for the D-Optimal Sensitivity Tool (the compiled app's
%   entry point). Five grouped buttons over the unchanged engine. [compiled-app]
    if ~isdeployed
    end

    state.result = [];      % most recent run, for the Reliability button

    fig = uifigure('Name', 'D-Optimal Sensitivity Tool', 'Position', [300 250 400 360]);
    gl = uigridlayout(fig, [7 1]);
    gl.RowHeight  = {36, 42, 42, 42, 10, 42, 42};
    gl.Padding    = [22 16 22 16];
    gl.RowSpacing = 8;

    title = uilabel(gl, 'Text', 'D-Optimal Sensitivity Tool', 'FontSize', 16, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    title.Layout.Row = 1;

    uibutton(gl, 'Text', 'Pre-Test Planner',      'ButtonPushedFcn', @onPlanner);
    uibutton(gl, 'Text', 'Run a Test',            'ButtonPushedFcn', @onRunTest);
    uibutton(gl, 'Text', 'Reliability Calculator','ButtonPushedFcn', @onReliability);
    uilabel(gl,  'Text', '');   % row 5: separator gap
    uibutton(gl, 'Text', 'Run a Demo (verify)',   'ButtonPushedFcn', @onDemo);
    uibutton(gl, 'Text', 'Help',                  'ButtonPushedFcn', @onHelp);

    % ---- callbacks (nested: share `state` and `fig`) ------------------------
    function onRunTest(~, ~)
        try
            res = run_test_ui();
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
                uialert(fig, sprintf(['Self-check PASSED.\n\nExpected average 5.3922, spread 1.0412.\n' ...
                    'Got %.4f / %.4f.  MATCH.'], d.got_mu, d.got_sigma), ...
                    'Demo verified', 'Icon', 'success');
            else
                uialert(fig, sprintf(['Self-check MISMATCH.\n\nExpected 5.3922 / 1.0412, got %.4f / %.4f.\n' ...
                    'Do not trust this build.'], d.got_mu, d.got_sigma), ...
                    'Demo FAILED', 'Icon', 'error');
            end
        catch err
            uialert(fig, err.message, 'Demo could not run');
        end
    end

    function onPlanner(~, ~)
        try
            a = inputdlg({'Low guess for the average height:', 'High guess for the average height:', ...
                          'Reliability you want (e.g. 0.999):', 'Confidence (e.g. 0.95):', 'Unit:'}, ...
                         'Pre-Test Planner', 1, {'0.6','1.4','0.999','0.95','mm'});
            if isempty(a), return; end
            params = struct('avg_low', str2double(a{1}), 'avg_high', str2double(a{2}));
            pr = plan_prep_numbers(params, str2double(a{3}), str2double(a{4}));
            uialert(fig, plan_prep_message(pr, a{5}), 'Pre-Test Plan', 'Icon', 'info');
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
        try, show_result(state.result); catch err, uialert(fig, err.message, 'Could not open'); end
    end

    function onHelp(~, ~)
        try, show_manual(); catch err, uialert(fig, err.message, 'Help unavailable'); end
    end
end


% ==== from run_test.m ====
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
%     outcome_fn  (optional) result = outcome_fn(level, k): true for a break,
%                 false for a survive. If omitted, the operator is prompted at
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
    prompt = sprintf('Test %d - set level to %.4f. Did it break? (1=break / 0=survive): ', ...
                     k, level);
    r = logical(input(prompt));
end
