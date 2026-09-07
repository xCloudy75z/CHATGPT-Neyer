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
    c1   = shape_model(C, 'quantile')^2;
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
