function h = show_result(result)
%SHOW_RESULT Decision-first results window with two complementary charts.
% The bell-shaped chart explains article-to-article variation. The probability
% chart answers how interaction chance changes as the physical gap changes.

    if ~(isdeployed || usejava('desktop'))
        error('show_result:noDisplay', 'The results window needs the MATLAB desktop.');
    end

    unit = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit)
        unit = char(string(result.unit));
    end
    has_estimate = isfield(result, 'has_overlap') && result.has_overlap && ...
        isfield(result, 'mu') && isfinite(result.mu);
    decision = result_decision_summary(result);

    confidence = 0.95;
    if isfield(result, 'confidence_level') && isfinite(result.confidence_level)
        confidence = result.confidence_level;
    end

    h = uifigure('Name', 'Neyer gap-study results', ...
        'Position', [60 50 1240 760], 'Color', [0.96 0.97 0.97]);
    layout = uigridlayout(h, [3 3]);
    layout.RowHeight = {118, '1x', 190};
    layout.ColumnWidth = {340, '1x', '1x'};
    layout.Padding = [14 14 14 14];
    layout.RowSpacing = 10;
    layout.ColumnSpacing = 10;

    decisionPanel = uipanel(layout, 'Title', 'Decision', 'FontWeight', 'bold');
    decisionPanel.Layout.Row = 1;
    decisionPanel.Layout.Column = [1 3];
    if decision.supported
        decisionPanel.BackgroundColor = [0.91 0.97 0.93];
        decisionTitle = 'Supported operating instruction';
        decisionText = decision.operating_instruction;
        if strlength(decision.physical_build_instruction) > 0
            decisionText = sprintf('%s\nPhysical build: %s', decisionText, ...
                decision.physical_build_instruction);
        end
        decisionColor = [0.10 0.38 0.20];
    else
        decisionPanel.BackgroundColor = [1.00 0.96 0.87];
        decisionTitle = 'Supported operating instruction: Not established';
        decisionText = decision.explanation;
        decisionColor = [0.52 0.31 0.06];
    end
    decisionLayout = uigridlayout(decisionPanel, [2 1]);
    decisionLayout.RowHeight = {32, '1x'};
    decisionLayout.Padding = [12 4 12 8];
    uilabel(decisionLayout, 'Text', decisionTitle, 'FontSize', 19, ...
        'FontWeight', 'bold', 'FontColor', decisionColor);
    uilabel(decisionLayout, 'Text', decisionText, 'FontSize', 12, ...
        'WordWrap', 'on', 'FontColor', [0.18 0.22 0.24]);

    factsPanel = uipanel(layout, 'Title', 'What the fitted result means', ...
        'FontWeight', 'bold');
    factsPanel.Layout.Row = 2;
    factsPanel.Layout.Column = 1;
    if has_estimate
        gA = uigridlayout(factsPanel, [9 1]);
        gA.RowHeight   = {54, 30, 42, 30, 8, 55, 74, '1x', 4};
        gA.Padding = [10 10 10 8];
        gA.RowSpacing = 3;
        uilabel(gA, 'Text', sprintf( ...
            'Middle gap (about 50%% interaction): %.2f %s', result.mu, unit), ...
            'FontSize', 17, 'FontWeight', 'bold', 'WordWrap', 'on');
        uilabel(gA, 'Text', sprintf('%.4g%% confidence range: %.2f to %.2f %s', ...
            100 * confidence, result.mu_lo, result.mu_hi, unit), ...
            'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', sprintf('Overall variation: %.2f %s', ...
            result.sigma, unit), 'FontSize', 16, 'FontWeight', 'bold');
        uilabel(gA, 'Text', sprintf('%.4g%% confidence range: %.2f to %.2f %s', ...
            100 * confidence, result.sigma_lo, result.sigma_hi, unit), ...
            'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', '');
        uilabel(gA, 'Text', [ ...
            'Overall variation describes how much the entire tested process ' ...
            'varies from article to article around the middle gap.'], ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.25 0.30 0.32]);
        uilabel(gA, 'Text', [ ...
            'Important: the middle gap is a 50/50 estimate. It is not the ' ...
            'reliable operating gap shown in the decision above.'], ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.52 0.31 0.06]);
        uilabel(gA, 'Text', sprintf([ ...
            'Direction: smaller gaps make Interaction more likely; larger ' ...
            'gaps make No interaction more likely. Based on %d tests.'], ...
            result.n), 'FontSize', 12, 'WordWrap', 'on');
        uilabel(gA, 'Text', '');
    else
        gA = uigridlayout(factsPanel, [1 1]);
        uilabel(gA, 'Text', [ ...
            'No fitted result yet. Both outcomes must be observed in a useful ' ...
            'region before the middle gap can be estimated.'], ...
            'FontSize', 15, 'FontWeight', 'bold', 'WordWrap', 'on');
    end

    distributionAxes = uiaxes(layout);
    distributionAxes.Layout.Row = 2;
    distributionAxes.Layout.Column = 2;
    probabilityAxes = uiaxes(layout);
    probabilityAxes.Layout.Row = 2;
    probabilityAxes.Layout.Column = 3;
    if has_estimate
        try
            compactSettings = neyer_settings();
            compactSettings.compact = true;
            draw_distribution(distributionAxes, result, compactSettings);
        catch
            title(distributionAxes, 'Variation chart unavailable');
        end
        try
            curveSettings = neyer_settings();
            if isfield(result, 'study_plan') && isstruct(result.study_plan)
                if isfield(result.study_plan, 'minimum_gap_mm')
                    curveSettings.min_level = result.study_plan.minimum_gap_mm;
                end
                if isfield(result.study_plan, 'maximum_gap_mm')
                    curveSettings.max_level = result.study_plan.maximum_gap_mm;
                end
            end
            draw_interaction_curve(probabilityAxes, result, curveSettings);
        catch
            title(probabilityAxes, 'Probability chart unavailable');
        end
    else
        title(distributionAxes, 'No result yet');
        title(probabilityAxes, 'No result yet');
    end

    calculatorPanel = uipanel(layout, 'Title', ...
        'Chance of an outcome at one physical gap', 'FontWeight', 'bold');
    calculatorPanel.Layout.Row = 3;
    calculatorPanel.Layout.Column = [1 3];
    calculatorLayout = uigridlayout(calculatorPanel, [2 1]);
    calculatorLayout.RowHeight = {'fit', 'fit'};
    calculatorLayout.Padding = [10 8 10 8];
    calculatorLayout.RowSpacing = 8;
    uilabel(calculatorLayout, 'Text', [ ...
        'This does not change the planned operating instruction. Enter a gap ' ...
        'to see the best estimated chance and its cautious confidence-backed minimum.'], ...
        'FontSize', 12, 'WordWrap', 'on');

    controls = uigridlayout(calculatorLayout, [1 7]);
    controls.ColumnWidth = {55, 90, 40, 125, 100, 120, '1x'};
    controls.Padding = [0 4 0 4];
    controls.ColumnSpacing = 8;
    uilabel(controls, 'Text', 'Gap:', 'HorizontalAlignment', 'right');
    defaultGap = 0;
    if has_estimate, defaultGap = round(result.mu, 2); end
    gapEdit = uieditfield(controls, 'numeric', 'Value', defaultGap);
    uilabel(controls, 'Text', unit);
    outcomeDrop = uidropdown(controls, ...
        'Items', {'Interaction', 'No interaction'});
    calculateButton = uibutton(controls, 'Text', 'Calculate');
    saveButton = uibutton(controls, 'Text', 'Save results...');
    outputLabel = uilabel(controls, 'Text', '', 'WordWrap', 'on');
    saveButton.Layout.Column = 6;
    outputLabel.Layout.Column = 7;

    if has_estimate && isfield(result, 'levels') && isfield(result, 'successes')
        calculateButton.ButtonPushedFcn = @(~, ~) calculate_probability( ...
            result, unit, confidence, gapEdit, outcomeDrop, outputLabel);
        saveButton.ButtonPushedFcn = @(~, ~) save_from_window(result, h);
    else
        calculateButton.Enable = 'off';
        saveButton.Enable = 'off';
        outputLabel.Text = 'A completed fitted result is needed.';
    end
end

function calculate_probability(result, unit, confidence, gapEdit, outcomeDrop, outputLabel)
    try
        gap = gapEdit.Value;
        if strcmp(outcomeDrop.Value, 'Interaction')
            target = 'interaction';
        else
            target = 'no_interaction';
        end
        answer = reliability_query(result, target, 'probability_at', ...
            gap, confidence);
        if isnan(answer.bound_percent) || isnan(answer.percent)
            outputLabel.Text = 'No estimate yet - more useful test results are needed.';
            return;
        end
        cautious = min(answer.bound_percent, answer.percent);
        outputLabel.Text = sprintf([ ...
            'At %.2f %s: best estimated chance %.4g%%; cautious minimum %.4g%% ' ...
            'at %.4g%% confidence.'], gap, unit, answer.percent, cautious, ...
            100 * confidence);
    catch err
        outputLabel.Text = sprintf('Could not calculate: %s', err.message);
    end
end

function save_from_window(result, parentFigure)
    [fileName, folder] = uiputfile( ...
        {'*.html', 'Report + data (HTML/CSV)'}, 'Save results as', ...
        'gap-study-results.html');
    if isequal(fileName, 0), return; end
    base = fullfile(folder, fileName);
    paths = result_output_paths(base);
    if isfile(paths.csv) || isfile(paths.html)
        uialert(parentFigure, sprintf([ ...
            'Nothing was saved because a result file already exists.\n\n' ...
            'Choose a different name so no earlier result is replaced.\n\n' ...
            'CSV: %s\nHTML: %s'], paths.csv, paths.html), ...
            'Name already in use', 'Icon', 'warning');
        return;
    end
    choice = uiconfirm(parentFigure, sprintf([ ...
        'The app will save these two files:\n\nData: %s\nReport: %s\n\nContinue?'], ...
        paths.csv, paths.html), 'Confirm save location', ...
        'Options', {'Save', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
    if ~strcmp(choice, 'Save'), return; end

    imageText = '';
    imagePath = [tempname '.png'];
    try
        exportapp(parentFigure, imagePath);
        fileId = fopen(imagePath, 'r');
        cleanupFile = onCleanup(@() close_and_delete(fileId, imagePath)); %#ok<NASGU>
        imageBytes = fread(fileId, Inf, '*uint8');
        imageText = matlab.net.base64encode(imageBytes);
    catch
        if isfile(imagePath), delete(imagePath); end
    end

    try
        savedPaths = save_results_files(base, results_to_csv_text(result), ...
            results_to_html(result, imageText));
        uialert(parentFigure, sprintf('Saved:\n%s\n%s', ...
            savedPaths.csv, savedPaths.html), 'Results saved', 'Icon', 'success');
    catch err
        uialert(parentFigure, err.message, 'Results not saved', 'Icon', 'error');
    end
end

function close_and_delete(fileId, imagePath)
    if fileId >= 0, fclose(fileId); end
    if isfile(imagePath), delete(imagePath); end
end
