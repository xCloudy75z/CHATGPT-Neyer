function [result, record] = run_physical_test(params, num_parts, outcome_fn, cfg)
%RUN_PHYSICAL_TEST Run a gap test using an explicitly confirmed rig increment.
%
%   Physical mode deliberately has no default level increment. CFG must contain
%   a positive finite scalar .level_increment. OUTCOME_FN must return a struct
%   containing the binary .outcome and 4 or 5 repeated .measurements for that
%   test's newly built spacer setup. The
%   existing RUN_TEST entry point remains available for synthetic simulations.

    if nargin < 4 || ~isstruct(cfg) || ...
            ~isfield(cfg,'level_increment') || ...
            ~(isnumeric(cfg.level_increment) && isreal(cfg.level_increment) && ...
              isscalar(cfg.level_increment) && isfinite(cfg.level_increment) && ...
              cfg.level_increment > 0)
        error('run_physical_test:badLevelIncrement', ...
            ['Physical testing requires a confirmed positive gap increment ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    if nargin < 3 || ~isa(outcome_fn,'function_handle')
        error('run_physical_test:badOutcomeFn', ...
            'Physical testing requires an operator response function.');
    end
    if ~isfield(cfg,'resolution_sigma_floor_factor') || ...
            isempty(cfg.resolution_sigma_floor_factor)
        cfg.resolution_sigma_floor_factor = 2;
    end

    [result, record] = run_test(params, num_parts, @physical_response, cfg);
    record.resolution_sigma_floor_factor = cfg.resolution_sigma_floor_factor;
    record.resolution_sigma_floor = cfg.level_increment * ...
        cfg.resolution_sigma_floor_factor;

    function response = physical_response(gap, k)
        response = outcome_fn(gap, k);
        if ~isstruct(response) || ~isfield(response,'measurements')
            error('run_physical_test:measurementsRequired', ...
                ['Physical testing requires an outcome and 4 or 5 gap ' ...
                 'measurements for every new spacer build.']);
        end
    end
end
