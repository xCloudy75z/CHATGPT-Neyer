function s = shape_model(x, mu, sigma)
%SHAPE_MODEL  Worker #1 — the bell curve (the ONLY place the shape lives).
%
%   s = SHAPE_MODEL(x, mu, sigma) evaluates the assumed response shape at one
%   or more physical gaps x, for interaction thresholds that follow a bell
%   curve (normal distribution) with middle gap mu and width sigma.
%
%   It returns the interaction chance at each gap, plus the standard-normal
%   building blocks every other worker needs (z, phi, Phi, Q). Because the
%   shape assumption is quarantined here, swapping the bell curve for another
%   shape (e.g. the logistic) is a single-file change.  [brief sec.4, worker #1]
%
%   Alternate call (inverse):  z = SHAPE_MODEL(p, 'quantile')  goes the other
%   way -- given a probability p in (0,1), it returns how many spreads from the
%   centre that interaction chance sits at (the z with Phi(z) = p). report (#9) uses
%   this to turn a strictness like 99.9% into an all-fire / no-fire level. See
%   the "Inverse (quantile) mode" block below.  [addendum B1]
%
%   Inputs
%     x      physical gap(s); scalar or array of any shape.
%     mu     middle gap, where interaction chance is 50%, scalar.
%     sigma  transition width, scalar, must be > 0.
%
%   Output struct s, every field the same size as x:
%     s.z    standardised gap, z = (mu - x) / sigma
%     s.phi  standard-normal pdf at z, phi(z)                   [brief App.A]
%     s.Phi  standard-normal cdf at z = P(interaction)
%     s.Q    upper tail, Q(z) = 1 - Phi(z) = P(no interaction)
%     s.p    probability of interaction at this gap = s.Phi
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

    % Gap model: interaction becomes less likely as the gap increases.
    z = (mu - x) ./ sigma;

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
