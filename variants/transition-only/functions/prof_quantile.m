function L = prof_quantile(levels, successes, q, ksig, sigma0)
%PROF_QUANTILE  Profiled log-likelihood with the level q = mu + ksig*sigma held
%   fixed: substitute mu = q - ksig*sigma and maximise over sigma>0 (via log sigma).
%   Shared by lr_confidence and the reliability-at-confidence units.  [addendum LR]
    f = @(t) -loglik(levels, successes, q - ksig*exp(t), exp(t));
    that = fminsearch(f, log(sigma0), pl_opts());
    L = -f(that);
end
