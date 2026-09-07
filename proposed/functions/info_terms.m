function [j0, j1, j2] = info_terms(x, mu, sigma)
%INFO_TERMS  Fisher information building blocks J0, J1, J2 (Eq.3).
%
%   [j0, j1, j2] = INFO_TERMS(x, mu, sigma) returns, for each level x, the
%   per-test information terms of the bell-curve model:  [brief App.A Eq.3]
%
%       J_j(z) = phi(z)^2 * z^j / ( Phi(z) * Q(z) * sigma^2 ),   z = (x-mu)/sigma
%
%   so j0 = J0, j1 = J1, j2 = J2. Summing these over a set of levels gives the
%   information matrix entries I00, I01(=I10), I11 (Eq.4), used by the D-optimal
%   picker (worker #3) and by the confidence calculation in report (worker #9).
%   Keeping the formula here means the information model lives in exactly one
%   place, just as the shape lives only in shape_model.
%
%   Tail guard (numerical hazard #1, brief sec.8): where Phi*Q underflows to
%   zero far from centre, the ratio becomes Inf/NaN although the true
%   information there is ~0; those entries are set to 0. All shape quantities
%   come from shape_model (worker #1).

    s = shape_model(x, mu, sigma);

    base = (s.phi.^2) ./ (s.Phi .* s.Q .* sigma^2);
    base(~isfinite(base)) = 0;

    j0 = base;
    j1 = base .* s.z;
    j2 = base .* s.z.^2;
end
