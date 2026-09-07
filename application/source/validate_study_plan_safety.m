function [is_valid, message] = validate_study_plan_safety(plan)
%VALIDATE_STUDY_PLAN_SAFETY Check the fixed v1.10 reliability safeguards.
% A missing or edited safeguard must never turn into permission to issue an
% operating instruction.

    is_valid = false;
    message = '';
    required = {'reliability', 'confidence', ...
        'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~isstruct(plan) || ~all(isfield(plan, required))
        message = [ ...
            'The study plan is missing the v1.10 reliability safety rules.'];
        return;
    end

    floor_articles = plan.reliability_validation_floor_articles;
    if ~(isnumeric(floor_articles) && isscalar(floor_articles) && ...
            isreal(floor_articles) && isfinite(floor_articles) && ...
            floor_articles == 400)
        message = [ ...
            'The reliability safety floor must remain 400 independent articles.'];
        return;
    end

    confidence = plan.confidence;
    if ~(isnumeric(confidence) && isscalar(confidence) && ...
            isreal(confidence) && isfinite(confidence) && ...
            confidence >= 0.10 && confidence <= 0.999)
        message = 'The saved confidence is outside the permitted planning range.';
        return;
    end

    reliability = plan.reliability;
    if ~(isnumeric(reliability) && isscalar(reliability) && ...
            isreal(reliability) && isfinite(reliability) && ...
            reliability >= 0.10 && reliability <= 0.999)
        message = 'The saved reliability is outside the permitted 10% to 99.9% range.';
        return;
    end

    support_flag = plan.reliability_instruction_supported;
    if ~(islogical(support_flag) && isscalar(support_flag))
        message = 'The reliability-support decision in the plan is invalid.';
        return;
    end

    if confidence <= 0.50
        expected_support = false;
        expected_status = 'exploratory_confidence';
    elseif confidence > 0.95
        expected_support = false;
        expected_status = 'above_recorded_validation';
    else
        expected_support = true;
        expected_status = 'supported_after_final_checkpoint';
    end
    status_text = char(string(plan.reliability_instruction_status));
    if support_flag ~= expected_support || ~strcmp(status_text, expected_status)
        message = [ ...
            'The saved confidence and reliability-support decision do not agree.'];
        return;
    end

    is_valid = true;
end
