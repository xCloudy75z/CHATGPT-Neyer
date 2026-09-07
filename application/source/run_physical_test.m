function [result, record] = run_physical_test(params, num_parts, outcome_fn, cfg)
%RUN_PHYSICAL_TEST Run a gap test using an explicitly chosen usable resolution.
%
%   Physical mode deliberately has no default usable resolution. New callers
%   provide .usable_resolution; .level_increment remains accepted for older
%   scripts. Foil thickness never controls rounding or the sigma floor.
%   OUTCOME_FN must return a struct
%   containing the binary .outcome and 4 or 5 repeated .measurements for that
%   test's newly built spacer setup. The
%   existing RUN_TEST entry point remains available for synthetic simulations.

    if nargin < 4 || ~isstruct(cfg)
        error('run_physical_test:badLevelIncrement', ...
            ['Physical testing requires a positive usable gap step ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    if isfield(cfg,'usable_resolution') && ~isempty(cfg.usable_resolution)
        usable_resolution=cfg.usable_resolution;
    elseif isfield(cfg,'level_increment') && ~isempty(cfg.level_increment)
        usable_resolution=cfg.level_increment;
    else
        usable_resolution=[];
    end
    if ~(isnumeric(usable_resolution) && isreal(usable_resolution) && ...
            isscalar(usable_resolution) && isfinite(usable_resolution) && ...
            usable_resolution > 0)
        error('run_physical_test:badLevelIncrement', ...
            ['Physical testing requires a positive usable gap step ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    if abs(usable_resolution*100-round(usable_resolution*100)) > 1e-10
        error('run_physical_test:badUsableResolution', ...
            ['The usable gap step must support two-decimal build requests. ' ...
             'Foil thickness is separate construction information.']);
    end
    cfg.usable_resolution=usable_resolution;
    cfg.level_increment=usable_resolution;
    if nargin < 3 || ~isa(outcome_fn,'function_handle')
        error('run_physical_test:badOutcomeFn', ...
            'Physical testing requires an operator response function.');
    end
    % Physical mode uses the approved two-resolution Stage-2 protection.
    % Synthetic studies may compare other factors through RUN_TEST, but a
    % physical caller cannot silently weaken this rule.
    cfg.resolution_sigma_floor_factor = 2;

    [result, record] = run_test(params, num_parts, @physical_response, cfg);
    record.resolution_sigma_floor_factor = cfg.resolution_sigma_floor_factor;
    record.usable_resolution = usable_resolution;
    if isfield(cfg,'foil_thickness')
        record.foil_thickness=cfg.foil_thickness;
    else
        record.foil_thickness=[];
    end
    record.resolution_sigma_floor = usable_resolution * ...
        cfg.resolution_sigma_floor_factor;
    record.measurement_ranges=cellfun(@(readings) ...
        max(readings)-min(readings),record.measurements);
    record.measurement_warnings=record.measurement_ranges > usable_resolution;
    result.raw_requested_levels=record.raw_requested_levels;
    result.requested_levels=record.requested_levels;
    result.measurements=record.measurements;
    result.usable_resolution=record.usable_resolution;
    result.foil_thickness=record.foil_thickness;
    result.resolution_sigma_floor_factor=record.resolution_sigma_floor_factor;
    result.resolution_sigma_floor=record.resolution_sigma_floor;
    result.measurement_ranges=record.measurement_ranges;
    result.measurement_warnings=record.measurement_warnings;

    function response = physical_response(gap, k)
        response = outcome_fn(gap, k);
        if ~isstruct(response) || ~isfield(response,'measurements')
            error('run_physical_test:measurementsRequired', ...
                ['Physical testing requires an outcome and 4 or 5 gap ' ...
                 'measurements for every new spacer build.']);
        end
    end
end
