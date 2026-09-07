function [plan, loaded_path] = load_study_plan(selected_path)
%LOAD_STUDY_PLAN Reopen a supported human-readable JSON study plan.

    loaded_path = absolute_load_path(selected_path);
    if ~isfile(loaded_path)
        error('load_study_plan:notFound', ...
            'The selected study plan could not be found: %s', loaded_path);
    end
    try
        plan = jsondecode(fileread(loaded_path));
    catch decode_error
        error('load_study_plan:invalidJson', ...
            'The selected file is not a readable study plan: %s', ...
            decode_error.message);
    end
    if ~isstruct(plan) || ~isfield(plan, 'schema_version')
        error('load_study_plan:unsupportedVersion', ...
            'This file has no supported study-plan version.');
    end
    version_text = char(string(plan.schema_version));
    if ~strcmp(version_text, '1.1')
        error('load_study_plan:unsupportedVersion', ...
            ['This study plan uses version %s. This tool supports the safer ' ...
             'version 1.1 plan; the older file was not changed. Create a new ' ...
             'plan so the validated article floor and confidence limits are present.'], ...
             version_text);
    end
    required_fields = {'mode', 'outcome', 'reliability', 'confidence', ...
        'accuracy_mm', 'minimum_gap_mm', 'maximum_gap_mm', ...
        'main_articles', 'reserve_1_articles', 'reserve_2_articles', ...
        'total_articles', 'reachable_model', 'checkpoint_status', ...
        'reliability_validation_floor_articles', ...
        'reliability_instruction_supported', ...
        'reliability_instruction_status'};
    if ~all(isfield(plan, required_fields))
        error('load_study_plan:incompletePlan', ...
            'The selected plan is missing information required to continue the study.');
    end
    [safe_plan, safety_message] = validate_study_plan_safety(plan);
    if ~safe_plan
        error('load_study_plan:unsafePlan', ...
            'The selected plan cannot be used safely: %s', safety_message);
    end
end

function path = absolute_load_path(selected_path)
    if isstring(selected_path) && isscalar(selected_path)
        path = char(selected_path);
    elseif ischar(selected_path) && isrow(selected_path)
        path = selected_path;
    else
        error('load_study_plan:badPath', ...
            'Choose one complete study-plan filename.');
    end
    path = strtrim(path);
    if isempty(path)
        error('load_study_plan:badPath', ...
            'Choose one complete study-plan filename.');
    end
    is_windows_absolute = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
    is_unc = startsWith(path, '\\');
    if ~(is_windows_absolute || is_unc)
        path = fullfile(pwd, path);
    end
end
