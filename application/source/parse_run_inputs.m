function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS  Pure core of the settings popup: strings -> validated {params,num_parts,cfg}.
%   out = PARSE_RUN_INPUTS(answers), answers a 9-cell array of strings
%   {lo, hi, spread_guess, num_parts, min_level, max_level, unit,
%   usable_resolution, foil_thickness}. The older 7- and 8-cell layouts are
%   still accepted for compatibility. Foil thickness is construction
%   information only. The
%   usable resolution controls physical requests and the Stage-2 safety floor.
%   Returns
%   struct with .params, .num_parts, .cfg. Validates by reusing check_inputs so
%   the popup cannot accept anything the engine would reject. Blank min_level =
%   no floor (-Inf). A named struct from the direct-test UI is also accepted;
%   it can describe either a regular usable step or a confirmed measured-gap
%   list. Throws a named error on any bad field. [addendum POPUP]
    if isstruct(answers) && isscalar(answers)
        out = parse_named_answers(answers);
        return;
    end
    if ~(iscell(answers) && any(numel(answers) == [7 8 9]))
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
    try
        check_inputs(params, num_parts);  % keep one set of mathematical rules
    catch input_error
        throw_plain_input_error(input_error);
    end
    cfg = neyer_settings();
    cfg.min_level = ml;
    if numel(answers) == 9
        if ~isfinite(ml)
            error('parse_run_inputs:badMinLevel', ...
                'Enter the smallest physical gap permitted for this test.');
        end
        max_level = str2double(answers{6});
        if ~(isscalar(max_level) && isreal(max_level) && ...
                isfinite(max_level) && max_level > ml)
            error('parse_run_inputs:badMaxLevel', ...
                'Maximum permitted gap must be greater than the minimum gap.');
        end
        unit_index = 7;
        resolution_index = 8;
        foil_index = 9;
    else
        max_level = cfg.max_level;
        unit_index = 6;
        resolution_index = 7;
        foil_index = 8;
    end
    cfg.max_level = max_level;
    if ~isempty(strtrim(answers{unit_index}))
        cfg.unit = strtrim(answers{unit_index});
    end
    usable_resolution = str2double(answers{resolution_index});
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

    if numel(answers) >= foil_index
        foil_thickness = str2double(answers{foil_index});
        if ~(isscalar(foil_thickness) && isreal(foil_thickness) && ...
                isfinite(foil_thickness) && foil_thickness > 0)
            error('parse_run_inputs:badFoilThickness', ...
                'Foil thickness must be a positive number, for example 0.015 mm.');
        end
        cfg.foil_thickness = foil_thickness;
    end
    if numel(answers) == 9
        regular_setup = struct('mode', 'regular', ...
            'increment_mm', usable_resolution);
        cfg.reachable_model = reachable_gap_model(regular_setup, ml, max_level);
    end
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end

function out = parse_named_answers(answers)
% Keep the existing cell parser as the single source of the direct-test
% number and foil validation rules. The named form only supplies the physical
% setup choice that the new UI exposes.
    required_fields = {'low_guess', 'high_guess', 'variation_guess', ...
        'maximum_tests', 'minimum_gap', 'maximum_gap', 'unit', ...
        'physical_mode', 'regular_step', 'confirmed_gaps', 'foil_thickness'};
    if ~all(isfield(answers, required_fields))
        error('parse_run_inputs:badNamedShape', ...
            'Complete all direct-test settings before starting the test.');
    end
    mode = lower(strtrim(named_text(answers.physical_mode)));
    shared_answers = {named_text(answers.low_guess), ...
        named_text(answers.high_guess), named_text(answers.variation_guess), ...
        named_text(answers.maximum_tests), named_text(answers.minimum_gap), ...
        named_text(answers.maximum_gap), named_text(answers.unit)};

    if contains(mode, 'confirmed') && contains(mode, 'list')
        % The legacy parser gives common direct settings their established
        % validation. 0.01 is a temporary valid regular step and is replaced
        % below by the floor proved from the validated confirmed list.
        out = parse_run_inputs([shared_answers, {'0.01', ...
            named_text(answers.foil_thickness)}]);
        gaps_mm = parse_confirmed_gap_list(named_text(answers.confirmed_gaps), ...
            out.cfg.min_level, out.cfg.max_level);
        out.cfg.reachable_model = reachable_gap_model( ...
            struct('mode', 'list', 'gaps_mm', gaps_mm), out.cfg.min_level, ...
            out.cfg.max_level);
        confirmed_step = min(diff(gaps_mm));
        out.cfg.usable_resolution = confirmed_step;
        % The Neyer core reads level_increment for its Stage-2 sigma floor.
        % In list mode it must equal the smallest confirmed adjacent gap, not
        % a fictional regular grid step; actual requests still come only from
        % reachable_model, so no intermediate setting is invented.
        out.cfg.level_increment = confirmed_step;
    elseif contains(mode, 'regular')
        out = parse_run_inputs([shared_answers, {named_text(answers.regular_step), ...
            named_text(answers.foil_thickness)}]);
    else
        error('parse_run_inputs:badPhysicalMode', ...
            ['Physical setup: choose Regular usable step or Confirmed gap ' ...
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
