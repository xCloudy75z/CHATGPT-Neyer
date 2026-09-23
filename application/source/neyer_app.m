function neyer_app()
%NEYER_APP Launch the focused V1.14 Neyer gap-study tool.
% Legacy internal names remain: break = Interaction; survive = No interaction.
% [compiled-app]

fig = uifigure('Name', 'Neyer Gap Test V1.14', ...
    'Position', [300 220 500 330], 'Color', [247 249 250] / 255);
layout = uigridlayout(fig, [4 1]);
layout.RowHeight = {52, 62, 64, 56};
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
uibutton(layout, 'Text', 'Help and Definitions', 'FontSize', 15, ...
    'ButtonPushedFcn', @onHelp);

    function onRunTest(~, ~)
        try
            run_test_ui([], []);
        catch err
            uialert(fig, err.message, 'Something went wrong');
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
