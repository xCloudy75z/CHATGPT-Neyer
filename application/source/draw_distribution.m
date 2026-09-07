function draw_distribution(ax, result, cfg)
%DRAW_DISTRIBUTION  Draw the fitted distribution of critical interaction gaps.
%   markers into a given axes handle `ax`. Base plotting only (works for a normal
%   figure axes and a uiaxes). Shared by plot_result and show_result. [addendum POPUP]
    if nargin<3 || isempty(cfg), cfg=neyer_settings(); end
    u = 'mm'; if isfield(result,'unit') && ~isempty(result.unit), u = result.unit; end
    mu = result.mu; sigma = result.sigma;
    % percentage attached to the high/negligible interaction edge gaps
    if isfield(result,'tail_fraction') && ~isempty(result.tail_fraction) && isfinite(result.tail_fraction)
        pc = 100 * result.tail_fraction;
    else
        pc = 99.9;
    end
    x   = linspace(mu - 4.5*sigma, mu + 4.5*sigma, 400);
    pdf = shape_model(x, mu, sigma).phi ./ sigma;
    plot(ax, x, pdf, '-', 'Color', [0.10 0.16 0.19], 'LineWidth', 2); hold(ax, 'on');
    % shade +/- 1 spread, then redraw the curve on top of the shade
    xin = x(x >= mu-sigma & x <= mu+sigma);
    pin = shape_model(xin, mu, sigma).phi ./ sigma;
    hBand = area(ax, xin, pin, 'FaceColor', [0.945 0.914 0.847], 'EdgeColor', 'none');
    hCurve = plot(ax, x, pdf, '-', 'Color', [0.10 0.16 0.19], 'LineWidth', 2);
    ymax = max(pdf);
    hMean = line(ax, [mu mu], [0 ymax], 'Color', [0.66 0.51 0.23], 'LineWidth', 1.5);

    % colours reused below
    teal = [0.18 0.44 0.42];
    clay = [0.74 0.37 0.20];
    gold = [0.66 0.51 0.23];

    % --- (1) label the mean line, clearly ABOVE the apex, in the gold colour
    text(ax, mu, 1.04*ymax, sprintf('middle gap %.2f %s', mu, u), ...
        'Color', gold, 'FontWeight', 'bold', 'FontSize', 14, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % --- (2) label the +/-1 spread band, lifted clearly above the relocated CI bracket
    text(ax, mu, 0.46*ymax, 'middle ~68% of transition gaps (\pm1 width)', ...
        'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.45 0.42 0.36]);

    highGap = result.high_interaction_gap;
    negligibleGap = result.negligible_interaction_gap;
    plot(ax, highGap, 0, 'v', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
    plot(ax, negligibleGap, 0, 'v', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);

    % --- (4) threshold dashed lines (make the triangle markers into clear lines)
    if isfinite(highGap)
        line(ax, [highGap highGap], [0 0.15*ymax], ...
            'Color', clay, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    if isfinite(negligibleGap)
        line(ax, [negligibleGap negligibleGap], [0 0.15*ymax], ...
            'Color', teal, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    % --- (4) clear filled baseline dots + readable multi-line callouts with leaders
    if isfinite(highGap)
        yCall = 0.30*ymax;
        plot(ax, highGap, 0, 'o', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [highGap highGap], [0 yCall], 'Color', clay, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, highGap, yCall, ...
            sprintf('%.4g%% interaction\n%.2f %s', pc, highGap, u), ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', clay);
    end
    if isfinite(negligibleGap)
        yCall = 0.30*ymax;
        plot(ax, negligibleGap, 0, 'o', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [negligibleGap negligibleGap], [0 yCall], 'Color', teal, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, negligibleGap, yCall, ...
            sprintf('negligible interaction\n%.2f %s', negligibleGap, u), ...
            'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', teal);
    end

    % --- (3) 95% CI bracket for the average (SEPARATE from the beige spread band)
    hCI = [];
    mu_lo = NaN; mu_hi = NaN;
    if isfield(result, 'mu_lo'), mu_lo = result.mu_lo; end
    if isfield(result, 'mu_hi'), mu_hi = result.mu_hi; end
    if isfinite(mu_lo) && isfinite(mu_hi)
        yCI = 0.12*ymax;    % low, just above the x-axis (vacates the crowded apex)
        cap = 0.03*ymax;    % end-cap half-height
        hCI = line(ax, [mu_lo mu_hi], [yCI yCI], 'Color', teal, 'LineWidth', 1.5);
        line(ax, [mu_lo mu_lo], [yCI-cap yCI+cap], 'Color', teal, 'LineWidth', 1.5);
        line(ax, [mu_hi mu_hi], [yCI-cap yCI+cap], 'Color', teal, 'LineWidth', 1.5);
        text(ax, mu, 0.18*ymax, sprintf('95%% range for middle gap: %.2f-%.2f %s', mu_lo, mu_hi, u), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 13, 'Color', teal);
    end

    % --- (5) SAFE / Expected / FAIL colour strip just below the baseline
    xl = get(ax, 'XLim');
    if xl(1) >= min(x), xl(1) = min(x); end
    if xl(2) <= max(x), xl(2) = max(x); end
    xlo = xl(1); xhi = xl(2);
    y0 = 0; ys = -0.03*ymax;                % small negative-y sliver
    green = [0.86 0.92 0.86];
    amber = [0.97 0.93 0.80];
    reddy = [0.96 0.86 0.83];
    if isfinite(highGap) && isfinite(negligibleGap)
        strip_patch(ax, xlo, highGap, ys, y0, reddy);
        strip_patch(ax, highGap, negligibleGap, ys, y0, amber);
        strip_patch(ax, negligibleGap, xhi, ys, y0, green);
        text(ax, (xlo+highGap)/2, ys/2, 'high interaction', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',9,'Color',[0.60 0.25 0.20]);
        text(ax, (highGap+negligibleGap)/2, ys/2, 'transition', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',11,'Color',[0.55 0.45 0.15]);
    end

    % --- (7) axis labels + title (enlarged text)
    xlabel(ax, sprintf('gap (%s)', u), 'FontSize', 14);
    ylabel(ax, {'relative distribution', 'of transition gaps'}, 'FontSize', 14);
    title(ax, sprintf('Fitted gap transition:  middle %.2f,  width %.2f', mu, sigma), ...
        'FontSize', 15, 'FontWeight', 'bold');

    % ensure the y-lower-limit includes the strip and headroom for the raised average label
    set(ax, 'YLim', [ys*1.2 1.30*ymax]);
    set(ax, 'XLim', [cfg.min_level cfg.max_level]);

    % --- (6) legend naming the four key elements (unobtrusive)
    try
        if isempty(hCI)
            legend(ax, [hCurve hMean hBand], ...
                {'fitted transition distribution', 'middle gap', 'middle ~68% (\pm1 width)'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        else
            legend(ax, [hCurve hMean hBand hCI], ...
                {'fitted transition distribution', 'middle gap', 'middle ~68% (\pm1 width)', '95% range for middle gap'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        end
    catch
        % legend can be problematic on some uiaxes configs; the labels/text
        % above already name each element, so failing here is non-fatal.
    end

    hold(ax, 'off');
end

function strip_patch(ax, x1, x2, ylo, yhi, col)
%STRIP_PATCH  Draw one coloured band with explicit vertices (works on uiaxes).
    if ~(isfinite(x1) && isfinite(x2)) || x2 <= x1, return; end
    patch(ax, [x1 x2 x2 x1], [ylo ylo yhi yhi], col, 'EdgeColor', 'none');
end
