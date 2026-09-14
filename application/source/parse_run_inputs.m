function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS Convert direct-test answers into validated engine settings.
% The established 7/8/9-cell layouts remain available for older tools. The
% direct-test UI may instead pass a named struct for regular or confirmed-list
% physical capability.

    if isstruct(answers) && isscalar(answers)
        out = parse_named_answers(answers);
        return;
    end
    if ~(iscell(answers) && any(numel(answers) == [7 8 9]))
        error('parse_run_inputs:badShape', ...
              'Expected all physical test settings.');
    end

    if numel(answers) == 9
        maximum_gap = answers{6};
        unit = answers{7};
        resolution = answers{8};
        foil = answers{9};
        require_finite_minimum = true;
        build_regular_model = true;
        has_foil = true;
    else
        defaults = neyer_settings();
        maximum_gap = num2str(defaults.max_level, '%.17g');
        unit = answers{6};
        resolution = answers{7};
        foil = '';
        require_finite_minimum = false;
        build_regular_model = false;
        has_foil = numel(answers) == 8;
        if has_foil, foil = answers{8}; end
    end

    out = parse_common_direct_fields(answers{1}, answers{2}, answers{3}, ...
        answers{4}, answers{5}, maximum_gap, unit, require_finite_minimum);
    out = apply_regular_setup(out, resolution, build_regular_model);
    if has_foil
        out = apply_foil_thickness(out, foil);
    end
end

function out = parse_named_answers(answers)
    required_fields = {'low_guess', 'high_guess', 'variation_guess', ...
        'maximum_tests', 'minimum_gap', 'maximum_gap', 'unit', ...
        'physical_mode', 'regular_step', 'confirmed_gaps', 'foil_thickness'};
    if ~all(isfield(answers, required_fields))
        error('parse_run_inputs:badNamedShape', ...
            'Complete all direct-test settings before starting the test.');
    end
    mode = normalize_physical_mode(named_text(answers.physical_mode));
    out = parse_common_direct_fields(named_text(answers.low_guess), ...
        named_text(answers.high_guess), named_text(answers.variation_guess), ...
        named_text(answers.maximum_tests), named_text(answers.minimum_gap), ...
        named_text(answers.maximum_gap), named_text(answers.unit), true);

    switch mode
        case 'confirmed gap list'
            gaps_mm = parse_confirmed_gap_list( ...
                named_text(answers.confirmed_gaps), out.cfg.min_level, ...
                out.cfg.max_level);
            out.cfg.reachable_model = reachable_gap_model( ...
                struct('mode', 'list', 'gaps_mm', gaps_mm), ...
                out.cfg.min_level, out.cfg.max_level);
            confirmed_step = min(diff(gaps_mm));
            out.cfg.usable_resolution = confirmed_step;
            % The Neyer core reads level_increment for its Stage-2 sigma floor.
            % In list mode it equals the smallest confirmed adjacent gap, not a
            % fictional regular grid; requests still come only from the list.
            out.cfg.level_increment = confirmed_step;

        case 'regular gap step'
            out = apply_regular_setup(out, named_text(answers.regular_step), true);

        otherwise
            error('parse_run_inputs:badPhysicalMode', ...
                ['Physical setup: choose Regular gap step or Confirmed gap ' ...
                 'list.']);
    end
    out = apply_foil_thickness(out, named_text(answers.foil_thickness));
end

function out = parse_common_direct_fields(low_text, high_text, ...
        variation_text, maximum_tests_text, minimum_gap_text, maximum_gap_text, ...
        unit_text, require_finite_minimum)
% Shared number, permitted-range, unit, and core-method validation. It does
% not construct a physical model, so confirmed-list parsing never builds an
% unrelated regular grid.
    lo = str2double(low_text);
    hi = str2double(high_text);
    sg = str2double(variation_text);
    num_parts = str2double(maximum_tests_text);
    minimum_gap_text = strtrim(minimum_gap_text);
    if isempty(minimum_gap_text)
        minimum_gap = -Inf;
    else
        minimum_gap = str2double(minimum_gap_text);
    end
    if ~(isscalar(minimum_gap) && isreal(minimum_gap) && ...
            ~isnan(minimum_gap) && minimum_gap < Inf)
        error('parse_run_inputs:badMinLevel', ...
              'Minimum gap must be a number.');
    end
    params = struct('avg_low', lo, 'avg_high', hi, 'spread_guess', sg);
    try
        check_inputs(params, num_parts);
    catch input_error
        throw_plain_input_error(input_error);
    end
    if require_finite_minimum && ~isfinite(minimum_gap)
        error('parse_run_inputs:badMinLevel', ...
            'Enter the smallest physical gap permitted for this test.');
    end
    maximum_gap = str2double(maximum_gap_text);
    if ~(isscalar(maximum_gap) && isreal(maximum_gap) && ...
            isfinite(maximum_gap) && maximum_gap > minimum_gap)
        error('parse_run_inputs:badMaxLevel', ...
            'Maximum permitted gap must be greater than the minimum gap.');
    end
    unit_text = strtrim(unit_text);
    if ~strcmpi(unit_text, 'mm')
        error('parse_run_inputs:badUnit', ...
            'Direct testing currently uses millimetres. Enter mm as the gap unit.');
    end
    cfg = neyer_settings();
    cfg.min_level = minimum_gap;
    cfg.max_level = maximum_gap;
    cfg.unit = 'mm';
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end

function out = apply_regular_setup(out, resolution_text, build_model)
    usable_resolution = str2double(resolution_text);
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
    out.cfg.usable_resolution = usable_resolution;
    out.cfg.level_increment = usable_resolution;
    if build_model
        regular_setup = struct('mode', 'regular', ...
            'increment_mm', usable_resolution);
        out.cfg.reachable_model = reachable_gap_model(regular_setup, ...
            out.cfg.min_level, out.cfg.max_level);
    end
end

function out = apply_foil_thickness(out, foil_text)
    foil_thickness = str2double(foil_text);
    if ~(isscalar(foil_thickness) && isreal(foil_thickness) && ...
            isfinite(foil_thickness) && foil_thickness > 0)
        error('parse_run_inputs:badFoilThickness', ...
            'Foil thickness must be a positive number, for example 0.015 mm.');
    end
    out.cfg.foil_thickness = foil_thickness;
end

function mode = normalize_physical_mode(value)
    mode = lower(strtrim(value));
    mode = regexprep(mode, '\s+', ' ');
    if ~ismember(mode, {'confirmed gap list', 'regular gap step'})
        error('parse_run_inputs:badPhysicalMode', ...
            ['Physical setup: choose Regular gap step or Confirmed gap ' ...
             'list.']);
    end
end

function text = named_text(value)
    if ischar(value)
        text = value;
    elseif isstring(value) && isscalar(value)
        text = char(value);
    else
        error('parse_run_inputs:badNamedValue', ...
            'Enter text for every direct-test setting.');
    end
end

function throw_plain_input_error(input_error)
    switch input_error.identifier
        case 'check_inputs:notFiniteScalar'
            error('parse_run_inputs:badStartingNumber', ...
                ['Enter ordinary numbers for the low guess, high guess, ' ...
                 'and overall variation guess.']);
        case 'check_inputs:badBounds'
            error('parse_run_inputs:badStartingGuesses', ...
                'High guess must be greater than the low guess.');
        case 'check_inputs:badSigma'
            error('parse_run_inputs:badOverallVariation', ...
                'The overall variation guess must be greater than zero.');
        case 'check_inputs:badBudget'
            error('parse_run_inputs:badTestMaximum', ...
                'Maximum allowed number of destructive tests must be a whole number.');
        case 'check_inputs:budgetTooSmall'
            error('parse_run_inputs:testMaximumTooSmall', ...
                'Allow at least 3 destructive tests.');
        otherwise
            rethrow(input_error);
    end
end
