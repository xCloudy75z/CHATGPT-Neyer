function h = show_result(result)
%SHOW_RESULT  Decision-first results window: leads with the conclusion, groups and
%   rounds the numbers, adds a plain-English interpretation, shows the fitted curve,
%   and offers an interactive "reliability at a height" tool.
%   MATLAB desktop only (uifigure). In a script, read fields off `result` instead. [addendum POPUP]
    if ~(isdeployed || usejava('desktop'))
        error('show_result:noDisplay', 'show_result needs the MATLAB desktop.');
    end

    % --- unit + a rounding helper -------------------------------------------------
    u = 'mm';
    if isfield(result, 'unit') && ~isempty(result.unit), u = result.unit; end

    has_ov = isfield(result, 'has_overlap') && result.has_overlap;

    % percentages used throughout (with sensible fallbacks)
    if isfield(result, 'tail_fraction') && ~isempty(result.tail_fraction)
        pc = 100 * result.tail_fraction;
    else
        pc = 99.9;
    end
    if isfield(result, 'confidence_level') && ~isempty(result.confidence_level)
        C  = result.confidence_level;
    else
        C  = 0.95;
    end
    cc = 100 * C;

    % --- window + master 2x2 grid -------------------------------------------------
    h  = uifigure('Name', 'Neyer - breaking-height results', 'Position', [100 100 940 640]);
    gl = uigridlayout(h, [2 2]);
    gl.RowHeight    = {'1x', 190};
    gl.ColumnWidth  = {380, '1x'};
    gl.Padding      = [12 12 12 12];
    gl.RowSpacing   = 10;
    gl.ColumnSpacing= 10;

    % =============================================================================
    %  TOP-LEFT (1,1): the answer panel
    % =============================================================================
    pAns = uipanel(gl, 'Title', 'Results', 'FontWeight', 'bold');
    pAns.Layout.Row = 1; pAns.Layout.Column = 1;

    if ~has_ov || ~isfield(result, 'mu') || isempty(result.mu) || isnan(result.mu)
        % --- no result yet: single message, skip the rest -----------------------
        gA = uigridlayout(pAns, [1 1]); gA.Padding = [10 10 10 10];
        uilabel(gA, 'Text', 'No result yet - run more parts.', ...
                'FontSize', 16, 'FontWeight', 'bold', 'WordWrap', 'on');
    else
        mu = result.mu;
        no_fire  = getf(result, 'no_fire',  NaN);
        all_fire = getf(result, 'all_fire', NaN);
        sigma    = getf(result, 'sigma',    NaN);
        mu_lo    = getf(result, 'mu_lo',    NaN);
        mu_hi    = getf(result, 'mu_hi',    NaN);
        n        = getf(result, 'n',        NaN);

        % 9 stacked labels (fixed heights keep the layout predictable)
        gA = uigridlayout(pAns, [9 1]);
        gA.RowHeight   = {34, 24, 24, 8, 20, 20, 20, 'fit', '1x'};
        gA.ColumnWidth = {'1x'};
        gA.Padding     = [10 10 10 10];
        gA.RowSpacing  = 4;

        % 1. headline
        uilabel(gA, 'Text', sprintf('Average breaking height:  %.2f %s', mu, u), ...
                'FontSize', 20, 'FontWeight', 'bold', 'WordWrap', 'on');
        % 2. safe (green)
        uilabel(gA, 'Text', sprintf('Safe: ~%.4g%% survive below %.2f %s', pc, no_fire, u), ...
                'FontColor', [0.16 0.44 0.22], 'FontWeight', 'bold');
        % 3. fails (red/clay)
        uilabel(gA, 'Text', sprintf('Fails: ~%.4g%% break above %.2f %s', pc, all_fire, u), ...
                'FontColor', [0.60 0.25 0.20], 'FontWeight', 'bold');
        % 4. thin separator gap
        uilabel(gA, 'Text', '');
        % 5-7. detail labels
        uilabel(gA, 'Text', sprintf('%.4g%% sure the average is %.2f-%.2f %s', cc, mu_lo, mu_hi, u), ...
                'FontSize', 12);
        uilabel(gA, 'Text', sprintf('Spread (how much parts vary): %.2f %s', sigma, u), ...
                'FontSize', 12);
        uilabel(gA, 'Text', sprintf('Based on %d tests', n), 'FontSize', 12);
        % 8. plain-English interpretation
        uilabel(gA, 'Text', sprintf(['In plain terms: the average part breaks around %.2f %s. Parts dropped below about ' ...
            '%.2f %s almost never break (~%.4g%% survive); above about %.2f %s they almost always break ' ...
            '(~%.4g%% break). These edges are less certain than the average.'], ...
            mu, u, no_fire, u, pc, all_fire, u, pc), ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.30 0.30 0.30]);
        % 9. plain-language "How to read the chart" block (no jargon)
        uilabel(gA, 'Text', sprintf(['How to read the chart:\n' ...
            '- The curve shows how likely a part is to break at each height.\n' ...
            '- Its highest point (the peak) is the most common breaking height - the average.\n' ...
            '- The wider the curve, the more parts differ from each other.\n' ...
            '- Below the green line almost no parts break; above the red line almost all do.\n' ...
            '- The up-down axis is relative: taller just means "more parts break around here".']), ...
            'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.20 0.20 0.20]);
    end

    % =============================================================================
    %  TOP-RIGHT (1,2): the chart
    % =============================================================================
    ax = uiaxes(gl);
    ax.Layout.Row = 1; ax.Layout.Column = 2;
    if has_ov && isfield(result, 'mu') && ~isempty(result.mu) && ~isnan(result.mu)
        try
            draw_distribution(ax, result);
        catch
            title(ax, 'Chart unavailable');
        end
    else
        title(ax, 'No result yet');
    end

    % =============================================================================
    %  BOTTOM (2, span both columns): interactive reliability tool
    % =============================================================================
    pRel = uipanel(gl, 'Title', 'Reliability at a height', 'FontWeight', 'bold');
    pRel.Layout.Row = 2; pRel.Layout.Column = [1 2];

    % two rows: a plain-language explainer on top, the controls below
    gRel = uigridlayout(pRel, [2 1]);
    gRel.RowHeight    = {'fit', 'fit'};
    gRel.ColumnWidth  = {'1x'};
    gRel.Padding      = [10 8 10 8];
    gRel.RowSpacing   = 6;

    uilabel(gRel, 'Text', sprintf([ ...
        'Reliability at a height - answer "at THIS drop height, what fraction of parts break (or survive)?"\n' ...
        '  - Type a height and pick break or survive.\n' ...
        '  - Click Calculate.\n' ...
        '  - You get the best estimate plus a confidence-backed floor ' ...
        '(e.g. "95%% confident at least 88%% break").']), ...
        'FontSize', 12, 'WordWrap', 'on', 'FontColor', [0.20 0.20 0.20]);

    gR = uigridlayout(gRel, [1 7]);
    gR.ColumnWidth = {55, 90, 40, 110, 100, 120, '1x'};
    gR.RowHeight   = {'fit'};
    gR.Padding     = [0 4 0 4];
    gR.ColumnSpacing = 8;

    uilabel(gR, 'Text', 'Height:', 'HorizontalAlignment', 'right');

    defVal = 0;
    if isfield(result, 'mu') && ~isempty(result.mu) && ~isnan(result.mu)
        defVal = round(result.mu);
    end
    hEdit = uieditfield(gR, 'numeric', 'Value', defVal);

    uilabel(gR, 'Text', u);

    hDrop = uidropdown(gR, 'Items', {'break', 'survive'});

    hBtn  = uibutton(gR, 'Text', 'Calculate');

    hOut  = uilabel(gR, 'Text', '', 'WordWrap', 'on');

    hSave = uibutton(gR, 'Text', 'Save results...');
    hSave.Layout.Column = 6;
    hOut.Layout.Column  = 7;
    if has_ov && isfield(result, 'levels') && ~isempty(result.levels)
        hSave.ButtonPushedFcn = @(~,~) save_from_window(result, ax, h);
    else
        hSave.Enable = 'off';
    end

    if has_ov && isfield(result, 'levels') && isfield(result, 'successes')
        % capture what the callback needs in a closure
        hBtn.ButtonPushedFcn = @(~, ~) do_reliability(result, u, C, hEdit, hDrop, hOut);
    else
        hBtn.Enable  = 'off';
        hOut.Text    = 'needs a completed run';
    end
end

% =================================================================================
function do_reliability(result, u, C, hEdit, hDrop, hOut)
%DO_RELIABILITY  Button callback: compute the reliability at the entered height.
    try
        x    = hEdit.Value;
        tail = hDrop.Value;
        r    = reliability_at_height(result.levels, result.successes, tail, x, C);
        if isnan(r.bound_percent) || isnan(r.percent)
            hOut.Text = 'No result yet - run more parts.';
            return;
        end
        hOut.Text = sprintf(['At %.2f %s: %.4g%% confident at least %.4g%% of parts %s ' ...
            '(best estimate %.4g%%).'], x, u, 100*C, r.bound_percent, tail, r.percent);
    catch err
        hOut.Text = sprintf('Could not calculate: %s', err.message);
    end
end

% =================================================================================
function v = getf(s, name, dflt)
%GETF  Field value with a default (guards missing/empty fields).
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = dflt;
    end
end

% =================================================================================
function save_from_window(result, ax, parentFig)
%SAVE_FROM_WINDOW  Export the current result to CSV + a self-contained HTML report.
    [f, p] = uiputfile({'*.html','Report + data (HTML/CSV)'}, 'Save results as', ...
                       'drop-test-results.html');
    if isequal(f, 0), return; end
    base = fullfile(p, f);
    img_b64 = '';
    try
        tmp = [tempname '.png'];
        exportgraphics(ax, tmp, 'Resolution', 120);
        fid = fopen(tmp, 'r'); bytes = fread(fid, Inf, '*uint8'); fclose(fid);
        img_b64 = matlab.net.base64encode(bytes);
        delete(tmp);
    catch
        img_b64 = '';   % report still saves, just without the picture
    end
    csv_text  = results_to_csv_text(result);
    html_text = results_to_html(result, img_b64);
    paths = save_results_files(base, csv_text, html_text);
    uialert(parentFig, sprintf('Saved:\n%s\n%s', paths.csv, paths.html), ...
            'Results saved', 'Icon', 'success');
end
