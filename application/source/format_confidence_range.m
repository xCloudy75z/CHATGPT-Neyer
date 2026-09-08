function text = format_confidence_range(confidence, lower_limit, upper_limit, unit)
%FORMAT_CONFIDENCE_RANGE Describe incomplete limits without displaying NaN.
    if nargin < 4 || isempty(unit), unit = 'mm'; end
    confidence_text = sprintf('%.4g%%', 100 * confidence);
    lower_text = limit_text(lower_limit, unit, 'lower');
    upper_text = limit_text(upper_limit, unit, 'upper');
    if isfinite(lower_limit) && isfinite(upper_limit)
        text = sprintf('%s confidence range: %.2f to %.2f %s', ...
            confidence_text, lower_limit, upper_limit, unit);
    else
        text = sprintf('%s confidence range: %s; %s', ...
            confidence_text, lower_text, upper_text);
    end
end

function text = limit_text(value, unit, side)
    if isfinite(value)
        text = sprintf('%s limit %.2f %s', side, value, unit);
    else
        text = sprintf('%s limit not established', side);
    end
end
