function result = run_test_ui(cfg0, loaded_plan)
%RUN_TEST_UI  Run a Neyer test through large, readable pop-up windows (MATLAB
%   desktop only): settings, then the reachable gap, measured readings, and
%   interaction outcome for each test. Physical validation lives in
%   parse_run_inputs and run_physical_test.
    if ~(isdeployed || usejava('desktop'))
        error('run_test_ui:noDisplay', ...
              'run_test_ui needs the MATLAB desktop; in a script use run_test instead.');
    end
    if nargin < 2, loaded_plan = []; end
    parsed = ask_settings_ui(loaded_plan);
    if isempty(parsed), fprintf('run_test_ui: cancelled.\n'); result = []; return; end
    if nargin >= 1 && ~isempty(cfg0)
        parsed.cfg = apply_run_configuration_overrides(parsed.cfg, cfg0);
    end
    try
        result = run_physical_test(parsed.params, parsed.num_parts, ...
            @(level,k)gap_popup(level,k,parsed.num_parts, ...
                parsed.cfg.usable_resolution, reachable_model_or_empty(parsed.cfg)), ...
                parsed.cfg);
    catch e
        if strcmp(e.identifier, 'run_test_ui:aborted')
            fprintf('run_test_ui: cancelled during testing.\n'); result = []; return;
        end
        rethrow(e);
    end
    try
        if ~isempty(loaded_plan)
            result.study_plan = loaded_plan;
            if isfield(result, 'checkpoint_decisions') && ...
                    ~isempty(result.checkpoint_decisions)
                result.checkpoint_decision = result.checkpoint_decisions{end};
            else
                result.checkpoint_decision = check_study_checkpoint( ...
                    result, loaded_plan, 'main');
            end
        end
        show_result(result);
    catch result_error
        warning('run_test_ui:resultDisplayFailed', ...
            'The tests finished, but the results window did not open: %s', ...
            result_error.message);
        show_result_error_notice(result_error);
    end

end

% =================================================================================
function parsed = ask_settings_ui(loaded_plan)
%ASK_SETTINGS_UI  Large, readable settings window. Returns a parsed struct or [].
    labels = {'Low guess for the middle gap (mm):', ...
              'High guess for the middle gap (mm):', ...
              'Rough guess of the overall variation (mm):', ...
              'Maximum allowed number of destructive tests:', ...
              'Minimum permitted gap (mm):', ...
              'Maximum permitted gap (mm):', ...
              'Gap unit:', ...
              'Usable gap step for this study (mm):', ...
              'Approximate foil thickness (mm, information only):'};
    defs = {'0','10','1','20','0','10','mm','0.05','0.015'};
    planned_message = [ ...
        'No Pre-Test Planner is used. The article number is the maximum ' ...
        'allowed, not a confidence-based stopping promise.'];
    if nargin >= 1 && ~isempty(loaded_plan)
        if all(isfield(loaded_plan, {'interaction_gap_mm', ...
                'no_interaction_gap_mm', 'estimated_sigma_mm', ...
                'main_articles', 'minimum_gap_mm'}))
            defs{1} = sprintf('%.6g', loaded_plan.interaction_gap_mm);
            defs{2} = sprintf('%.6g', loaded_plan.no_interaction_gap_mm);
            defs{3} = sprintf('%.6g', loaded_plan.estimated_sigma_mm);
            defs{4} = sprintf('%d', loaded_plan.main_articles);
            defs{5} = sprintf('%.6g', loaded_plan.minimum_gap_mm);
            planned_message = sprintf('Planned checkpoint: Main study - %d articles', ...
                loaded_plan.main_articles);
            if isfield(loaded_plan, 'maximum_gap_mm')
                defs{6} = sprintf('%.6g', loaded_plan.maximum_gap_mm);
            end
            defs{8} = sprintf('%.6g', usable_resolution_for_plan( ...
                loaded_plan, str2double(defs{8})));
        end
    end

    fig = uifigure('Name', 'Neyer gap test - inputs', 'Position', [280 45 720 750]);
    gl  = uigridlayout(fig, [11 2]);
    gl.RowHeight     = {70, 46, 46, 46, 46, 46, 46, 46, 46, 46, 54};
    gl.ColumnWidth   = {'1x', 190};
    gl.Padding       = [28 24 28 24];
    gl.RowSpacing    = 12;
    gl.ColumnSpacing = 16;

    ttl = uilabel(gl, 'Text', ['Run a Test directly  |  ' planned_message], ...
        'FontSize', 17, 'FontWeight', 'bold', 'WordWrap', 'on');
    ttl.Layout.Row = 1; ttl.Layout.Column = [1 2];

    edits = gobjects(1, 9);
    for i = 1:9
        lb = uilabel(gl, 'Text', labels{i}, 'FontSize', 15, 'WordWrap', 'on');
        lb.Layout.Row = i + 1; lb.Layout.Column = 1;
        edits(i) = uieditfield(gl, 'text', 'Value', defs{i}, 'FontSize', 16);
        edits(i).Layout.Row = i + 1; edits(i).Layout.Column = 2;
    end

    bp = uigridlayout(gl, [1 2]);
    bp.Layout.Row = 11; bp.Layout.Column = [1 2];
    bp.ColumnWidth = {'1x', '1x'}; bp.Padding = [0 6 0 0]; bp.ColumnSpacing = 16;
    uibutton(bp, 'Text', 'Start test', 'FontSize', 16, 'FontWeight', 'bold', ...
             'BackgroundColor', [0.20 0.42 0.40], 'FontColor', [1 1 1], ...
             'ButtonPushedFcn', @(~,~) startTest());
    uibutton(bp, 'Text', 'Cancel', 'FontSize', 16, 'ButtonPushedFcn', @(~,~) cancelTest());

    store = struct('parsed', []);
    fig.CloseRequestFcn = @(~,~) cancelTest();
    uiwait(fig);
    parsed = store.parsed;
    if isvalid(fig), delete(fig); end

    function startTest()
        answers = cell(1, 9);
        for j = 1:9, answers{j} = edits(j).Value; end
        try
            store.parsed = parse_run_inputs(answers);
            if ~isempty(loaded_plan)
                store.parsed.loaded_plan = loaded_plan;
                store.parsed.num_parts = loaded_plan.total_articles;
                store.parsed.cfg.study_plan = loaded_plan;
                store.parsed.cfg.reserve_decision_fn = @ask_reserve_ui;
                if isfield(loaded_plan, 'maximum_gap_mm')
                    store.parsed.cfg.max_level = loaded_plan.maximum_gap_mm;
                end
                if isfield(loaded_plan, 'reachable_model')
                    store.parsed.cfg.reachable_model = loaded_plan.reachable_model;
                end
            end
            uiresume(fig);
        catch e
            uialert(fig, e.message, 'Please fix your inputs');
        end
    end
    function cancelTest()
        store.parsed = [];
        uiresume(fig);
    end
end

function approved = ask_reserve_ui(decision)
%ASK_RESERVE_UI Obtain explicit permission before consuming a reserve group.
    prompt_figure = uifigure('Name', 'Study checkpoint', ...
        'Position', [420 260 520 230], 'Visible', 'on');
    cleanup_figure = onCleanup(@() delete_if_valid(prompt_figure));
    missing_text = strjoin(cellstr(decision.missing_conditions), newline);
    choice = uiconfirm(prompt_figure, sprintf([ ...
        '%s\n\nWhat is still missing:\n%s\n\nUse %s now?'], ...
        decision.plain_explanation, missing_text, ...
        strrep(decision.next_checkpoint, '_', ' ')), ...
        'Planned checkpoint', ...
        'Options', {'Use this reserve group', 'Stop and review'}, ...
        'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
    approved = strcmp(choice, 'Use this reserve group');
    clear cleanup_figure;
end

function delete_if_valid(figure_handle)
    if isvalid(figure_handle), delete(figure_handle); end
end

function show_result_error_notice(result_error)
    try
        notice = uifigure('Name', 'Neyer result notice', ...
            'Position', [460 300 520 180]);
        message = sprintf([ ...
            'The tests finished, but the results window could not open.\n\n' ...
            'Return to the main menu and select Review latest results.\n\n' ...
            'Reason: %s'], result_error.message);
        uialert(notice, message, 'Results not shown', 'Icon', 'warning', ...
            'CloseFcn', @(~, ~) delete_if_valid(notice));
    catch notice_error
        warning('run_test_ui:resultNoticeFailed', ...
            'The result notice could not open: %s', notice_error.message);
    end
end

% =================================================================================
function response = gap_popup(level, k, N, usable_resolution, reachable_model)
%GAP_POPUP Show one reachable setting and collect its physical result.
    if nargin < 5, reachable_model = []; end
    fig = uifigure('Name', 'Neyer gap test', 'Position', [300 170 650 440]);
    gl  = uigridlayout(fig, [5 2]);
    gl.RowHeight     = {'fit', 90, 54, 54, 64};
    gl.ColumnWidth   = {'1x', '1x'};
    gl.Padding       = [30 24 30 24];
    gl.RowSpacing    = 16;
    gl.ColumnSpacing = 16;

    l1 = uilabel(gl, 'Text', sprintf('Test %d of %d', k, N), ...
                 'FontSize', 16, 'FontColor', [0.38 0.38 0.38], 'HorizontalAlignment', 'center');
    l1.Layout.Row = 1; l1.Layout.Column = [1 2];
    requested_text = format_requested_gap(level,'mm');
    if ~isempty(reachable_model)
        [distance, recipe_row] = min(abs(reachable_model.gaps_mm(:) - level));
        if distance <= reachable_model.comparison_tolerance_mm
            requested_text = sprintf('%s\n%s', requested_text, ...
                char(reachable_model.instructions(recipe_row)));
        end
    end
    l2 = uilabel(gl, 'Text', requested_text, ...
                 'FontSize', 22, 'FontWeight', 'bold', 'WordWrap', 'on', 'HorizontalAlignment', 'center');
    l2.Layout.Row = 2; l2.Layout.Column = [1 2];

    prompt=uilabel(gl,'Text','Enter 4 or 5 measured gaps:', ...
        'FontSize',15,'HorizontalAlignment','right');
    prompt.Layout.Row=3; prompt.Layout.Column=1;
    reading_edit=uieditfield(gl,'text','FontSize',16, ...
        'Placeholder','Example: 2.50, 2.49, 2.52, 2.48');
    reading_edit.Layout.Row=3; reading_edit.Layout.Column=2;
    note_text='Measure this new spacer build. Its mean will be used in the calculation.';
    note=uilabel(gl,'Text',note_text,'FontSize',14,'WordWrap','on', ...
        'HorizontalAlignment','center');
    note.Layout.Row=4; note.Layout.Column=[1 2];

    store = struct('response', []);
    bI = uibutton(gl, 'Text', 'Interaction', 'FontSize', 18, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.80 0.45 0.38], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) submitResult(true));
    bI.Layout.Row = 5; bI.Layout.Column = 1;
    bN = uibutton(gl, 'Text', 'No interaction', 'FontSize', 18, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.30 0.55 0.42], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) submitResult(false));
    bN.Layout.Row = 5; bN.Layout.Column = 2;

    fig.CloseRequestFcn = @(~,~) cancelResult();
    uiwait(fig);
    response = store.response;
    if isvalid(fig), delete(fig); end
    if isempty(response), error('run_test_ui:aborted', 'cancelled by operator.'); end

    function submitResult(outcome)
        try
            store.response=parse_physical_response(reading_edit.Value,outcome);
        catch e
            uialert(fig,e.message,'Please check the measurements');
            return;
        end
        reading_range=max(store.response.measurements)-min(store.response.measurements);
        if reading_range > usable_resolution
            choice=uiconfirm(fig,sprintf([ ...
                'These readings span %.3f mm, which is greater than the ' ...
                '%.2f mm usable gap step for this study. Check the setup ' ...
                'and measurement method before continuing.'], ...
                reading_range,usable_resolution), ...
                'Measurement variation warning', ...
                'Options',{'Check again','Use these readings'}, ...
                'DefaultOption',1,'CancelOption',1);
            if strcmp(choice,'Check again')
                store.response=[];
                return;
            end
        end
        uiresume(fig);
    end
    function cancelResult()
        store.response=[];
        uiresume(fig);
    end
end

function model = reachable_model_or_empty(cfg)
    if isfield(cfg, 'reachable_model')
        model = cfg.reachable_model;
    else
        model = [];
    end
end
