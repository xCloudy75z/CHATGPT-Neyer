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
