function response = parse_physical_response(measurement_text, outcome)
%PARSE_PHYSICAL_RESPONSE Convert operator readings to a physical response.
%   Readings may be separated by spaces or commas. Exactly 4 or 5 finite
%   numeric gap measurements are required.

    if isstring(measurement_text) && isscalar(measurement_text)
        measurement_text = char(measurement_text);
    end
    if ~ischar(measurement_text)
        error('parse_physical_response:badMeasurements', ...
            'Enter 4 or 5 measured gaps separated by spaces or commas.');
    end
    tokens = strsplit(strtrim(strrep(measurement_text,',',' ')));
    if isempty(tokens) || (numel(tokens)==1 && isempty(tokens{1}))
        readings = [];
    else
        readings = cellfun(@str2double,tokens);
    end
    if ~(any(numel(readings)==[4 5]) && all(isfinite(readings)) && ...
            isreal(readings))
        error('parse_physical_response:badMeasurements', ...
            'Enter exactly 4 or 5 finite measured gaps.');
    end
    if ~(islogical(outcome) && isscalar(outcome))
        error('parse_physical_response:badOutcome', ...
            'Choose either Interaction or No interaction.');
    end
    response = struct('outcome',outcome,'measurements',readings);
end
