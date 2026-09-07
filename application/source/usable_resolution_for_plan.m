function usable_resolution_mm = usable_resolution_for_plan(plan, default_mm)
%USABLE_RESOLUTION_FOR_PLAN Choose a two-decimal test step for a loaded plan.
% Component thicknesses and irregular reachable gaps do not prove the test
% equipment can control their smallest numerical difference. Those plans keep
% the visible provisional default so the operator can confirm or change it.

    if nargin < 2, default_mm = 0.05; end
    if ~is_two_decimal_step(default_mm)
        error('usable_resolution_for_plan:badDefault', ...
            'The default usable gap step must be a positive whole hundredth.');
    end
    usable_resolution_mm = default_mm;
    if ~isstruct(plan) || ~isfield(plan, 'physical_setup') || ...
            ~isstruct(plan.physical_setup) || ...
            ~isfield(plan.physical_setup, 'mode')
        return;
    end
    setup = plan.physical_setup;
    if strcmpi(char(string(setup.mode)), 'regular')
        if ~isfield(setup, 'increment_mm') || ...
                ~is_two_decimal_step(setup.increment_mm)
            error('usable_resolution_for_plan:badRegularStep', ...
                ['A regular gap step must be a positive whole hundredth, ' ...
                 'for example 0.05, 0.10, 0.15, or 0.50 mm.']);
        end
        usable_resolution_mm = double(setup.increment_mm);
    end
end

function yes = is_two_decimal_step(value)
    yes = isnumeric(value) && isscalar(value) && isreal(value) && ...
        isfinite(value) && value > 0 && ...
        abs(value * 100 - round(value * 100)) <= 1e-10;
end
