function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS  Pure core of the settings popup: strings -> validated {params,num_parts,cfg}.
%   out = PARSE_RUN_INPUTS(answers), answers a 7- or 8-cell array of strings
%   {lo, hi, spread_guess, num_parts, min_level, unit, usable_resolution,
%   foil_thickness}. Foil thickness is construction information only. The
%   usable resolution controls physical requests and the Stage-2 safety floor.
%   Returns
%   struct with .params, .num_parts, .cfg. Validates by reusing check_inputs so
%   the popup cannot accept anything the engine would reject. Blank min_level =
%   no floor (-Inf). Throws a named error on any bad field. [addendum POPUP]
    if ~(iscell(answers) && any(numel(answers) == [7 8]))
        error('parse_run_inputs:badShape', ...
              'Expected all physical test settings.');
    end
    lo = str2double(answers{1});
    hi = str2double(answers{2});
    sg = str2double(answers{3});
    num_parts = str2double(answers{4});
    ml_str = strtrim(answers{5});
    if isempty(ml_str)
        ml = -Inf;                        % blank = no floor
    else
        ml = str2double(ml_str);
    end
    if ~(isscalar(ml) && isreal(ml) && ~isnan(ml) && ml < Inf)
        error('parse_run_inputs:badMinLevel', ...
              'Minimum gap must be a number.');
    end
    params = struct('avg_low', lo, 'avg_high', hi, 'spread_guess', sg);
    check_inputs(params, num_parts);      % reuse the engine's validation (#7)
    cfg = neyer_settings();
    cfg.min_level = ml;
    if ~isempty(strtrim(answers{6}))
        cfg.unit = strtrim(answers{6});
    end
    usable_resolution = str2double(answers{7});
    if ~(isscalar(usable_resolution) && isreal(usable_resolution) && ...
            isfinite(usable_resolution) && usable_resolution > 0)
        error('parse_run_inputs:badLevelIncrement', ...
            ['Enter the positive usable gap step for this study ' ...
             '(for example 0.05 or 0.10 mm).']);
    end
    hundredths = usable_resolution * 100;
    if abs(hundredths-round(hundredths)) > 1e-10
        error('parse_run_inputs:badUsableResolution', ...
            ['The usable gap step must work with two-decimal build requests. ' ...
             'Enter 0.01, 0.02, 0.05, 0.10 mm, or another whole hundredth. ' ...
             'Do not enter the 0.015 mm foil thickness here.']);
    end
    cfg.usable_resolution = usable_resolution;
    cfg.level_increment = usable_resolution; % compatibility with the Neyer core

    if numel(answers) == 8
        foil_thickness = str2double(answers{8});
        if ~(isscalar(foil_thickness) && isreal(foil_thickness) && ...
                isfinite(foil_thickness) && foil_thickness > 0)
            error('parse_run_inputs:badFoilThickness', ...
                'Foil thickness must be a positive number, for example 0.015 mm.');
        end
        cfg.foil_thickness = foil_thickness;
    end
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end
