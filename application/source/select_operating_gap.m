function [gap_mm, status] = select_operating_gap(raw_boundary_mm, outcome, model)
%SELECT_OPERATING_GAP Add one reachable physical step in the safe direction.
% The confidence boundary is first rounded in the safe direction. The final
% instruction then moves to the next reachable setting in that same direction
% to protect a newly built setup from small build-to-build differences.

    [first_safe_gap, first_status] = round_reachable_gap( ...
        raw_boundary_mm, outcome, model, []);
    if ~strcmp(first_status.code, 'ok')
        gap_mm = NaN;
        status = first_status;
        return;
    end

    [gap_mm, status] = round_reachable_gap(raw_boundary_mm, outcome, ...
        model, first_safe_gap);
    if ~strcmp(status.code, 'ok')
        gap_mm = NaN;
        status.code = 'no_buffered_setting';
        status.message = [ ...
            'The confidence boundary can be rounded, but no extra reachable ' ...
            'setting remains in the safe direction. No operating instruction is shown.'];
        status.display_gap = "Not established";
        status.instruction = "";
        return;
    end
    status.message = [ ...
        'One extra reachable setting was added in the safe direction to ' ...
        'protect against differences in a newly built spacer setup.'];
end
