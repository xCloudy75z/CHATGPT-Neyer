function coverage = operating_gap_coverage(raw_boundary_mm, ...
        true_boundary_mm, outcome, reachable_model)
%OPERATING_GAP_COVERAGE Judge the final reachable instruction, not a hidden raw value.
    coverage = struct('safe_gap_mm', NaN, 'available', false, ...
        'conservative', false, 'status', struct());
    if ~(isfinite(raw_boundary_mm) && isfinite(true_boundary_mm))
        return;
    end
    [safe_gap_mm, status] = select_operating_gap(raw_boundary_mm, ...
        outcome, reachable_model);
    coverage.status = status;
    coverage.safe_gap_mm = safe_gap_mm;
    coverage.available = strcmp(status.code, 'ok');
    if ~coverage.available, return; end
    tolerance = reachable_model.comparison_tolerance_mm;
    if strcmp(char(string(outcome)), 'interaction')
        coverage.conservative = safe_gap_mm <= true_boundary_mm + tolerance;
    elseif strcmp(char(string(outcome)), 'no_interaction')
        coverage.conservative = safe_gap_mm >= true_boundary_mm - tolerance;
    else
        error('operating_gap_coverage:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end
end
