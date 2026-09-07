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
    isPhysical=isfield(result,'requested_levels') && ...
        isfield(result,'measurements') && numel(result.requested_levels)==n && ...
        numel(result.measurements)==n;
    if isPhysical
        L{end+1}=sprintf(['test,internal target (%s),build request (%s),measured mean (%s),' ...
            'reading 1,reading 2,reading 3,reading 4,reading 5,' ...
            'reading range,measurement warning,outcome'],u,u,u);
        requested=result.requested_levels(:);
        if isfield(result,'raw_requested_levels') && ...
                numel(result.raw_requested_levels)==n
            rawRequested=result.raw_requested_levels(:);
        else
            % Older physical records did not store the pre-rounding target.
            rawRequested=requested;
        end
        for k=1:n
            if sc(k), o='interaction'; else, o='no interaction'; end
            readings=result.measurements{k}(:)';
            cells=repmat({''},1,5);
            for readingNumber=1:numel(readings)
                cells{readingNumber}=csv_number(readings(readingNumber));
            end
            if isfield(result,'measurement_ranges') && ...
                    numel(result.measurement_ranges)>=k
                readingRange=csv_number(result.measurement_ranges(k));
            else
                readingRange=csv_number(max(readings)-min(readings));
            end
            if isfield(result,'measurement_warnings') && ...
                    numel(result.measurement_warnings)>=k && ...
                    result.measurement_warnings(k)
                warningText='yes';
            else
                warningText='no';
            end
            L{end+1}=sprintf('%d,%s,%.2f,%s,%s,%s,%s,%s,%s,%s,%s,%s', ...
                k,csv_number(rawRequested(k)),requested(k),csv_number(lv(k)), ...
                cells{1},cells{2},cells{3},cells{4}, ...
                cells{5},readingRange,warningText,o);
        end
    else
        L{end+1} = sprintf('test,gap (%s),outcome', u);
        for k = 1:n
            if sc(k), o = 'interaction'; else, o = 'no interaction'; end
            L{end+1} = sprintf('%d,%.2f,%s', k, lv(k), o);
        end
    end
    L{end+1} = '';
    L{end+1} = 'summary,value,unit';
    L{end+1} = sprintf('Middle gap,%.4f,%s', csv_field(result,'mu',NaN), u);
    L{end+1} = sprintf('Transition width,%.4f,%s', csv_field(result,'sigma',NaN), u);
    L{end+1} = sprintf('95%% middle-gap low,%.4f,%s', csv_field(result,'mu_lo',NaN), u);
    L{end+1} = sprintf('95%% middle-gap high,%.4f,%s', csv_field(result,'mu_hi',NaN), u);
    L{end+1} = sprintf('High-interaction gap (~%.4g%% interaction),%.4f,%s', ...
        pc,csv_field(result,'high_interaction_gap',NaN),u);
    L{end+1} = sprintf('Negligible-interaction gap (~%.4g%% no interaction),%.4f,%s', ...
        pc,csv_field(result,'negligible_interaction_gap',NaN),u);
    L{end+1} = sprintf('Tests,%d,', n);
    if isfield(result,'usable_resolution') && ~isempty(result.usable_resolution)
        L{end+1}=sprintf('Usable resolution,%.4f,%s', ...
            result.usable_resolution,u);
    end
    if isfield(result,'foil_thickness') && ~isempty(result.foil_thickness)
        L{end+1}=sprintf('Foil thickness,%.4f,%s',result.foil_thickness,u);
    end
    if isfield(result,'resolution_sigma_floor') && ...
            ~isempty(result.resolution_sigma_floor)
        L{end+1}=sprintf('Stage-2 planning sigma floor,%.4f,%s', ...
            result.resolution_sigma_floor,u);
    end

    txt = strjoin(L, sprintf('\n'));
end

function v = csv_field(s, name, dflt)
    if isfield(s, name) && ~isempty(s.(name)) && ~isnan(s.(name)), v = s.(name);
    else, v = dflt; end
end

function text = csv_number(value)
%CSV_NUMBER Shortest clean decimal that recreates the same MATLAB double.
% This keeps ordinary readings such as 3.67 readable without losing the
% uncommon 16th or 17th digit needed by some valid numeric values.
    for significantDigits=1:17
        candidate=sprintf(['%.' num2str(significantDigits) 'g'],value);
        if isequal(str2double(candidate),value)
            text=candidate;
            return;
        end
    end
    text=sprintf('%.17g',value);
end
