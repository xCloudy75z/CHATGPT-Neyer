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
