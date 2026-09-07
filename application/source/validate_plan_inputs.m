function [clean, messages] = validate_plan_inputs(input)
%VALIDATE_PLAN_INPUTS Check and normalize the pre-test planner answers.
% Percentages may be entered as 95 or 0.95. Returned percentages are
% fractions, so 95% is returned as 0.95.

    required_fields = {'mode', 'outcome', 'reliability', 'confidence', ...
        'accuracy_mm', 'interaction_gap_mm', 'no_interaction_gap_mm', ...
        'minimum_gap_mm', 'maximum_gap_mm', 'previous_information', ...
        'available_articles', 'physical_setup'};
    for field_number = 1:numel(required_fields)
        field_name = required_fields{field_number};
        if ~isstruct(input) || ~isfield(input, field_name)
            error('validate_plan_inputs:missingAnswer', ...
                'The planner answer "%s" is missing. Please complete that question.', ...
                field_name);
        end
    end

    clean = input;
    clean.mode = normalized_text(input.mode);
    if ~any(strcmp(clean.mode, {'requirements_first', ...
            'available_articles_first'}))
        error('validate_plan_inputs:badMode', ...
            'Choose whether to plan from requirements or from the articles available.');
    end

    clean.outcome = normalized_text(input.outcome);
    if isempty(clean.outcome)
        error('validate_plan_inputs:missingOutcome', ...
            'Choose Interaction or No interaction before calculating the plan.');
    end
    if ~any(strcmp(clean.outcome, {'interaction', 'no_interaction'}))
        error('validate_plan_inputs:badOutcome', ...
            'The required result must be Interaction or No interaction.');
    end

    clean.reliability = normalize_percentage(input.reliability, ...
        'validate_plan_inputs:badReliability', 'Reliability');
    clean.confidence = normalize_percentage(input.confidence, ...
        'validate_plan_inputs:badConfidence', 'Confidence');

    numeric_fields = {'accuracy_mm', 'interaction_gap_mm', ...
        'no_interaction_gap_mm', 'minimum_gap_mm', 'maximum_gap_mm'};
    for field_number = 1:numel(numeric_fields)
        field_name = numeric_fields{field_number};
        value = input.(field_name);
        if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
            error('validate_plan_inputs:badNumber', ...
                '%s must be one finite number in millimetres.', ...
                readable_field_name(field_name));
        end
        clean.(field_name) = double(value);
    end

    if clean.maximum_gap_mm <= clean.minimum_gap_mm
        error('validate_plan_inputs:badPermittedRange', ...
            'The maximum permitted gap must be greater than the minimum gap.');
    end
    if clean.interaction_gap_mm >= clean.no_interaction_gap_mm
        error('validate_plan_inputs:reversedExpectations', ...
            ['The almost-always Interaction gap must be smaller than the ' ...
             'almost-always No-interaction gap for this application.']);
    end
    if clean.interaction_gap_mm < clean.minimum_gap_mm || ...
            clean.no_interaction_gap_mm > clean.maximum_gap_mm
        error('validate_plan_inputs:expectationOutsideRange', ...
            'Both expected gaps must be inside the permitted gap range.');
    end
    permitted_width = clean.maximum_gap_mm - clean.minimum_gap_mm;
    if clean.accuracy_mm <= 0 || clean.accuracy_mm > permitted_width
        error('validate_plan_inputs:badAccuracy', ...
            'Required gap accuracy must be positive and smaller than the permitted range.');
    end

    clean.previous_information = normalized_text(input.previous_information);
    if ~any(strcmp(clean.previous_information, {'first_study', ...
            'sudden', 'gradual', 'advanced_value'}))
        error('validate_plan_inputs:badPreviousInformation', ...
            'Choose first study, sudden change, gradual change, or an advanced value.');
    end

    if strcmp(clean.mode, 'available_articles_first')
        article_count = input.available_articles;
        if ~(isnumeric(article_count) && isscalar(article_count) && ...
                isreal(article_count) && isfinite(article_count) && ...
                article_count >= 1 && article_count == floor(article_count))
            error('validate_plan_inputs:badAvailableArticles', ...
                'The number of available articles must be a positive whole number.');
        end
        clean.available_articles = double(article_count);
    else
        clean.available_articles = [];
    end

    if ~isstruct(clean.physical_setup) || ~isfield(clean.physical_setup, 'mode')
        error('validate_plan_inputs:badPhysicalSetup', ...
            'Choose how the physical gaps can be built.');
    end

    if clean.confidence < 0.5
        confidence_message = "This confidence is exploratory only. " + ...
            "It is below 50% and is not a cautious reliability claim.";
    elseif clean.confidence == 0.5
        confidence_message = "50% confidence is the centre estimate " + ...
            "with no safety margin.";
    else
        confidence_message = "This confidence applies a cautious safety " + ...
            "margin to the result.";
    end
    messages = [confidence_message; ...
        "Almost every time is treated as at least 95%, not as 100%."];
end

function value = normalize_percentage(raw_value, error_id, label)
    if ~(isnumeric(raw_value) && isscalar(raw_value) && isreal(raw_value) && ...
            isfinite(raw_value) && raw_value > 0)
        error(error_id, '%s must be between 10%% and 99.9%%.', label);
    end
    value = double(raw_value);
    if value > 1
        value = value / 100;
    end
    endpoint_tolerance = 1e-12;
    if value < 0.10 - endpoint_tolerance || value > 0.999 + endpoint_tolerance
        error(error_id, '%s must be between 10%% and 99.9%%.', label);
    end
    value = min(max(value, 0.10), 0.999);
end

function text = normalized_text(value)
    if isstring(value) && isscalar(value)
        text = lower(strtrim(char(value)));
    elseif ischar(value) && isrow(value)
        text = lower(strtrim(value));
    else
        text = '';
    end
end

function label = readable_field_name(field_name)
    label = strrep(field_name, '_', ' ');
    label = regexprep(label, ' mm$', '');
    label(1) = upper(label(1));
end
