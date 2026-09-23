function result = run_test_ui(cfg0, loaded_plan)
%RUN_TEST_UI  Run a Neyer test through large, readable pop-up windows (MATLAB
%   desktop only): settings, then the reachable gap, one measured gap, and
%   interaction outcome for each test. Physical validation lives in
%   parse_run_inputs and run_physical_test.
    capture_inputs = isappdata(groot, 'NeyerV2CaptureDirectInputs') && ...
        getappdata(groot, 'NeyerV2CaptureDirectInputs');
    if ~(isdeployed || usejava('desktop') || capture_inputs)
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
                reachable_model_or_empty(parsed.cfg)), ...
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
    defaults = struct('study_mode', 'First study - variation unknown', ...
        'low_guess', '0', 'high_guess', '10', ...
        'variation_guess', '1', 'maximum_tests', '20', ...
        'minimum_gap', '0', 'maximum_gap', '10', 'unit', 'mm', ...
        'regular_step', '0.05', 'confirmed_gaps', '', ...
        'foil_thickness', '0.015');
    planned_message = ['No Pre-Test Planner result is required. ' ...
        'Start this direct run with the entries below.'];
    if nargin >= 1 && ~isempty(loaded_plan)
        if all(isfield(loaded_plan, {'interaction_gap_mm', ...
                'no_interaction_gap_mm', 'estimated_sigma_mm', ...
                'main_articles', 'minimum_gap_mm'}))
            defaults.low_guess = sprintf('%.6g', loaded_plan.interaction_gap_mm);
            defaults.high_guess = sprintf('%.6g', loaded_plan.no_interaction_gap_mm);
            defaults.variation_guess = sprintf('%.6g', loaded_plan.estimated_sigma_mm);
            defaults.study_mode = 'Advanced - starting variation known';
            defaults.maximum_tests = sprintf('%d', loaded_plan.main_articles);
            defaults.minimum_gap = sprintf('%.6g', loaded_plan.minimum_gap_mm);
            planned_message = sprintf('Planned checkpoint: Main study - %d articles', ...
                loaded_plan.main_articles);
            if isfield(loaded_plan, 'maximum_gap_mm')
                defaults.maximum_gap = sprintf('%.6g', loaded_plan.maximum_gap_mm);
            end
            defaults.regular_step = sprintf('%.6g', usable_resolution_for_plan( ...
                loaded_plan, str2double(defaults.regular_step)));
        end
    end

    fig = uifigure('Name', 'Neyer gap test - inputs', ...
        'Position', [220 30 860 680], 'Color', [0.97 0.98 0.98]);
    gl = uigridlayout(fig, [13 1]);
    gl.Tag = 'direct_input_scroll_layout';
    gl.Scrollable = 'on';
    gl.RowHeight = {56, 62, 52, 52, 0, 62, 52, 52, 48, 68, 76, 52, 48};
    gl.ColumnWidth = {'1x'};
    gl.Padding = [28 18 28 18];
    gl.RowSpacing = 7;

    ttl = uilabel(gl, 'Text', ['Run a Test directly  |  ' planned_message], ...
        'FontSize', 18, 'FontWeight', 'bold', 'WordWrap', 'on', ...
        'FontColor', [0.12 0.20 0.24]);
    ttl.Layout.Row = 1;

    study_mode = add_dropdown_input(gl, 2, ...
        'How much do you know before this study?', ...
        ['For a first study, the program chooses only an internal starting ' ...
         'search scale. It does not pretend that overall variation is already known.'], ...
        'study_mode', 'study_mode_help', ...
        {'First study - variation unknown', ...
         'Advanced - starting variation known'}, defaults.study_mode);
    study_mode.field.ValueChangedFcn = @(~, ~) update_study_mode();

    low_guess = add_text_input(gl, 3, ...
        'Low guess for the middle gap (mm)', ...
        ['Your smallest reasonable guess for the gap where Interaction and ' ...
         'No interaction are equally likely. This starts the search; it is not a limit.'], ...
        'low_guess', 'low_guess_help', defaults.low_guess);
    high_guess = add_text_input(gl, 4, ...
        'High guess for the middle gap (mm)', ...
        ['Your largest reasonable guess for the gap where Interaction and ' ...
         'No interaction are equally likely.'], ...
        'high_guess', 'high_guess_help', defaults.high_guess);
    variation_guess = add_text_input(gl, 5, ...
        'Advanced starting variation estimate (mm)', ...
        ['Use this only when earlier evidence gives a reasonable starting ' ...
         'value. It affects early requests but is not the final result.'], ...
        'variation_guess', 'variation_guess_help', defaults.variation_guess);
    maximum_tests = add_text_input(gl, 6, ...
        'Maximum allowed number of destructive tests', ...
        ['The most new articles this direct run may consume. It is a maximum, ' ...
         'not a promise that a confidence level will be reached.'], ...
        'maximum_tests', 'maximum_tests_help', defaults.maximum_tests);
    minimum_gap = add_text_input(gl, 7, ...
        'Minimum permitted gap (mm)', ...
        'The smallest gap the study is allowed to request.', ...
        'minimum_gap', 'minimum_gap_help', defaults.minimum_gap);
    maximum_gap = add_text_input(gl, 8, ...
        'Maximum permitted gap (mm)', ...
        'The largest useful gap the study is allowed to request.', ...
        'maximum_gap', 'maximum_gap_help', defaults.maximum_gap);
    unit = add_text_input(gl, 9, ...
        'Gap unit (millimetres only)', ...
        'Direct testing currently uses millimetres. Leave this entry as mm.', ...
        'unit', 'unit_help', defaults.unit);
    physical_mode = add_dropdown_input(gl, 10, ...
        'How can you build the test gaps?', ...
        ['Choose the method that matches what can actually be built. ' ...
         'Only the selected entry below will be used.'], ...
        'physical_mode', 'physical_mode_help', ...
        {'Regular gap step', 'Confirmed gap list'}, ...
        'Regular gap step');

    physical_entries = uigridlayout(gl, [2 1]);
    physical_entries.Layout.Row = 11;
    physical_entries.RowHeight = {76, 0};
    physical_entries.ColumnWidth = {'1x'};
    physical_entries.Padding = [0 0 0 0];
    physical_entries.RowSpacing = 0;
    regular_step = add_text_input(physical_entries, 1, ...
        'Regular gap step (mm)', ...
        ['Use this only when every multiple of this step can genuinely be built ' ...
         'inside the permitted range, such as 0.05 mm or 0.10 mm.'], ...
        'regular_step', 'regular_step_help', defaults.regular_step);
    confirmed_gaps = add_text_input(physical_entries, 2, ...
        'Confirmed gap list', ...
        ['Enter only measured gaps already confirmed as buildable, separated by ' ...
         'commas and using no more than two decimal places, such as ' ...
         '1.00, 1.10, 2.50.'], ...
        'confirmed_gaps', 'confirmed_gaps_help', defaults.confirmed_gaps);
    set_input_state(confirmed_gaps, false);
    physical_mode.field.ValueChangedFcn = @(~, ~) update_physical_mode();

    foil_thickness = add_text_input(gl, 12, ...
        'Approximate foil thickness (mm)', ...
        ['Construction information only. It does not set the usable gap step ' ...
         'or change the calculation.'], ...
        'foil_thickness', 'foil_thickness_help', defaults.foil_thickness);

    bp = uigridlayout(gl, [1 2]);
    bp.Layout.Row = 13;
    bp.ColumnWidth = {'1x', '1x'}; bp.Padding = [0 6 0 0]; bp.ColumnSpacing = 16;
    uibutton(bp, 'Text', 'Start test', 'FontSize', 16, 'FontWeight', 'bold', ...
             'BackgroundColor', [0.20 0.42 0.40], 'FontColor', [1 1 1], ...
             'ButtonPushedFcn', @(~,~) startTest());
    uibutton(bp, 'Text', 'Cancel', 'FontSize', 16, 'ButtonPushedFcn', @(~,~) cancelTest());

    update_study_mode();
    store = struct('parsed', []);
    fig.CloseRequestFcn = @(~,~) cancelTest();
    uiwait(fig);
    parsed = store.parsed;
    if isvalid(fig), delete(fig); end

    function startTest()
        answers = struct( ...
            'study_mode', study_mode.field.Value, ...
            'low_guess', low_guess.field.Value, ...
            'high_guess', high_guess.field.Value, ...
            'variation_guess', variation_guess.field.Value, ...
            'maximum_tests', maximum_tests.field.Value, ...
            'minimum_gap', minimum_gap.field.Value, ...
            'maximum_gap', maximum_gap.field.Value, ...
            'unit', unit.field.Value, ...
            'physical_mode', physical_mode.field.Value, ...
            'regular_step', regular_step.field.Value, ...
            'confirmed_gaps', confirmed_gaps.field.Value, ...
            'foil_thickness', foil_thickness.field.Value);
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
    function update_physical_mode()
        use_regular = strcmp(physical_mode.field.Value, 'Regular gap step');
        set_input_state(regular_step, use_regular);
        set_input_state(confirmed_gaps, ~use_regular);
        if use_regular
            physical_entries.RowHeight = {76, 0};
        else
            physical_entries.RowHeight = {0, 76};
        end
    end
    function update_study_mode()
        use_advanced = strcmp(study_mode.field.Value, ...
            'Advanced - starting variation known');
        set_input_state(variation_guess, use_advanced);
        row_heights = gl.RowHeight;
        if use_advanced
            row_heights{5} = 62;
        else
            row_heights{5} = 0;
        end
        gl.RowHeight = row_heights;
    end
    function cancelTest()
        store.parsed = [];
        uiresume(fig);
    end
end

function controls = add_text_input(parent, row, question, explanation, ...
        tag, help_tag, value)
    group = uigridlayout(parent, [2 2]);
    group.Layout.Row = row;
    group.RowHeight = {23, '1x'};
    group.ColumnWidth = {'1x', 218};
    group.Padding = [0 0 0 0];
    group.RowSpacing = 1;
    group.ColumnSpacing = 18;
    controls.label = uilabel(group, 'Text', question, 'FontSize', 14, ...
        'FontWeight', 'bold', 'FontColor', [0.12 0.20 0.24], ...
        'Tag', [tag '_label']);
    controls.label.Layout.Row = 1;
    controls.label.Layout.Column = 1;
    controls.help = uilabel(group, 'Text', explanation, 'FontSize', 11, ...
        'FontColor', [0.34 0.40 0.43], 'WordWrap', 'on', ...
        'VerticalAlignment', 'top', 'Tag', help_tag);
    controls.help.Layout.Row = 2;
    controls.help.Layout.Column = 1;
    controls.field = uieditfield(group, 'text', 'Value', value, ...
        'FontSize', 15, 'Tag', tag);
    controls.field.Layout.Row = [1 2];
    controls.field.Layout.Column = 2;
end

function controls = add_dropdown_input(parent, row, question, explanation, ...
        tag, help_tag, items, value)
    group = uigridlayout(parent, [2 2]);
    group.Layout.Row = row;
    group.RowHeight = {25, '1x'};
    group.ColumnWidth = {'1x', 218};
    group.Padding = [0 0 0 0];
    group.RowSpacing = 1;
    group.ColumnSpacing = 18;
    controls.label = uilabel(group, 'Text', question, 'FontSize', 15, ...
        'FontWeight', 'bold', 'FontColor', [0.12 0.20 0.24], ...
        'Tag', [tag '_label']);
    controls.label.Layout.Row = 1;
    controls.label.Layout.Column = 1;
    controls.help = uilabel(group, 'Text', explanation, 'FontSize', 11, ...
        'FontColor', [0.34 0.40 0.43], 'WordWrap', 'on', ...
        'VerticalAlignment', 'top', 'Tag', help_tag);
    controls.help.Layout.Row = 2;
    controls.help.Layout.Column = 1;
    controls.field = uidropdown(group, 'Items', items, 'Value', value, ...
        'FontSize', 14, 'Tag', tag);
    controls.field.Layout.Row = [1 2];
    controls.field.Layout.Column = 2;
end

function set_input_state(controls, is_active)
    if is_active
        visible = 'on';
        enabled = 'on';
    else
        visible = 'off';
        enabled = 'off';
    end
    controls.label.Visible = visible;
    controls.help.Visible = visible;
    controls.field.Visible = visible;
    controls.field.Enable = enabled;
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
            'The calculated values were printed in the MATLAB Command Window. ' ...
            'Keep this session open and record the reason below.\n\n' ...
            'Reason: %s'], result_error.message);
        uialert(notice, message, 'Results not shown', 'Icon', 'warning', ...
            'CloseFcn', @(~, ~) delete_if_valid(notice));
    catch notice_error
        warning('run_test_ui:resultNoticeFailed', ...
            'The result notice could not open: %s', notice_error.message);
    end
end

% =================================================================================
function response = gap_popup(level, k, N, reachable_model)
%GAP_POPUP Show one reachable setting and collect its physical result.
    if nargin < 4, reachable_model = []; end
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
        if distance <= reachable_model.comparison_tolerance_mm && ...
                (strcmp(reachable_model.mode, 'list') || ...
                 strcmp(reachable_model.mode, 'combinations'))
            requested_text = sprintf('%s\n%s', requested_text, ...
                char(reachable_model.instructions(recipe_row)));
        end
    end
    l2 = uilabel(gl, 'Text', requested_text, ...
                 'FontSize', 22, 'FontWeight', 'bold', 'WordWrap', 'on', 'HorizontalAlignment', 'center');
    l2.Layout.Row = 2; l2.Layout.Column = [1 2];

    prompt=uilabel(gl,'Text','Enter the measured gap:', ...
        'FontSize',15,'HorizontalAlignment','right');
    prompt.Layout.Row=3; prompt.Layout.Column=1;
    reading_edit=uieditfield(gl,'text','FontSize',16, ...
        'Placeholder','Example: 2.507');
    reading_edit.Layout.Row=3; reading_edit.Layout.Column=2;
    note_text=['Measure this new setup once. That measured gap will be used ' ...
        'in the calculation.'];
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
