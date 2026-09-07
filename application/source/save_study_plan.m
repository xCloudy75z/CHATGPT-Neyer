function saved_path = save_study_plan(plan, selected_path)
%SAVE_STUDY_PLAN Save a human-readable study plan without replacing a file.
% The caller chooses the complete destination. The exact path is returned so
% the interface can show where the plan was saved.

    if ~isstruct(plan) || ~all(isfield(plan, {'schema_version', 'mode', ...
            'outcome', 'main_articles', 'reserve_1_articles', ...
            'reserve_2_articles', 'total_articles', 'reachable_model'}))
        error('save_study_plan:badPlan', ...
            'The study plan is incomplete and cannot be saved.');
    end
    saved_path = absolute_path(selected_path);
    [folder, ~, extension] = fileparts(saved_path);
    if ~strcmpi(extension, '.json')
        error('save_study_plan:badExtension', ...
            'Choose a filename ending in .json for the study plan.');
    end
    if ~isfolder(folder)
        error('save_study_plan:folderNotFound', ...
            'The selected save folder does not exist: %s', folder);
    end
    if isfile(saved_path)
        error('save_study_plan:alreadyExists', ...
            ['A file already exists at this location. Choose a new name; ' ...
             'the existing plan was not replaced: %s'], saved_path);
    end

    saved_plan = plan;
    saved_plan.saved_at = char(datetime('now', 'TimeZone', 'local'), ...
        'yyyy-MM-dd HH:mm:ss Z');
    try
        json_text = jsonencode(saved_plan, 'PrettyPrint', true);
    catch encode_error
        error('save_study_plan:encodeFailed', ...
            'The study plan could not be converted to JSON: %s', ...
            encode_error.message);
    end

    file_id = fopen(saved_path, 'wt', 'n', 'UTF-8');
    if file_id < 0
        error('save_study_plan:cannotOpen', ...
            'MATLAB could not create the selected plan file: %s', saved_path);
    end
    try
        written_count = fprintf(file_id, '%s\n', json_text);
        if written_count < strlength(string(json_text))
            error('save_study_plan:writeFailed', ...
                'MATLAB could not finish writing the selected plan file.');
        end
        fclose(file_id);
        file_id = -1;
    catch write_error
        if file_id >= 0
            fclose(file_id);
        end
        if isfile(saved_path)
            delete(saved_path);
        end
        if startsWith(write_error.identifier, 'save_study_plan:')
            rethrow(write_error);
        end
        error('save_study_plan:writeFailed', ...
            'MATLAB could not finish writing the selected plan file: %s', ...
            write_error.message);
    end
end

function path = absolute_path(selected_path)
    if isstring(selected_path) && isscalar(selected_path)
        path = char(selected_path);
    elseif ischar(selected_path) && isrow(selected_path)
        path = selected_path;
    else
        error('save_study_plan:badPath', ...
            'Choose one complete filename for the study plan.');
    end
    path = strtrim(path);
    if isempty(path)
        error('save_study_plan:badPath', ...
            'Choose one complete filename for the study plan.');
    end
    is_windows_absolute = ~isempty(regexp(path, '^[A-Za-z]:[\\/]', 'once'));
    is_unc = startsWith(path, '\\');
    if ~(is_windows_absolute || is_unc)
        path = fullfile(pwd, path);
    end
end
