function tf = has_overlap(levels, successes)
%HAS_OVERLAP  Worker #4 — the Silvapulle condition (Stage 2 -> Stage 3 gate).
%
%   tf = HAS_OVERLAP(levels, successes) answers yes/no: have interaction and
%   no-interaction results started to interleave? Until they do, there is
%   enough information to compute a real best-fit, so the loop must stay on the
%   Stage-2 surrogate path. Once they overlap, the MLE exists and Stage 3
%   begins.  [brief sec.3 Stage 2; sec.4 worker #4; sec.8 #2 -- the Silvapulle
%   condition]
%
%   In this decreasing-gap model, overlap means an interaction occurred at a
%   strictly larger gap than at least one no-interaction result. Equivalently:
%
%       overlap  <=>  max(interaction gaps) > min(no-interaction gaps)
%
%   Strict inequality is deliberate: if the two outcomes occur only at the
%   same boundary gap, the data is still
%   separable and the MLE diverges, so that is NOT overlap.
%
%   Inputs
%     levels     vector of test levels run so far.
%     successes  logical vector: true = interaction, false = no interaction.
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

    % Gap model decreases: overlap requires an interaction at a larger gap
    % than at least one non-interaction.
    tf = max(success_levels) > min(failure_levels);
end
