function neyer_app()
%NEYER_APP  Launch menu for the D-Optimal Sensitivity Tool (the compiled app's
%   entry point). Five grouped buttons over the unchanged engine. [compiled-app]
    if ~isdeployed
    end

    state.result = [];      % most recent run, for the Reliability button
    fig = uifigure('Name', 'Neyer Gap Test', 'Position', [300 160 480 500], ...
        'Color', [247 249 250] / 255);
    gl = uigridlayout(fig, [8 1]);
    gl.RowHeight  = {44, 42, 58, 58, 48, 12, 48, 48};
    gl.Padding    = [26 20 26 20];
    gl.RowSpacing = 10;

    title = uilabel(gl, 'Text', 'Neyer Gap Test', 'FontSize', 20, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
                    'FontColor', [33 49 58] / 255);
    title.Layout.Row = 1;

    guide = uilabel(gl, 'Text', ...
        'Run a Test works independently. The planner is optional and separate.', ...
        'FontSize', 13, 'FontWeight', 'bold', ...
        'FontColor', [35 108 142] / 255);
    guide.Layout.Row = 2;

    uibutton(gl, 'Text', 'Pre-Test Planner (separate)', 'FontSize', 16, ...
        'FontWeight', 'bold', 'BackgroundColor', [35 108 142] / 255, ...
        'FontColor', [1 1 1], 'ButtonPushedFcn', @onPlanner);
    uibutton(gl, 'Text', 'Run a Test', 'FontSize', 16, ...
        'FontWeight', 'bold', 'BackgroundColor', [47 125 109] / 255, ...
        'FontColor', [1 1 1], 'ButtonPushedFcn', @onRunTest);
    uibutton(gl, 'Text', 'Review latest results', 'FontSize', 15, ...
        'ButtonPushedFcn', @onReliability);
    uilabel(gl,  'Text', '');
    uibutton(gl, 'Text', 'Run the published example', 'FontSize', 15, ...
        'ButtonPushedFcn', @onDemo);
    uibutton(gl, 'Text', 'Help and definitions', 'FontSize', 15, ...
        'ButtonPushedFcn', @onHelp);

    % ---- callbacks (nested: share `state` and `fig`) ------------------------
    function onRunTest(~, ~)
        try
            res = run_test_ui([], []);
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
                uialert(fig, sprintf(['Self-check PASSED.\n\nExpected middle gap 5.3922, overall variation 1.0412.\n' ...
                    'Got %.4f / %.4f.  MATCH.'], d.got_mu, d.got_sigma), ...
                    'Demo verified', 'Icon', 'success');
            else
                uialert(fig, sprintf(['Self-check MISMATCH.\n\nExpected middle gap 5.3922 and overall variation 1.0412; got %.4f / %.4f.\n' ...
                    'Do not trust this build.'], d.got_mu, d.got_sigma), ...
                    'Demo FAILED', 'Icon', 'error');
            end
        catch err
            fig.UserData = struct('demo_error_identifier', err.identifier, ...
                'demo_error_message', err.message);
            uialert(fig, err.message, 'Demo could not run');
        end
    end

    function onPlanner(~, ~)
        try
            plan = pretest_planner_ui();
            if ~isempty(plan)
                uialert(fig, sprintf([ ...
                    'The separate plan contains %d main-study articles.\n\n' ...
                    'Direct Run a Test does not use this plan.'], ...
                    plan.main_articles), 'Plan ready', 'Icon', 'success');
            end
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
        try
            show_result(state.result);
        catch err
            uialert(fig, err.message, 'Could not open');
        end
    end

    function onHelp(~, ~)
        try
            show_manual();
        catch err
            uialert(fig, err.message, 'Help unavailable');
        end
    end
end
