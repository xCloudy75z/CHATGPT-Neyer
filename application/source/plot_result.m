function h = plot_result(result, cfg, savepath)
%PLOT_RESULT  Draw the interaction-probability and transition-gap views.
%
%   h = PLOT_RESULT(result, cfg) draws the bell curve implied by the estimate
%   (result.mu, result.sigma), shades +/-1 spread, marks the all-fire and
%   no-fire levels and their confidence bounds, and returns the figure handle.
%   Opens a new figure each call (repeated calls do not overlay).
%   h = PLOT_RESULT(result, cfg, savepath) also writes a PNG to savepath.
%   Uses only base plotting (works in MATLAB and Octave).  [addendum LR]
    if nargin < 2 || isempty(cfg), cfg = neyer_settings(); end   % cfg reserved for future styling; not used yet
    if ~result.has_overlap || isnan(result.mu)
        error('plot_result:noResult', 'No result to plot (results have not overlapped).');
    end

    h  = figure('Position',[100 100 1000 850]);
    layout=tiledlayout(h,2,1,'TileSpacing','compact','Padding','compact');
    probabilityAxes=nexttile(layout,1);
    draw_interaction_curve(probabilityAxes,result,cfg);
    distributionAxes=nexttile(layout,2);
    draw_distribution(distributionAxes,result,cfg);

    if nargin >= 3 && ~isempty(savepath)
        print(h, savepath, '-dpng');
    end
end
