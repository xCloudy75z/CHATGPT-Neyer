function gaps_mm = parse_confirmed_gap_list(answer, minimum_gap_mm, maximum_gap_mm)
%PARSE_CONFIRMED_GAP_LIST Validate a comma-separated list of measured gaps.
% A confirmed list is deliberately stricter than a convenient numeric vector:
% every entry must be a finite nonnegative measurement, and at least two
% distinct entries must remain within the permitted direct-test range.

    validate_bounds(minimum_gap_mm, maximum_gap_mm);
    text = answer_text(answer);
    if contains(text, ';')
        error('parse_confirmed_gap_list:badFormat', ...
            ['Confirmed gap list: separate measured gaps with commas, for ' ...
             'example 1.00, 1.10, 2.50.']);
    end

    entries = strsplit(text, ',', 'CollapseDelimiters', false);
    values = zeros(numel(entries), 1);
    for entry_number = 1:numel(entries)
        entry = strtrim(entries{entry_number});
        if isempty(entry)
            error('parse_confirmed_gap_list:badEntry', ...
                ['Confirmed gap list: enter a measured nonnegative number ' ...
                 'for every comma-separated gap.']);
        end
        if ~isempty(regexp(entry, '\s', 'once'))
            error('parse_confirmed_gap_list:badFormat', ...
                ['Confirmed gap list: separate measured gaps with commas, ' ...
                 'not spaces.']);
        end
        value = str2double(entry);
        if ~(isscalar(value) && isreal(value) && isfinite(value) && value >= 0)
            error('parse_confirmed_gap_list:badEntry', ...
                ['Confirmed gap list: enter finite nonnegative measured gaps ' ...
                 'such as 1.00, 1.10, 2.50.']);
        end
        shown_value = round(value, 2);
        precision_tolerance = 1e-10 * max(1, abs(value));
        if abs(value - shown_value) > precision_tolerance
            error('parse_confirmed_gap_list:tooManyDecimals', ...
                ['Confirmed gap list: enter every gap to no more than two ' ...
                 'decimal places, such as 1.00, 1.10, 2.50.']);
        end
        values(entry_number) = value;
    end

    % Confirmed means inside the stated bounds exactly. The reachable-model
    % tolerance is useful for collapsing equivalent constructed gaps, but it
    % must not admit a value that is strictly outside the operator's range.
    values = values(values >= minimum_gap_mm & values <= maximum_gap_mm);
    if numel(values) < 2
        error('parse_confirmed_gap_list:notEnoughGaps', ...
            ['Confirmed gap list: enter at least two different measured ' ...
             'gaps inside the permitted range.']);
    end
    try
        model = reachable_gap_model(struct('mode', 'list', 'gaps_mm', values), ...
            minimum_gap_mm, maximum_gap_mm);
    catch input_error
        if strcmp(input_error.identifier, 'reachable_gap_model:noReachableGaps')
            error('parse_confirmed_gap_list:notEnoughGaps', ...
                ['Confirmed gap list: enter at least two different measured ' ...
                 'gaps inside the permitted range.']);
        end
        rethrow(input_error);
    end
    gaps_mm = model.gaps_mm;
    if numel(gaps_mm) < 2
        error('parse_confirmed_gap_list:notEnoughGaps', ...
            ['Confirmed gap list: enter at least two different measured ' ...
             'gaps inside the permitted range.']);
    end
end

function validate_bounds(minimum_gap_mm, maximum_gap_mm)
    if ~(isnumeric(minimum_gap_mm) && isscalar(minimum_gap_mm) && ...
            isreal(minimum_gap_mm) && isfinite(minimum_gap_mm) && ...
            isnumeric(maximum_gap_mm) && isscalar(maximum_gap_mm) && ...
            isreal(maximum_gap_mm) && isfinite(maximum_gap_mm) && ...
            maximum_gap_mm > minimum_gap_mm)
        error('parse_confirmed_gap_list:badBounds', ...
            'The permitted minimum and maximum gaps must be valid numbers.');
    end
end

function text = answer_text(answer)
    if ischar(answer)
        text = answer;
    elseif isstring(answer) && isscalar(answer)
        text = char(answer);
    else
        error('parse_confirmed_gap_list:badEntry', ...
            ['Confirmed gap list: enter comma-separated measured gap numbers, ' ...
             'for example 1.00, 1.10, 2.50.']);
    end
    text = strtrim(text);
end
