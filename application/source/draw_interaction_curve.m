function draw_interaction_curve(ax,result,cfg)
%DRAW_INTERACTION_CURVE Show how interaction probability falls as gap grows.
    if nargin<3 || isempty(cfg), cfg=neyer_settings(); end
    u='mm';
    if isfield(result,'unit') && ~isempty(result.unit), u=result.unit; end

    x=linspace(cfg.min_level,cfg.max_level,500);
    p=shape_model(x,result.mu,result.sigma).p;
    gold=[0.66 0.51 0.23];
    yesColor=[0.74 0.37 0.20];
    noColor=[0.18 0.44 0.42];

    plot(ax,x,100*p,'Color',gold,'LineWidth',2.5);
    hold(ax,'on');
    yes=result.successes(:);
    levels=result.levels(:);
    plot(ax,levels(yes),97*ones(sum(yes),1),'o', ...
        'MarkerFaceColor',yesColor,'MarkerEdgeColor','none','MarkerSize',6);
    plot(ax,levels(~yes),3*ones(sum(~yes),1),'o', ...
        'MarkerFaceColor',noColor,'MarkerEdgeColor','none','MarkerSize',6);

    edge_line(ax,result.high_interaction_gap,yesColor,'99.9% interaction');
    edge_line(ax,result.mu,gold,'middle gap - 50%');
    edge_line(ax,result.negligible_interaction_gap,noColor,'99.9% no interaction');

    xlim(ax,[cfg.min_level cfg.max_level]);
    ylim(ax,[0 100]);
    yticks(ax,[0 50 100]);
    yticklabels(ax,{'0%','50%','100%'});
    grid(ax,'on');
    xlabel(ax,sprintf('gap (%s)',u));
    ylabel(ax,'chance of interaction');
    title(ax,'Interaction becomes less likely as the gap increases');
    hold(ax,'off');
end

function edge_line(ax,x,color,label)
    if ~isfinite(x), return; end
    line(ax,[x x],[0 100],'Color',color,'LineStyle','--','LineWidth',1);
    text(ax,x,54,label,'Color',color,'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize',9);
end
