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
