function [requested_gap_mm, status] = select_reachable_request( ...
        raw_gap_mm, reachable_model, previous_requested_gaps, allow_repeat)
%SELECT_REACHABLE_REQUEST Choose the nearest different buildable test gap.
% This is for sequential Neyer requests, where the outcome is not known yet.
% Direction-safe operating-limit rounding is handled separately.

    if nargin < 3 || isempty(previous_requested_gaps)
        previous_requested_gaps = zeros(0, 1);
    end
    if nargin < 4, allow_repeat = false; end
    if ~(isscalar(raw_gap_mm) && isnumeric(raw_gap_mm) && isreal(raw_gap_mm) && ...
            isfinite(raw_gap_mm))
        error('select_reachable_request:badGap', ...
            'The requested mathematical gap must be one finite number.');
    end
    if ~isstruct(reachable_model) || ~all(isfield(reachable_model, ...
            {'gaps_mm', 'instructions', 'comparison_tolerance_mm'}))
        error('select_reachable_request:badModel', ...
            'A reachable physical-gap model is required.');
    end
    candidates = reachable_model.gaps_mm(:);
    allowed = true(size(candidates));
    tolerance = reachable_model.comparison_tolerance_mm;
    if ~allow_repeat
        for previous_number = 1:numel(previous_requested_gaps)
            allowed = allowed & abs(candidates - ...
                previous_requested_gaps(previous_number)) > tolerance;
        end
    end
    rows = find(allowed);
    if isempty(rows)
        error('select_reachable_request:noDifferentGap', ...
            ['No different reachable gap remains. Review the physical gap ' ...
             'capability before continuing the destructive study.']);
    end
    [~, nearest_position] = min(abs(candidates(rows) - raw_gap_mm));
    chosen_row = rows(nearest_position);
    requested_gap_mm = candidates(chosen_row);
    status = struct('raw_gap_mm', raw_gap_mm, ...
        'requested_gap_mm', requested_gap_mm, ...
        'display_gap', string(sprintf('%.2f mm', requested_gap_mm)), ...
        'instruction', reachable_model.instructions(chosen_row));
end
