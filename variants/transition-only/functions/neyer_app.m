function neyer_app()
%NEYER_APP  Launch menu for the D-Optimal Sensitivity Tool (the compiled app's
%   entry point). Five grouped buttons over the unchanged engine. [compiled-app]
    if ~isdeployed
    end

    state.result = [];      % most recent run, for the Reliability button

    fig = uifigure('Name', 'D-Optimal Sensitivity Tool', 'Position', [300 250 400 360]);
    gl = uigridlayout(fig, [7 1]);
    gl.RowHeight  = {36, 42, 42, 42, 10, 42, 42};
    gl.Padding    = [22 16 22 16];
    gl.RowSpacing = 8;

    title = uilabel(gl, 'Text', 'D-Optimal Sensitivity Tool', 'FontSize', 16, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    title.Layout.Row = 1;

    uibutton(gl, 'Text', 'Pre-Test Planner',      'ButtonPushedFcn', @onPlanner);
    uibutton(gl, 'Text', 'Run a Test',            'ButtonPushedFcn', @onRunTest);
    uibutton(gl, 'Text', 'Reliability Calculator','ButtonPushedFcn', @onReliability);
    uilabel(gl,  'Text', '');   % row 5: separator gap
    uibutton(gl, 'Text', 'Run a Demo (verify)',   'ButtonPushedFcn', @onDemo);
    uibutton(gl, 'Text', 'Help',                  'ButtonPushedFcn', @onHelp);

    % ---- callbacks (nested: share `state` and `fig`) ------------------------
    function onRunTest(~, ~)
        try
            res = run_test_ui();
            if ~isempty(res), state.result = res; end
        catch err
            uialert(fig, err.message, 'Something went wrong');
        end
    end

    function onDemo(~, ~)
        try
            d = run_demo();
            state.result = d.result;
            show_result(d.result);
            if d.is_match
                uialert(fig, sprintf(['Self-check PASSED.\n\nExpected average 5.3922, spread 1.0412.\n' ...
                    'Got %.4f / %.4f.  MATCH.'], d.got_mu, d.got_sigma), ...
                    'Demo verified', 'Icon', 'success');
            else
                uialert(fig, sprintf(['Self-check MISMATCH.\n\nExpected 5.3922 / 1.0412, got %.4f / %.4f.\n' ...
                    'Do not trust this build.'], d.got_mu, d.got_sigma), ...
                    'Demo FAILED', 'Icon', 'error');
            end
        catch err
            uialert(fig, err.message, 'Demo could not run');
        end
    end

    function onPlanner(~, ~)
        try
            a = inputdlg({'Low guess for the average height:', 'High guess for the average height:', ...
                          'Reliability you want (e.g. 0.999):', 'Confidence (e.g. 0.95):', 'Unit:'}, ...
                         'Pre-Test Planner', 1, {'0.6','1.4','0.999','0.95','mm'});
            if isempty(a), return; end
            params = struct('avg_low', str2double(a{1}), 'avg_high', str2double(a{2}));
            pr = plan_prep_numbers(params, str2double(a{3}), str2double(a{4}));
            uialert(fig, plan_prep_message(pr, a{5}), 'Pre-Test Plan', 'Icon', 'info');
        catch err
            uialert(fig, err.message, 'Please check your inputs');
        end
    end

    function onReliability(~, ~)
        if isempty(state.result)
            uialert(fig, 'Run a test first, then this opens its results and reliability tool.', ...
                    'No test yet', 'Icon', 'info');
            return;
        end
        try, show_result(state.result); catch err, uialert(fig, err.message, 'Could not open'); end
    end

    function onHelp(~, ~)
        try, show_manual(); catch err, uialert(fig, err.message, 'Help unavailable'); end
    end
end
