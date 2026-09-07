function opts = pl_opts()
%PL_OPTS  Shared optimiser options for profile-likelihood inner maximisation.
%   Base optimset only (no toolbox). Used by lr_confidence and the
%   reliability-at-confidence units (Mode A/B, planner).  [addendum LR / RAC]
    opts = optimset('TolX', 1e-8, 'TolFun', 1e-10, 'MaxFunEvals', 1e4, 'MaxIter', 1e4);
end
