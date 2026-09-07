function [gap_mm, status] = round_reachable_gap(raw_gap_mm, outcome, model, previous_gap_mm)
%ROUND_REACHABLE_GAP Move a mathematical limit to a physically safe setting.
% Interaction moves down (same gap or smaller). No interaction moves up
% (same gap or larger). A previously used setting is excluded when supplied.

    if nargin < 4, previous_gap_mm = []; end
    if ~(isnumeric(raw_gap_mm) && isscalar(raw_gap_mm) && ...
            isreal(raw_gap_mm) && isfinite(raw_gap_mm))
        error('round_reachable_gap:badGap', ...
            'The mathematical gap must be one finite number.');
    end
    if ~isstruct(model) || ~all(isfield(model, ...
            {'gaps_mm', 'instructions', 'comparison_tolerance_mm'}))
        error('round_reachable_gap:badModel', ...
            'A reachable-gap model is required before safe rounding.');
    end
    target = lower(strtrim(char(string(outcome))));
    tolerance = model.comparison_tolerance_mm;
    gaps = model.gaps_mm(:);

    if strcmp(target, 'interaction')
        safe = gaps <= raw_gap_mm + tolerance;
    elseif strcmp(target, 'no_interaction')
        safe = gaps >= raw_gap_mm - tolerance;
    else
        error('round_reachable_gap:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end
    had_safe_setting = any(safe);

    if ~isempty(previous_gap_mm)
        if ~(isnumeric(previous_gap_mm) && isscalar(previous_gap_mm) && ...
                isreal(previous_gap_mm) && isfinite(previous_gap_mm))
            error('round_reachable_gap:badPreviousGap', ...
                'The previous requested gap must be one finite number.');
        end
        safe = safe & abs(gaps - previous_gap_mm) > tolerance;
    end

    candidate_rows = find(safe);
    if isempty(candidate_rows)
        gap_mm = NaN;
        if had_safe_setting && ~isempty(previous_gap_mm)
            code = 'no_different_setting';
            message = ['No different reachable and safe setting remains. ' ...
                'Review the physical setup before continuing.'];
        else
            code = 'no_safe_setting';
            message = ['The confidence limit has no safely rounded reachable ' ...
                'setting inside the permitted range.'];
        end
        status = struct('code', code, 'message', message, ...
            'display_gap', "Not established", 'instruction', "", ...
            'raw_gap_mm', raw_gap_mm);
        return;
    end

    [~, nearest_position] = min(abs(gaps(candidate_rows) - raw_gap_mm));
    chosen_row = candidate_rows(nearest_position);
    gap_mm = gaps(chosen_row);
    status = struct('code', 'ok', 'message', ...
        'A reachable setting was selected in the safe direction.', ...
        'display_gap', string(sprintf('%.2f mm', gap_mm)), ...
        'instruction', model.instructions(chosen_row), ...
        'raw_gap_mm', raw_gap_mm);
end
