function response = parse_physical_response(measurement_text, outcome)
%PARSE_PHYSICAL_RESPONSE Convert one measured gap and outcome to a response.
%   Exactly one finite, real, nonnegative gap measurement is required.

    if isstring(measurement_text) && isscalar(measurement_text)
        measurement_text = char(measurement_text);
    end
    if ~ischar(measurement_text)
        error('parse_physical_response:badMeasurements', ...
            'Enter one measured gap.');
    end
    tokens = strsplit(strtrim(strrep(measurement_text,',',' ')));
    if isempty(tokens) || (numel(tokens)==1 && isempty(tokens{1}))
        readings = [];
    else
        readings = cellfun(@str2double,tokens);
    end
    if ~(numel(readings)==1 && isfinite(readings) && ...
            isreal(readings) && readings >= 0)
        error('parse_physical_response:badMeasurements', ...
            'Enter exactly one finite, nonnegative measured gap.');
    end
    if ~(islogical(outcome) && isscalar(outcome))
        error('parse_physical_response:badOutcome', ...
            'Choose either Interaction or No interaction.');
    end
    response = struct('outcome',outcome,'measurements',readings);
end
