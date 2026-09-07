function txt = results_to_csv_text(result)
%RESULTS_TO_CSV_TEXT  Build a CSV report (as text) from a run's result struct.
%   txt = RESULTS_TO_CSV_TEXT(result) returns spreadsheet-friendly CSV text:
%   a per-drop table (test #, height, broke/survived) then a summary block
%   (average, spread, 95%% range, safe/breaks-above heights). Data only -- no
%   code. Pure (no file IO); save_results_files writes it. [compiled-app]
    u = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit), u = result.unit; end
    lv = result.levels(:);
    sc = logical(result.successes(:));
    n  = numel(lv);
    pc = 99.9;   % tail percentage, from the run's settings (default 99.9)
    if isfield(result, 'tail_fraction') && ~isempty(result.tail_fraction), pc = 100 * result.tail_fraction; end

    L = {};
    L{end+1} = sprintf('test,height (%s),outcome', u);
    for k = 1:n
        if sc(k), o = 'break'; else, o = 'survive'; end
        L{end+1} = sprintf('%d,%.2f,%s', k, lv(k), o);
    end
    L{end+1} = '';
    L{end+1} = 'summary,value,unit';
    L{end+1} = sprintf('Average breaking height,%.4f,%s', csv_field(result,'mu',NaN), u);
    L{end+1} = sprintf('Spread,%.4f,%s',                  csv_field(result,'sigma',NaN), u);
    L{end+1} = sprintf('95%% average low,%.4f,%s',        csv_field(result,'mu_lo',NaN), u);
    L{end+1} = sprintf('95%% average high,%.4f,%s',       csv_field(result,'mu_hi',NaN), u);
    L{end+1} = sprintf('Safe below (~%.4g%% survive),%.4f,%s',  pc, csv_field(result,'no_fire',NaN), u);
    L{end+1} = sprintf('Breaks above (~%.4g%% break),%.4f,%s',  pc, csv_field(result,'all_fire',NaN), u);
    L{end+1} = sprintf('Tests,%d,', n);

    txt = strjoin(L, sprintf('\n'));
end

function v = csv_field(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name)) && ~isnan(s.(name)), v = s.(name);
    else, v = dflt; end
end
