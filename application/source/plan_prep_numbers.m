function res = plan_prep_numbers(params, R, C, cfg)
%PLAN_PREP_NUMBERS  Pure core of the pre-lab planner: parts count + first height.
%   res = PLAN_PREP_NUMBERS(params, R, C, cfg) returns how many parts to prepare
%   for reliability R at confidence C, and the height of the first drop -- with NO
%   printing. Reuses plan_samples (the verified engine) so the sample-size math has
%   a single home. The V1.10 planner call is PLAN_PREP_NUMBERS(clean, model),
%   where clean is validated planner input and model is a reachable-gap model.
%   The older four-argument call remains available only for compatibility with
%   recorded compatibility tests while the user interface uses the guided planner.
    if nargin >= 2 && isstruct(params) && isfield(params, 'mode') && ...
            isstruct(R) && isfield(R, 'gaps_mm')
        res = estimate_study_plan(params, R);
        return;
    end
    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if ~(isfield(params, 'avg_low') && isfield(params, 'avg_high'))
        error('plan_prep_numbers:missingField', 'params needs avg_low and avg_high.');
    end
    lo = params.avg_low; hi = params.avg_high;
    if ~(isscalar(lo) && isscalar(hi) && isreal(lo) && isreal(hi) ...
         && isfinite(lo) && isfinite(hi) && lo < hi)
        error('plan_prep_numbers:badBounds', ...
              'need finite avg_low (%.4g) < avg_high (%.4g).', lo, hi);
    end
    p = plan_samples('break', R, C, cfg, struct('sigma', 1));   % sigma cancels
    res = struct('n_parts', p.n_recommended, ...
                 'start_height', (lo + hi) / 2, ...
                 'R', R, 'C', C, ...
                 'n_floor', p.n_floor, 'n_bogey', p.n_bogey, ...
                 'floor_reason', p.floor_reason);
end
