function result = report(record, cfg)
%REPORT  Worker #9 — present the final middle gap, transition width, and confidence.
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
            fprintf('Results have not yet overlapped, so the middle gap and transition width\n');
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
    fprintf('TRANSITION WIDTH: %.4f %s\n', sigma, u);
    fprintf('  Smaller means a sharper change; larger means a more gradual change.\n');
    fprintf('  %.4g%% confident the true width is between %.4f and %.4f %s.\n\n', ...
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
