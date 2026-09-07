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
