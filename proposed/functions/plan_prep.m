function res = plan_prep(params, R, C, cfg)
%PLAN_PREP  Pre-lab planner: how many parts to prepare + where to start.
%   res = PLAN_PREP(params, R, C) prints a plain-language prep summary and returns
%   the numbers (see plan_prep_numbers). C defaults to settings().confidence_level.
%   Run this at home BEFORE printing parts. It gives the parts count and the first
%   height only -- the tool picks every height after that. [addendum PREP]
    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end
    if nargin < 3 || isempty(C), C = cfg.confidence_level; end
    res = plan_prep_numbers(params, R, C, cfg);
    fprintf('\n--- Before you start: parts & first height ---\n');
    fprintf('Prepare about %d parts.\n', res.n_parts);
    fprintf('  (Never fewer than %d - %s)\n', res.n_floor, res.floor_reason);
    fprintf('Start your first drop at %.4g mm  (the midpoint of your guess).\n', res.start_height);
    fprintf('Target: %.4g%% of parts, %.4g%% confidence.\n', 100*res.R, 100*res.C);
    fprintf('For contrast, counting failures directly would need about %d parts.\n', res.n_bogey);
    fprintf('This is the count and starting height only - the tool picks every height after that.\n\n');
end
