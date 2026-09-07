function out = parse_run_inputs(answers)
%PARSE_RUN_INPUTS  Pure core of the settings popup: strings -> validated {params,num_parts,cfg}.
%   out = PARSE_RUN_INPUTS(answers), answers a 5-cell array of strings
%   {lo, hi, spread_guess, num_parts, min_level} as inputdlg returns. Returns
%   struct with .params, .num_parts, .cfg. Validates by reusing check_inputs so
%   the popup cannot accept anything the engine would reject. Blank min_level =
%   no floor (-Inf). Throws a named error on any bad field. [addendum POPUP]
    if ~(iscell(answers) && (numel(answers) == 5 || numel(answers) == 6))
        error('parse_run_inputs:badShape', 'expected a 5-field answer.');
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
              'Minimum height must be a number (or blank for none).');
    end
    params = struct('avg_low', lo, 'avg_high', hi, 'spread_guess', sg);
    check_inputs(params, num_parts);      % reuse the engine's validation (#7)
    cfg = neyer_settings();
    cfg.min_level = ml;
    % Optional 6th field = display unit (label only). Blank = settings() default.
    if numel(answers) == 6 && ~isempty(strtrim(answers{6}))
        cfg.unit = strtrim(answers{6});
    end
    out = struct('params', params, 'num_parts', num_parts, 'cfg', cfg);
end
