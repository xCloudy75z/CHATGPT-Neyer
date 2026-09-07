function draw_distribution(ax, result)
%DRAW_DISTRIBUTION  Draw the fitted bell curve + average line + all-fire/no-fire
%   markers into a given axes handle `ax`. Base plotting only (works for a normal
%   figure axes and a uiaxes). Shared by plot_result and show_result. [addendum POPUP]
    u = 'mm'; if isfield(result,'unit') && ~isempty(result.unit), u = result.unit; end
    mu = result.mu; sigma = result.sigma;
    % percentage that survives-below / breaks-above the thresholds (for callouts)
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
    text(ax, mu, 1.04*ymax, sprintf('average %.2f %s', mu, u), ...
        'Color', gold, 'FontWeight', 'bold', 'FontSize', 14, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    % --- (2) label the +/-1 spread band, lifted clearly above the relocated CI bracket
    text(ax, mu, 0.46*ymax, 'middle ~68% of parts (\pm1 spread)', ...
        'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.45 0.42 0.36]);

    % --- markers for all-fire / no-fire thresholds
    plot(ax, result.all_fire, 0, 'v', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
    plot(ax, result.no_fire,  0, 'v', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);

    % --- (4) threshold dashed lines (make the triangle markers into clear lines)
    if isfield(result, 'no_fire') && isfinite(result.no_fire)
        line(ax, [result.no_fire result.no_fire], [0 0.15*ymax], ...
            'Color', teal, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    if isfield(result, 'all_fire') && isfinite(result.all_fire)
        line(ax, [result.all_fire result.all_fire], [0 0.15*ymax], ...
            'Color', clay, 'LineStyle', '--', 'LineWidth', 1.2);
    end
    % --- (4) clear filled baseline dots + readable multi-line callouts with leaders
    if isfield(result, 'no_fire') && isfinite(result.no_fire)
        yCall = 0.30*ymax;
        plot(ax, result.no_fire, 0, 'o', 'MarkerFaceColor', teal, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [result.no_fire result.no_fire], [0 yCall], 'Color', teal, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, result.no_fire, yCall, ...
            sprintf('no-fire %.2f %s\n%.4g%% survive below here', result.no_fire, u, pc), ...
            'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', teal);
    end
    if isfield(result, 'all_fire') && isfinite(result.all_fire)
        yCall = 0.30*ymax;
        plot(ax, result.all_fire, 0, 'o', 'MarkerFaceColor', clay, 'MarkerEdgeColor','none','MarkerSize',9);
        line(ax, [result.all_fire result.all_fire], [0 yCall], 'Color', clay, 'LineStyle', ':', 'LineWidth', 1);
        text(ax, result.all_fire, yCall, ...
            sprintf('all-fire %.2f %s\n%.4g%% break above here', result.all_fire, u, pc), ...
            'HorizontalAlignment','left', 'VerticalAlignment','bottom', ...
            'FontSize', 13, 'Color', clay);
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
        text(ax, mu, 0.18*ymax, sprintf('95%% sure the average is %.2f-%.2f %s', mu_lo, mu_hi, u), ...
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
    nf = result.no_fire; af = result.all_fire;
    if isfinite(nf) && isfinite(af)
        strip_patch(ax, xlo, nf, ys, y0, green);
        strip_patch(ax, nf,  af, ys, y0, amber);
        strip_patch(ax, af,  xhi, ys, y0, reddy);
        text(ax, (xlo+nf)/2, ys/2, 'safe',     'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.20 0.40 0.22]);
        text(ax, (nf+af)/2,  ys/2, 'expected', 'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.55 0.45 0.15]);
        text(ax, (af+xhi)/2, ys/2, 'fails',    'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',13,'Color',[0.60 0.25 0.20]);
    end

    % --- (7) axis labels + title (enlarged text)
    xlabel(ax, sprintf('drop height (%s)', u), 'FontSize', 14);
    ylabel(ax, {'how often parts break', 'at each height (taller = more)'}, 'FontSize', 14);
    title(ax, sprintf('Fitted distribution:  average %.2f,  spread %.2f', mu, sigma), ...
        'FontSize', 15, 'FontWeight', 'bold');

    % ensure the y-lower-limit includes the strip and headroom for the raised average label
    set(ax, 'YLim', [ys*1.2 1.30*ymax]);
    set(ax, 'XLim', [xlo xhi]);

    % --- (6) legend naming the four key elements (unobtrusive)
    try
        if isempty(hCI)
            legend(ax, [hCurve hMean hBand], ...
                {'fitted spread of breaking heights', 'average', 'middle ~68% (\pm1 spread)'}, ...
                'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
        else
            legend(ax, [hCurve hMean hBand hCI], ...
                {'fitted spread of breaking heights', 'average', 'middle ~68% (\pm1 spread)', '95% range for the average'}, ...
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
