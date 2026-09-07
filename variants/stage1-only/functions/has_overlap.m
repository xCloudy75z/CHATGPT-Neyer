function tf = has_overlap(levels, successes)
%HAS_OVERLAP  Worker #4 — the Silvapulle condition (Stage 2 -> Stage 3 gate).
%
%   tf = HAS_OVERLAP(levels, successes) answers yes/no: have breaks and
%   survivals started to interleave? Until they do, there is genuinely not
%   enough information to compute a real best-fit, so the loop must stay on the
%   Stage-2 surrogate path. Once they overlap, the MLE exists and Stage 3
%   begins.  [brief sec.3 Stage 2; sec.4 worker #4; sec.8 #2 -- the Silvapulle
%   condition]
%
%   Interleave, in the brief's words, is "a lower level broke while a higher
%   one survived": a success (break) occurring at a strictly lower level than
%   some failure (survive). Equivalently:
%
%       overlap  <=>  min(success levels) < max(failure levels)
%
%   Strict inequality is deliberate: if the lowest break and the highest
%   survive sit at the same level (a boundary tie), the data is still
%   separable and the MLE diverges, so that is NOT overlap.
%
%   Inputs
%     levels     vector of test levels run so far.
%     successes  logical vector, same length: true = break, false = survive.
%
%   Output
%     tf  logical scalar. false if either group is empty (nothing to interleave).

    levels    = levels(:);
    successes = logical(successes(:));

    if numel(levels) ~= numel(successes)
        error('has_overlap:sizeMismatch', ...
              'levels and successes must have the same length.');
    end

    success_levels = levels(successes);
    failure_levels = levels(~successes);

    % Need at least one of each to possibly interleave.
    if isempty(success_levels) || isempty(failure_levels)
        tf = false;
        return;
    end

    tf = min(success_levels) < max(failure_levels);
end
