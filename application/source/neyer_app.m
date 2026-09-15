function neyer_app()
%NEYER_APP Launch the focused V1.14 Neyer gap-study tool.
% Legacy internal names remain: break = Interaction; survive = No interaction.
% [compiled-app]

fig = uifigure('Name', 'Neyer Gap Test V1.14', ...
    'Position', [300 190 500 390], 'Color', [247 249 250] / 255);
layout = uigridlayout(fig, [5 1]);
layout.RowHeight = {52, 62, 64, 56, 56};
layout.Padding = [28 22 28 24];
layout.RowSpacing = 12;

uilabel(layout, 'Text', 'Neyer Gap Test V1.14', 'FontSize', 21, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'left', ...
    'FontColor', [33 49 58] / 255);
uilabel(layout, 'Text', [ ...
    'Build the response curve first. Fixed-gap reliability planning is a ' ...
    'separate later study.'], 'FontSize', 13, 'FontWeight', 'bold', ...
    'FontColor', [35 108 142] / 255, 'WordWrap', 'on');
uibutton(layout, 'Text', 'Start a Gap Study', 'FontSize', 17, ...
    'FontWeight', 'bold', 'BackgroundColor', [47 125 109] / 255, ...
    'FontColor', [1 1 1], 'ButtonPushedFcn', @onRunTest);
uibutton(layout, 'Text', 'Run the Published Example', 'FontSize', 15, ...
    'ButtonPushedFcn', @onDemo);
uibutton(layout, 'Text', 'Help and Definitions', 'FontSize', 15, ...
    'ButtonPushedFcn', @onHelp);

    function onRunTest(~, ~)
        try
            run_test_ui([], []);
        catch err
            uialert(fig, err.message, 'Something went wrong');
        end
    end

    function onDemo(~, ~)
        try
            example = run_demo();
            show_result(example.result);
            if example.is_match
                uialert(fig, sprintf([ ...
                    'Self-check passed.\n\nExpected middle gap 5.3922 mm ' ...
                    'and overall variation 1.0412 mm.\nGot %.4f mm and %.4f mm.'], ...
                    example.got_mu, example.got_sigma), ...
                    'Published example matched', 'Icon', 'success');
            else
                uialert(fig, sprintf([ ...
                    'Self-check did not match.\n\nExpected 5.3922 mm and ' ...
                    '1.0412 mm; got %.4f mm and %.4f mm.\nDo not use this build.'], ...
                    example.got_mu, example.got_sigma), ...
                    'Published example failed', 'Icon', 'error');
            end
        catch err
            uialert(fig, err.message, 'Published example could not run');
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
