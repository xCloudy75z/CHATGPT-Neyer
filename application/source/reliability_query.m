function q = reliability_query(result, tail, action, value, C)
%RELIABILITY_QUERY  Plain-language reliability/height/confidence calculator.
%   Interactive:  reliability_query(result)         -- guided menu.
%   Scriptable:   q = reliability_query(result, tail, action, value, C)
%     tail   : 'break' or 'survive'
%     action : 'height_for'     value = reliability R  -> Mode A (height)
%              'reliability_at' value = height x       -> Mode B (reliability)
%              'plan'           value = reliability R  -> sample-size planner
%     C      : confidence in (0,1); defaults to settings().confidence_level.
%   Reads levels/successes/mu/sigma off `result` (the 'plan' action uses result.sigma).
%   [addendum RAC]
    cfg = neyer_settings();
    if nargin < 2
        q = run_menu(result, cfg);        % interactive path (thin I/O shell)
        return;
    end
    if nargin < 5 || isempty(C), C = cfg.confidence_level; end

    target = lower(tail);
    if strcmp(target,'interaction')
        legacy_tail='break';
    elseif strcmp(target,'no_interaction')
        legacy_tail='survive';
    elseif any(strcmp(target,{'break','survive'}))
        legacy_tail=target; % temporary compatibility for inherited callers
    else
        error('reliability_query:badTarget', ...
              'target must be ''interaction'' or ''no_interaction''.');
    end
    levels = result.levels; successes = result.successes;

    switch lower(action)
        case {'gap_for','height_for'}
            q = height_for_reliability(levels, successes, legacy_tail, value, C);
            q.gap=q.height;
            q.target=target;
            q.raw_bound=q.bound;
            q.permitted_range=[cfg.min_level cfg.max_level];
            q.bound_established=isfinite(q.raw_bound) && ...
                q.raw_bound>=cfg.min_level && q.raw_bound<=cfg.max_level;
            if ~q.bound_established
                q.bound=NaN;
            end
            q.gap_within_permitted_range=isfinite(q.gap) && ...
                q.gap>=cfg.min_level && q.gap<=cfg.max_level;
        case {'probability_at','reliability_at'}
            q = reliability_at_height(levels, successes, legacy_tail, value, C);
            q.probability=q.reliability;
            q.bound_probability=q.bound;
            q.gap=q.x;
            q.target=target;
        case 'plan'
            % Banerjee (point-estimate) basis from the fitted spread. This is the
            % up-front asymptotic formula, NOT the exact scaled 1/N basis --
            % report.m does the refined scaled count off n/level/se.
            q = plan_samples(legacy_tail, value, C, cfg, struct('sigma', result.sigma));
        otherwise
            error('reliability_query:badAction', ...
                  'action must be ''gap_for'', ''probability_at'', or ''plan''.');
    end
end

% ---- interactive menu (never called by the test suite) --------------------
% All prompts read text with input(...,'s') and validate via the local helpers
% ask_int_in_set / ask_num_in_range, which loop until the entry is good. A stray
% letter becomes NaN (str2double) and is simply re-asked, never a raw Octave
% error, so a human running the menu cannot crash it or be silently mis-defaulted.
function q = run_menu(result, cfg)
    fprintf('\n--- Reliability calculator ---\n');
    fprintf('  [1] Safe height for a reliability   (I have a target)\n');
    fprintf('  [2] Reliability at a height          (I am stuck with a height)\n');
    fprintf('  [3] How many parts do I need?        (planner)\n');
    mode = ask_int_in_set('Choose 1/2/3: ', [1 2 3]);
    t    = ask_int_in_set('Break or survive? [1] break  [2] survive: ', [1 2]);
    tail = 'break'; if t == 2, tail = 'survive'; end

    if mode == 2
        x = ask_num_in_range('Height (mm): ', -Inf, Inf);   % any finite height
        C = ask_confidence(cfg);
        q = reliability_query(result, tail, 'reliability_at', x, C);
    else
        R = ask_reliability(cfg);
        C = ask_confidence(cfg);
        if mode == 3
            q = reliability_query(result, tail, 'plan', R, C);
        else
            q = reliability_query(result, tail, 'height_for', R, C);
        end
    end
    print_answer(q, tail, cfg);
end

function R = ask_reliability(cfg)
    pr = cfg.reliability_presets;
    fprintf('Reliability?\n');
    for i = 1:numel(pr)
        fprintf('  [%d] 1 in %s  (%.4g%%)\n', i, thousands(1/(1-pr(i))), 100*pr(i));
    end
    own = numel(pr) + 1;
    fprintf('  [%d] type my own %%\n', own);
    c = ask_int_in_set('Choose: ', 1:own);
    if c == own
        pct = ask_num_in_range('Reliability percent (e.g. 99.5): ', 0, 100); % strictly (0,100)
        R = pct / 100;
    else
        R = pr(c);
    end
end

function C = ask_confidence(cfg)
    % Empty (Enter) keeps the default; anything else must be a percent in (0,100).
    while true
        s = input(sprintf('Confidence %% [Enter for %g]: ', 100*cfg.confidence_level), 's');
        if isempty(s), C = cfg.confidence_level; return; end
        v = str2double(s);
        if isscalar(v) && isfinite(v) && v > 0 && v < 100, C = v / 100; return; end
        fprintf('  Please enter a percentage between 0 and 100 (or press Enter for %g).\n', ...
                100*cfg.confidence_level);
    end
end

% ---- input helpers: loop on input() until the entry validates --------------
function v = ask_int_in_set(prompt, allowed)
%ASK_INT_IN_SET  Re-ask until the reply is an integer in the allowed set.
    while true
        x = str2double(input(prompt, 's'));   % 's' so a stray letter -> NaN, not an error
        if isscalar(x) && isfinite(x) && x == round(x) && any(x == allowed)
            v = x; return;
        end
        fprintf('  Please enter one of: %s\n', num2str(allowed));
    end
end

function v = ask_num_in_range(prompt, lo, hi)
%ASK_NUM_IN_RANGE  Re-ask until the reply parses to a number strictly in (lo,hi).
%   lo/hi may be -Inf/+Inf to leave a side open; the bound is always exclusive.
    while true
        x = str2double(input(prompt, 's'));
        if isscalar(x) && isfinite(x) && x > lo && x < hi
            v = x; return;
        end
        if isfinite(lo) && isfinite(hi)
            fprintf('  Please enter a number between %g and %g.\n', lo, hi);
        else
            fprintf('  Please enter a number.\n');
        end
    end
end

function print_answer(q, tail, cfg)
    % Minimal plain-language echo; report.m carries the detailed phrasing.
    fprintf('\n');
    if isfield(q, 'height')
        verb = 'break at >='; if strcmp(tail,'survive'), verb = 'survive below'; end
        fprintf('%.4g%% confident that %.4g%% of parts %s %.2f mm.\n', ...
                100*q.C, 100*q.R, verb, q.bound);
    elseif isfield(q, 'reliability')
        fprintf('At %.2f mm: %.4g%% confident at least %.4g%% of parts %s.\n', ...
                q.x, 100*q.C, q.bound_percent, tail);
    elseif isfield(q, 'n_recommended')
        fprintf('Plan for about %d parts. %s\n', q.n_recommended, q.caveat);
        fprintf('(Why at least %d: %s)\n', q.n_floor, q.floor_reason);
        fprintf('(Counting failures directly would need ~%d parts.)\n', q.n_bogey);
    end
end

function s = thousands(x)
%THOUSANDS  Format a number with comma separators (e.g. 1000000 -> 1,000,000).
    s = sprintf('%.0f', x);
    out = '';
    n = numel(s);
    for i = 1:n
        out = [out, s(i)];
        r = n - i;
        if r > 0 && mod(r,3) == 0, out = [out, ',']; end
    end
    s = out;
end
