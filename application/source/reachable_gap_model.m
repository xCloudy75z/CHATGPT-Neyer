function model = reachable_gap_model(setup, minimum_gap_mm, maximum_gap_mm)
%REACHABLE_GAP_MODEL List the physical gaps the equipment can construct.
% The returned gaps retain their real numerical values. User-facing build
% instructions show two decimal places and, for combinations, retain the
% spacer/foil recipe so a rounded display does not lose the construction.

    validate_bounds(minimum_gap_mm, maximum_gap_mm);
    if ~isstruct(setup) || ~isfield(setup, 'mode')
        error('reachable_gap_model:badSetup', ...
            'Choose regular increments, spacer combinations, or a confirmed list.');
    end
    mode = lower(strtrim(char(string(setup.mode))));
    numerical_tolerance = 1e-10;

    switch mode
        case 'regular'
            require_fields(setup, {'increment_mm'});
            increment_mm = setup.increment_mm;
            if ~positive_scalar(increment_mm)
                error('reachable_gap_model:badIncrement', ...
                    'The regular gap increment must be one positive number.');
            end
            first_multiple = ceil((minimum_gap_mm - numerical_tolerance) / ...
                increment_mm);
            last_multiple = floor((maximum_gap_mm + numerical_tolerance) / ...
                increment_mm);
            multiple_numbers = (first_multiple:last_multiple)';
            gaps_mm = multiple_numbers * increment_mm;
            gaps_mm(abs(gaps_mm) < numerical_tolerance) = 0;
            instructions = compose("Set the gap to %.2f mm", gaps_mm);
            description = sprintf('Every %.4g mm from %.4g to %.4g mm', ...
                increment_mm, minimum_gap_mm, maximum_gap_mm);

        case 'list'
            require_fields(setup, {'gaps_mm'});
            supplied_gaps = setup.gaps_mm(:);
            if ~isnumeric(supplied_gaps) || ~isreal(supplied_gaps) || ...
                    any(~isfinite(supplied_gaps))
                error('reachable_gap_model:badList', ...
                    'Every confirmed reachable gap must be a finite number.');
            end
            supplied_gaps = supplied_gaps(supplied_gaps >= minimum_gap_mm - ...
                numerical_tolerance & supplied_gaps <= maximum_gap_mm + ...
                numerical_tolerance);
            gaps_mm = unique_with_tolerance(supplied_gaps, numerical_tolerance);
            instructions = compose("Use the confirmed %.2f mm setup", gaps_mm);
            description = sprintf('%d confirmed reachable gaps', numel(gaps_mm));

        case 'combinations'
            require_fields(setup, {'component_names', 'component_mm', ...
                'maximum_counts'});
            component_mm = setup.component_mm(:)';
            maximum_counts = setup.maximum_counts(:)';
            component_names = setup.component_names;
            if isstring(component_names), component_names = cellstr(component_names); end
            if ~(iscell(component_names) && numel(component_names) == ...
                    numel(component_mm) && numel(component_mm) == ...
                    numel(maximum_counts))
                error('reachable_gap_model:badComponents', ...
                    'Each physical component needs a name, measured thickness, and maximum count.');
            end
            if any(~isfinite(component_mm)) || any(component_mm <= 0) || ...
                    any(~isfinite(maximum_counts)) || any(maximum_counts < 0) || ...
                    any(maximum_counts ~= floor(maximum_counts))
                error('reachable_gap_model:badComponents', ...
                    'Component thicknesses must be positive and maximum counts must be whole numbers.');
            end
            count_rows = enumerate_counts(maximum_counts);
            all_gaps = count_rows * component_mm(:);
            keep = all_gaps >= minimum_gap_mm - numerical_tolerance & ...
                all_gaps <= maximum_gap_mm + numerical_tolerance;
            all_gaps = all_gaps(keep);
            count_rows = count_rows(keep, :);
            [all_gaps, order] = sort(all_gaps);
            count_rows = count_rows(order, :);
            keep_unique = [true; diff(all_gaps) > numerical_tolerance];
            gaps_mm = all_gaps(keep_unique);
            count_rows = count_rows(keep_unique, :);
            instructions = strings(numel(gaps_mm), 1);
            for row_number = 1:numel(gaps_mm)
                recipe = describe_recipe(count_rows(row_number, :), component_names);
                instructions(row_number) = sprintf('%.2f mm target: %s', ...
                    gaps_mm(row_number), recipe);
            end
            description = sprintf('%d reachable spacer/foil combinations', ...
                numel(gaps_mm));

        otherwise
            error('reachable_gap_model:badMode', ...
                'Physical setup mode must be regular, combinations, or list.');
    end

    if isempty(gaps_mm)
        error('reachable_gap_model:noReachableGaps', ...
            'No physical gap can be built inside the permitted range.');
    end

    model = struct('mode', mode, 'gaps_mm', gaps_mm(:), ...
        'instructions', instructions(:), 'description', description, ...
        'minimum_gap_mm', minimum_gap_mm, ...
        'maximum_gap_mm', maximum_gap_mm, ...
        'comparison_tolerance_mm', numerical_tolerance);
end

function validate_bounds(minimum_gap_mm, maximum_gap_mm)
    if ~(isnumeric(minimum_gap_mm) && isscalar(minimum_gap_mm) && ...
            isreal(minimum_gap_mm) && isfinite(minimum_gap_mm) && ...
            isnumeric(maximum_gap_mm) && isscalar(maximum_gap_mm) && ...
            isreal(maximum_gap_mm) && isfinite(maximum_gap_mm) && ...
            maximum_gap_mm > minimum_gap_mm)
        error('reachable_gap_model:badBounds', ...
            'The maximum permitted gap must be greater than the minimum gap.');
    end
end

function require_fields(value, fields)
    for field_number = 1:numel(fields)
        if ~isfield(value, fields{field_number})
            error('reachable_gap_model:missingSetupAnswer', ...
                'The physical setup answer "%s" is missing.', fields{field_number});
        end
    end
end

function yes = positive_scalar(value)
    yes = isnumeric(value) && isscalar(value) && isreal(value) && ...
        isfinite(value) && value > 0;
end

function values = unique_with_tolerance(values, tolerance)
    values = sort(values(:));
    if isempty(values), return; end
    values = values([true; diff(values) > tolerance]);
end

function count_rows = enumerate_counts(maximum_counts)
    bases = maximum_counts + 1;
    number_of_rows = prod(bases);
    count_rows = zeros(number_of_rows, numel(maximum_counts));
    for row_number = 0:number_of_rows - 1
        remaining = row_number;
        for component_number = 1:numel(maximum_counts)
            count_rows(row_number + 1, component_number) = ...
                mod(remaining, bases(component_number));
            remaining = floor(remaining / bases(component_number));
        end
    end
end

function recipe = describe_recipe(counts, names)
    pieces = strings(0, 1);
    for component_number = 1:numel(counts)
        count = counts(component_number);
        if count == 0, continue; end
        name = char(string(names{component_number}));
        if count == 1
            pieces(end + 1, 1) = "1 " + string(name); %#ok<AGROW>
        else
            pieces(end + 1, 1) = string(count) + " " + string(name) + "s"; %#ok<AGROW>
        end
    end
    if isempty(pieces)
        recipe = 'no spacers or foil';
    else
        recipe = char(strjoin(pieces, ' + '));
    end
end
