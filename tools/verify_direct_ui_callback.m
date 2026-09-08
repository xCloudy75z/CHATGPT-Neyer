function verify_direct_ui_callback(varargin) %#ok<INUSD>
%VERIFY_DIRECT_UI_CALLBACK Inspect and close the modal direct-test inputs.
    try
        settings_figure = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test - inputs');
        if numel(settings_figure) ~= 1, return; end
        edits = findall(settings_figure, 'Type', 'uieditfield');
        buttons = findall(settings_figure, 'Type', 'uibutton');
        if numel(edits) ~= 9 || ...
                ~any(string({buttons.Text}) == "Start test")
            return;
        end
        labels = findall(settings_figure, 'Type', 'uilabel');
        visible_text = strjoin(string({labels.Text}), ' | ');
        assert(contains(visible_text, 'Maximum permitted gap'), ...
            'The maximum permitted gap input is missing.');
        assert(contains(visible_text, 'No Pre-Test Planner is used'), ...
            'The direct-test screen does not explain that the planner is unused.');
        setappdata(groot, 'direct_ui_checked', true);
        setappdata(groot, 'direct_ui_error', '');
        delete(settings_figure);
    catch verification_error
        setappdata(groot, 'direct_ui_error', verification_error.message);
        settings_figure = findall(groot, 'Type', 'figure', ...
            'Name', 'Neyer gap test - inputs');
        if ~isempty(settings_figure)
            delete(settings_figure);
        end
    end
end
