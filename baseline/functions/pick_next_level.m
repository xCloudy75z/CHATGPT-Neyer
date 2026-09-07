function [x_next, det_max] = pick_next_level(levels, mu, sigma, cfg, side_pref)
%PICK_NEXT_LEVEL  Worker #3 — the D-optimal picker (the method's heart).
%
%   x = PICK_NEXT_LEVEL(levels, mu, sigma) returns the single next test level
%   that sharpens the current estimate the most: the level that maximises the
%   determinant of the Fisher information matrix.  [brief sec.4 worker #3;
%   App.A "D-optimal objective"]
%
%       det(I) = I00*I11 - I01^2
%
%   where, summed over the already-tested levels plus the candidate level,
%   using the Eq.3 building blocks J_j(z) = phi(z)^2 * z^j / (Phi*Q*sigma^2):
%
%       I00 = sum J0 ,  I01 = sum J1 ,  I11 = sum J2 .
%
%   In words: maximise (knowledge of average) x (knowledge of spread) minus
%   (entanglement)^2. The maximiser emerges near +/-1.138 spreads from centre
%   on its own -- it is found, not hard-coded.
%
%   Inputs
%     levels   levels already tested (column or row). Their information,
%              evaluated at the current estimate, forms the running matrix.
%     mu, sigma  the current best estimate (centre and spread).
%     cfg      settings struct (optional; defaults to settings()). Uses
%              cfg.search_window_sigmas (the fence) and cfg.grid_points.
%     side_pref  optional -1 / 0 / +1. 0 (default) = search both sides and
%              take the global best. +1 restricts to x >= mu, -1 to x <= mu.
%              choose_stage (#6) can use this to enforce the alternate-sides
%              balancing policy; the core stays a pure determinant search.
%
%   Outputs
%     x_next   the chosen next level.
%     det_max  det(I) achieved there (diagnostic).
%
%   Guardrail (numerical hazard #1, brief sec.8): the candidate search is
%   fenced to +/- search_window_sigmas spreads, and the information term is
%   guarded so far-out levels (where Phi*Q underflows) contribute ~0 instead
%   of producing NaN/Inf. All shape quantities come from worker #1.

    if nargin < 4 || isempty(cfg),       cfg = neyer_settings();   end
    if nargin < 5 || isempty(side_pref), side_pref = 0;      end

    levels = levels(:);

    % Running information from the already-tested levels at the current estimate.
    [I00e, I01e, I11e] = info_sum(levels, mu, sigma);

    % Fenced candidate grid around the current centre.
    W  = cfg.search_window_sigmas;
    n  = cfg.grid_points;
    xs = linspace(mu - W*sigma, mu + W*sigma, n)';

    if side_pref > 0
        xs = xs(xs >= mu);
    elseif side_pref < 0
        xs = xs(xs <= mu);
    end

    % Information each candidate would add (guarded against tail blow-up).
    [j0, j1, j2] = info_terms(xs, mu, sigma);

    I00 = I00e + j0;
    I01 = I01e + j1;
    I11 = I11e + j2;

    det = I00 .* I11 - I01.^2;

    [det_max, k] = max(det);
    x_next = xs(k);
end

% -------------------------------------------------------------------------
function [I00, I01, I11] = info_sum(levels, mu, sigma)
%INFO_SUM  Sum the Eq.4 information matrix over a set of levels.
    if isempty(levels)
        I00 = 0; I01 = 0; I11 = 0;
        return;
    end
    [j0, j1, j2] = info_terms(levels, mu, sigma);   % shared helper (Eq.3)
    I00 = sum(j0);
    I01 = sum(j1);
    I11 = sum(j2);
end
