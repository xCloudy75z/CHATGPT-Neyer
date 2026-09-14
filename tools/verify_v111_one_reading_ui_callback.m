function verify_v111_one_reading_ui_callback(varargin) %#ok<INUSD>
%VERIFY_V111_ONE_READING_UI_CALLBACK Drive one safe automated UI smoke path.
try
    settings_figure = findall(groot,'Type','figure', ...
        'Name','Neyer gap test - inputs');
    if numel(settings_figure) == 1
        settled_ticks = 0;
        if isappdata(groot,'v111_settings_settled_ticks')
            settled_ticks = getappdata(groot,'v111_settings_settled_ticks');
        end
        settled_ticks = settled_ticks + 1;
        setappdata(groot,'v111_settings_settled_ticks',settled_ticks);
        if settled_ticks < 8, return; end
        drawnow;
        edits = findall(settings_figure,'Type','uieditfield');
        buttons = findall(settings_figure,'Type','uibutton');
        edits = edits(isgraphics(edits));
        start_button = find_button_by_text(buttons,"Start test");
        if numel(edits) ~= 9 || isempty(start_button)
            setappdata(groot,'v111_one_reading_ui_last_transient', ...
                sprintf('Settings visible: %d edit fields, %d buttons, start found: %d.', ...
                numel(edits),numel(buttons),~isempty(start_button)));
            return;
        end
        for edit_index = 1:numel(edits)
            if edits(edit_index).Layout.Row == 5
                edits(edit_index).Value = '3';
            end
        end
        setappdata(groot,'v111_one_reading_ui_last_transient', ...
            'Settings accepted; waiting for the one-reading test screen.');
        feval(start_button.ButtonPushedFcn,start_button,[]);
        setappdata(groot,'v111_gap_settled_ticks',0);
        return;
    end

    gap_figure = findall(groot,'Type','figure','Name','Neyer gap test');
    if numel(gap_figure) == 1
        settled_ticks = getappdata(groot,'v111_gap_settled_ticks');
        settled_ticks = settled_ticks + 1;
        setappdata(groot,'v111_gap_settled_ticks',settled_ticks);
        if settled_ticks < 8, return; end
        setappdata(groot,'v111_one_reading_ui_last_transient', ...
            'One-reading test screen found; checking its controls.');
        drawnow;
        if isappdata(groot,'v111_ui_screen_path')
            exportapp(gap_figure,getappdata(groot,'v111_ui_screen_path'));
        end
        labels = findall(gap_figure,'Type','uilabel');
        visible_text = strjoin(string({labels.Text}),' | ');
        assert(contains(visible_text,'Enter the measured gap:'), ...
            'The physical screen did not ask for one measured gap.');
        edits = findall(gap_figure,'Type','uieditfield');
        assert(numel(edits) == 1, ...
            'The physical screen must contain one measurement field.');
        assert(strcmp(edits.Placeholder,'Example: 2.507'), ...
            'The measurement example does not show one reading.');
        edits.Value = '5.007';
        buttons = findall(gap_figure,'Type','uibutton');
        outcome_button = find_button_by_text(buttons,"Interaction");
        assert(~isempty(outcome_button),'The Interaction button is missing.');
        feval(outcome_button.ButtonPushedFcn,outcome_button,[]);
        setappdata(groot,'v111_one_reading_ui_last_transient', ...
            'One reading and outcome accepted; waiting for results.');
        return;
    end

    result_figure = findall(groot,'Type','figure', ...
        'Name','Neyer gap-study results');
    if ~isempty(result_figure)
        setappdata(groot,'v111_one_reading_ui_checked',true);
        setappdata(groot,'v111_one_reading_ui_error','');
        return;
    end
    figure_names = strings(0,1);
    open_figures = findall(groot,'Type','figure');
    for figure_index = 1:numel(open_figures)
        try
            figure_names(end+1,1) = string(open_figures(figure_index).Name); %#ok<AGROW>
        catch
        end
    end
    setappdata(groot,'v111_one_reading_ui_last_transient', ...
        sprintf('Waiting. Open windows: %s',strjoin(figure_names,', ')));
catch verification_error
    % A uifigure may briefly appear in findall before MATLAB finishes
    % constructing it. Let the next timer visit retry with the settled UI.
    setappdata(groot,'v111_one_reading_ui_last_transient', ...
        verification_error.message);
end
end

function matching_button = find_button_by_text(buttons,required_text)
matching_button = [];
for button_index = 1:numel(buttons)
    try
        if string(buttons(button_index).Text) == required_text
            matching_button = buttons(button_index);
            return;
        end
    catch
        % MATLAB may briefly return a placeholder while the window draws.
    end
end
end
