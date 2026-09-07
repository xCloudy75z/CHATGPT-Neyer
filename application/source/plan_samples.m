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
