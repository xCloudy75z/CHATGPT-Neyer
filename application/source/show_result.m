function h = show_result(result)
%SHOW_RESULT Present either an unfinished status or a calculated result.

    if ~(isdeployed || usejava('desktop'))
        error('show_result:noDisplay', 'The results window needs the MATLAB desktop.');
    end

    unit = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit)
        unit = char(string(result.unit));
    end
    has_estimate = isfield(result, 'has_overlap') && result.has_overlap && ...
        isfield(result, 'mu') && isfinite(result.mu);
    if ~has_estimate
        h = show_unfinished_result(result);
        return;
    end

    confidence = 0.95;
    if isfield(result, 'confidence_level') && isfinite(result.confidence_level)
        confidence = result.confidence_level;
    end

    h = show_calculated_result(result, unit, confidence);
end

function h = show_unfinished_result(result)
    h = uifigure('Name', 'Neyer gap-study results', ...
        'Position', [240 120 760 520], 'Color', [0.96 0.97 0.97]);
    layout = uigridlayout(h, [1 1]);
    layout.Padding = [18 18 18 18];

    statusPanel = uipanel(layout, 'Title', 'Result not calculated yet', ...
        'FontWeight', 'bold', 'BackgroundColor', [1.00 0.97 0.90]);
    statusLayout = uigridlayout(statusPanel, [7 1]);
    statusLayout.RowHeight = {66, 58, 38, 38, 38, 78, 42};
    statusLayout.Padding = [22 18 22 20];
    statusLayout.RowSpacing = 8;

    uilabel(statusLayout, 'Text', [ ...
        'The middle gap and overall variation cannot yet be calculated ' ...
        'from these completed tests.'], 'FontSize', 20, ...
        'FontWeight', 'bold', 'WordWrap', 'on', ...
        'FontColor', [0.52 0.31 0.06]);
    uilabel(statusLayout, 'Text', [ ...
        'A calculated result needs Interaction and No interaction results ' ...
        'close enough to show the change. No substitute answer is shown.'], ...
        'FontSize', 13, 'WordWrap', 'on', ...
        'FontColor', [0.20 0.24 0.26]);

    [completedCount, interactionCount, noInteractionCount] = ...
        completed_outcome_counts(result);
    uilabel(statusLayout, 'Text', sprintf('Completed tests: %d', ...
        completedCount), 'FontSize', 15, 'FontWeight', 'bold');
    uilabel(statusLayout, 'Text', sprintf('Interaction observed: %s (%d)', ...
        observed_word(interactionCount), interactionCount), 'FontSize', 14);
    uilabel(statusLayout, 'Text', sprintf( ...
        'No interaction observed: %s (%d)', ...
        observed_word(noInteractionCount), noInteractionCount), 'FontSize', 14);

    saveAvailable = result_save_available(result);
    if saveAvailable
        nextAction = [ ...
            'Next action: save the completed results, then review the ' ...
            'tested gaps before deciding whether another useful test can be run.'];
    else
        nextAction = [ ...
            'Next action: return to the test and record at least one ' ...
            'completed outcome.'];
    end
    uilabel(statusLayout, 'Text', nextAction, 'FontSize', 14, ...
        'FontWeight', 'bold', 'WordWrap', 'on', ...
        'FontColor', [0.18 0.22 0.24]);

    saveButton = uibutton(statusLayout, 'Text', 'Save results...');
    if saveAvailable
        saveButton.ButtonPushedFcn = @(~, ~) save_from_window(result, h);
    else
        saveButton.Enable = 'off';
    end
end

function [completedCount, interactionCount, noInteractionCount] = ...
        completed_outcome_counts(result)
    completedCount = 0;
    interactionCount = 0;
    noInteractionCount = 0;
    if ~isfield(result, 'successes') || isempty(result.successes)
        return;
    end
    outcomes = logical(result.successes(:));
    completedCount = numel(outcomes);
    interactionCount = sum(outcomes);
    noInteractionCount = completedCount - interactionCount;
end

function word = observed_word(count)
    if count > 0
        word = 'Yes';
    else
        word = 'No';
    end
end

function h = show_calculated_result(result, unit, confidence)
    h = uifigure('Name', 'Neyer gap-study results', ...
        'Position', [60 50 1240 760], 'Color', [0.96 0.97 0.97]);
    layout = uigridlayout(h, [3 3]);
    layout.RowHeight = {105, '1x', 130};
    layout.ColumnWidth = {340, '1x', '1x'};
    layout.Padding = [14 14 14 14];
    layout.RowSpacing = 10;
    layout.ColumnSpacing = 10;

    summaryPanel = uipanel(layout, 'Title', 'Gap-study summary', ...
        'FontWeight', 'bold', 'BackgroundColor', [0.91 0.97 0.96]);
    summaryPanel.Layout.Row = 1;
    summaryPanel.Layout.Column = [1 3];
    [completedCount, interactionCount, noInteractionCount] = ...
        completed_outcome_counts(result);
    summaryLayout = uigridlayout(summaryPanel, [2 1]);
    summaryLayout.RowHeight = {34, '1x'};
    summaryLayout.Padding = [12 4 12 8];
    uilabel(summaryLayout, 'Text', sprintf([ ...
        '%d completed tests: %d Interaction, %d No interaction'], ...
        completedCount, interactionCount, noInteractionCount), ...
        'FontSize', 18, 'FontWeight', 'bold', ...
        'FontColor', [0.10 0.38 0.32]);
    uilabel(summaryLayout, 'Text', [ ...
        'The fitted curve describes this changing-gap study. It is not a ' ...
        'fixed-gap reliability qualification.'], 'FontSize', 12, ...
        'WordWrap', 'on', 'FontColor', [0.18 0.22 0.24]);

    factsPanel = uipanel(layout, 'Title', 'Estimated middle and variation', ...
        'FontWeight', 'bold');
    factsPanel.Layout.Row = 2;
    factsPanel.Layout.Column = 1;
    gA = uigridlayout(factsPanel, [10 1]);
    gA.RowHeight   = {54, 24, 30, 42, 30, 56, 62, 62, '1x', 4};
    gA.Padding = [10 10 10 8];
    gA.RowSpacing = 3;
    uilabel(gA, 'Text', sprintf( ...
        'Middle gap (about 50%% interaction): %.2f %s', result.mu, unit), ...
        'FontSize', 17, 'FontWeight', 'bold', 'WordWrap', 'on');
    uilabel(gA, 'Text', 'How certain is this estimate?', ...
        'FontSize', 12, 'FontWeight', 'bold', ...
        'FontColor', [0.20 0.35 0.42]);
    uilabel(gA, 'Text', format_confidence_range(confidence, ...
        result.mu_lo, result.mu_hi, unit), ...
        'FontSize', 12, 'WordWrap', 'on');
    uilabel(gA, 'Text', sprintf('Overall variation: %.2f %s', ...
        result.sigma, unit), 'FontSize', 16, 'FontWeight', 'bold');
    uilabel(gA, 'Text', format_confidence_range(confidence, ...
        result.sigma_lo, result.sigma_hi, unit), ...
        'FontSize', 12, 'WordWrap', 'on');
    uilabel(gA, 'Text', [ ...
        'Overall variation describes how much the entire tested process ' ...
        'varies from article to article around the middle gap.'], ...
        'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.25 0.30 0.32]);
    uilabel(gA, 'Text', [ ...
        'The middle gap is a 50/50 estimate. It is not a fixed-gap ' ...
        'reliability claim.'], ...
        'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.52 0.31 0.06]);
    uilabel(gA, 'Text', [ ...
        'This 95% view describes uncertainty in the fitted estimate. It was ' ...
        'not entered as a reliability requirement.'], ...
        'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.25 0.30 0.32]);
    uilabel(gA, 'Text', sprintf([ ...
        'Direction: smaller gaps make Interaction more likely; larger ' ...
        'gaps make No interaction more likely. Based on %d tests.'], ...
        result.n), 'FontSize', 12, 'WordWrap', 'on');
    uilabel(gA, 'Text', '');

    distributionAxes = uiaxes(layout);
    distributionAxes.Layout.Row = 2;
    distributionAxes.Layout.Column = 2;
    probabilityAxes = uiaxes(layout);
    probabilityAxes.Layout.Row = 2;
    probabilityAxes.Layout.Column = 3;
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

    calculatorPanel = uipanel(layout, 'Title', ...
        'Chance of an outcome at one physical gap', 'FontWeight', 'bold');
    calculatorPanel.Layout.Row = 3;
    calculatorPanel.Layout.Column = [1 3];
    calculatorLayout = uigridlayout(calculatorPanel, [2 1]);
    calculatorLayout.RowHeight = {'fit', 'fit'};
    calculatorLayout.Padding = [10 8 10 8];
    calculatorLayout.RowSpacing = 8;
    uilabel(calculatorLayout, 'Text', [ ...
        'Enter one gap to read the fitted curve at that point. This is an ' ...
        'estimate from the changing-gap study, not a separate qualification. ' ...
        'The screen shows the best estimated chance and the ' ...
        'cautious minimum supported by the data.'], ...
        'FontSize', 12, 'WordWrap', 'on');

    controls = uigridlayout(calculatorLayout, [1 7]);
    controls.ColumnWidth = {55, 90, 40, 125, 100, 120, '1x'};
    controls.Padding = [0 4 0 4];
    controls.ColumnSpacing = 8;
    uilabel(controls, 'Text', 'Gap:', 'HorizontalAlignment', 'right');
    gapEdit = uieditfield(controls, 'numeric', ...
        'Value', round(result.mu, 2));
    uilabel(controls, 'Text', unit);
    outcomeDrop = uidropdown(controls, ...
        'Items', {'Interaction', 'No interaction'});
    calculateButton = uibutton(controls, 'Text', 'Calculate');
    saveButton = uibutton(controls, 'Text', 'Save results...');
    outputLabel = uilabel(controls, 'Text', '', 'WordWrap', 'on');
    saveButton.Layout.Column = 6;
    outputLabel.Layout.Column = 7;

    calculateButton.ButtonPushedFcn = @(~, ~) calculate_probability( ...
        result, unit, confidence, gapEdit, outcomeDrop, outputLabel);
    if result_save_available(result)
        saveButton.ButtonPushedFcn = @(~, ~) save_from_window(result, h);
    else
        saveButton.Enable = 'off';
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
            'At %.2f %s: best estimated chance %.4g%%; ' ...
            'cautious minimum supported by the data %.4g%% at %.4g%% confidence.'], ...
            gap, unit, ...
            answer.percent, cautious, 100 * confidence);
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
