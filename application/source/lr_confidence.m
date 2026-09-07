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
