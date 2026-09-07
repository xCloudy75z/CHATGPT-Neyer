function result = run_test_ui(cfg0)
%RUN_TEST_UI  Run a Neyer test through large, readable pop-up windows (MATLAB
%   desktop only): a settings window, then a big Break/Survive window per drop,
%   then the results window. Thin GUI shell over the unchanged engine; input
%   validation lives in parse_run_inputs. In a script use run_test instead. [addendum POPUP]
    if ~(isdeployed || usejava('desktop'))
        error('run_test_ui:noDisplay', ...
              'run_test_ui needs the MATLAB desktop; in a script use run_test instead.');
    end
    parsed = ask_settings_ui();
    if isempty(parsed), fprintf('run_test_ui: cancelled.\n'); result = []; return; end
    if nargin >= 1 && ~isempty(cfg0)
        f = fieldnames(cfg0);
        for i = 1:numel(f), parsed.cfg.(f{i}) = cfg0.(f{i}); end
    end
    try
        result = run_test(parsed.params, parsed.num_parts, @(level,k) drop_popup(level,k,parsed.num_parts), parsed.cfg);
    catch e
        if strcmp(e.identifier, 'run_test_ui:aborted')
            fprintf('run_test_ui: cancelled during testing.\n'); result = []; return;
        end
        rethrow(e);
    end
    try, show_result(result); catch, end
end

% =================================================================================
function parsed = ask_settings_ui()
%ASK_SETTINGS_UI  Large, readable settings window. Returns a parsed struct or [].
    labels = {'Low guess for the average height (mm):', ...
              'High guess for the average height (mm):', ...
              'Rough guess of the spread (mm):', ...
              'Number of parts to test:', ...
              'Rig minimum height (mm; blank = none):', ...
              'Unit for heights (mm / cm / m / km):'};
    defs = {'0.6','1.4','0.10','20','0','mm'};

    fig = uifigure('Name', 'Neyer - your inputs', 'Position', [280 170 600 520]);
    gl  = uigridlayout(fig, [8 2]);
    gl.RowHeight     = {46, 46, 46, 46, 46, 46, 46, 54};
    gl.ColumnWidth   = {'1x', 190};
    gl.Padding       = [28 24 28 24];
    gl.RowSpacing    = 12;
    gl.ColumnSpacing = 16;

    ttl = uilabel(gl, 'Text', 'Enter your test settings', 'FontSize', 20, 'FontWeight', 'bold');
    ttl.Layout.Row = 1; ttl.Layout.Column = [1 2];

    edits = gobjects(1, 6);
    for i = 1:6
        lb = uilabel(gl, 'Text', labels{i}, 'FontSize', 15, 'WordWrap', 'on');
        lb.Layout.Row = i + 1; lb.Layout.Column = 1;
        edits(i) = uieditfield(gl, 'text', 'Value', defs{i}, 'FontSize', 16);
        edits(i).Layout.Row = i + 1; edits(i).Layout.Column = 2;
    end

    bp = uigridlayout(gl, [1 2]);
    bp.Layout.Row = 8; bp.Layout.Column = [1 2];
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
        answers = cell(1, 6);
        for j = 1:6, answers{j} = edits(j).Value; end
        try
            store.parsed = parse_run_inputs(answers);
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

% =================================================================================
function r = drop_popup(level, k, N)
%DROP_POPUP  Large, readable Break/Survive window for one drop. Returns logical.
    fig = uifigure('Name', 'Neyer drop test', 'Position', [330 240 500 300]);
    gl  = uigridlayout(fig, [3 2]);
    gl.RowHeight     = {'fit', '1x', 64};
    gl.ColumnWidth   = {'1x', '1x'};
    gl.Padding       = [30 24 30 24];
    gl.RowSpacing    = 16;
    gl.ColumnSpacing = 16;

    l1 = uilabel(gl, 'Text', sprintf('Test %d of %d', k, N), ...
                 'FontSize', 16, 'FontColor', [0.38 0.38 0.38], 'HorizontalAlignment', 'center');
    l1.Layout.Row = 1; l1.Layout.Column = [1 2];
    l2 = uilabel(gl, 'Text', sprintf('Set the height to %.2f mm.\nDid the part break?', level), ...
                 'FontSize', 22, 'FontWeight', 'bold', 'WordWrap', 'on', 'HorizontalAlignment', 'center');
    l2.Layout.Row = 2; l2.Layout.Column = [1 2];

    store = struct('v', []);
    bB = uibutton(gl, 'Text', 'Break', 'FontSize', 19, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.80 0.45 0.38], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) dropPick(true));
    bB.Layout.Row = 3; bB.Layout.Column = 1;
    bS = uibutton(gl, 'Text', 'Survive', 'FontSize', 19, 'FontWeight', 'bold', ...
                  'BackgroundColor', [0.30 0.55 0.42], 'FontColor', [1 1 1], ...
                  'ButtonPushedFcn', @(~,~) dropPick(false));
    bS.Layout.Row = 3; bS.Layout.Column = 2;

    fig.CloseRequestFcn = @(~,~) dropPick([]);
    uiwait(fig);
    v = store.v;
    if isvalid(fig), delete(fig); end
    if isempty(v), error('run_test_ui:aborted', 'cancelled by operator.'); end
    r = v;

    function dropPick(val)
        store.v = val;
        uiresume(fig);
    end
end
