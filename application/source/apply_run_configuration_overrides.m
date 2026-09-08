function updated = apply_run_configuration_overrides(current, overrides)
%APPLY_RUN_CONFIGURATION_OVERRIDES Apply advanced settings without a stale gap list.
% Direct UI callers normally pass no overrides. Programmatic callers may do
% so; if they change the permitted range or usable step, the reachable gaps
% are rebuilt after all changes have been applied.
    updated = current;
    if nargin < 2 || isempty(overrides), return; end
    if ~isstruct(current) || ~isstruct(overrides)
        error('apply_run_configuration_overrides:badInput', ...
            'Advanced settings must be supplied as a settings structure.');
    end
    names = fieldnames(overrides);
    for field_number = 1:numel(names)
        updated.(names{field_number}) = overrides.(names{field_number});
    end

    step_changed = isfield(overrides, 'usable_resolution') || ...
        isfield(overrides, 'level_increment');
    if isfield(overrides, 'usable_resolution')
        updated.level_increment = overrides.usable_resolution;
    elseif isfield(overrides, 'level_increment')
        updated.usable_resolution = overrides.level_increment;
    end
    bounds_changed = isfield(overrides, 'min_level') || ...
        isfield(overrides, 'max_level');
    model_was_supplied = isfield(overrides, 'reachable_model');
    if (step_changed || bounds_changed) && ~model_was_supplied
        required = {'min_level', 'max_level', 'usable_resolution'};
        if ~all(isfield(updated, required))
            error('apply_run_configuration_overrides:incompletePhysicalSettings', ...
                ['Advanced settings that change the physical range or step ' ...
                 'must include a complete minimum, maximum, and usable step.']);
        end
        regular_setup = struct('mode', 'regular', ...
            'increment_mm', updated.usable_resolution);
        updated.reachable_model = reachable_gap_model(regular_setup, ...
            updated.min_level, updated.max_level);
    end
end
