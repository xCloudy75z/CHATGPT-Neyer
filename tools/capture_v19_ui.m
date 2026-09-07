function capture_v19_ui()
%CAPTURE_V19_UI Save genuine MATLAB screenshots of every operator screen.
    root=fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'application','source'));
    out=fullfile(root,'review-preview','matlab-v19');
    if ~isfolder(out), mkdir(out); end

    close_all_figures();

    neyer_app;
    drawnow;
    menu=find_named_figure('Neyer Gap Test');
    exportapp(menu,fullfile(out,'01-main-menu.png'));
    delete(menu);

    captureState=struct('settings',false,'gap',false);
    watcher=timer('ExecutionMode','fixedSpacing','Period',0.25, ...
        'BusyMode','drop','TimerFcn',@capture_test_flow);
    cleanup=onCleanup(@()stop_and_delete_timer(watcher));
    start(watcher);
    run_test_ui;
    stop(watcher);

    demo=run_demo;
    resultFig=show_result(demo.result);
    drawnow;
    pause(2);
    exportapp(resultFig,fullfile(out,'04-results.png'));
    resultAxes=findall(resultFig,'Type','axes');
    if ~isempty(resultAxes)
        exportgraphics(resultAxes(1),fullfile(out,'04-results-chart.png'),'Resolution',150);
    end
    delete(resultFig);

    show_manual;
    drawnow;
    helpFig=find_named_figure('Neyer Gap Test - Help');
    exportapp(helpFig,fullfile(out,'05-help.png'));
    delete(helpFig);

    marker=fullfile(out,'capture-complete.txt');
    fid=fopen(marker,'w');
    if fid<0, error('capture_v19_ui:marker','Could not write completion marker.'); end
    fprintf(fid,'Five V1.9 MATLAB operator screens captured.\n');
    fclose(fid);

    function capture_test_flow(~,~)
        settings=findall(groot,'Type','figure','Name','Neyer gap test - inputs');
        if ~captureState.settings && ~isempty(settings)
            fig=settings(1);
            drawnow;
            exportapp(fig,fullfile(out,'02-settings.png'));
            fields=findall(fig,'Type','uieditfield');
            rows=arrayfun(@(x)x.Layout.Row,fields);
            [~,order]=sort(rows);
            fields=fields(order);
            values={'0','10','1','20','0','mm','0.10'};
            for j=1:min(numel(fields),numel(values)), fields(j).Value=values{j}; end
            captureState.settings=true;
            invoke_button(find_button(fig,'Start test'));
            return;
        end

        gap=findall(groot,'Type','figure','Name','Neyer gap test');
        if captureState.settings && ~captureState.gap && ~isempty(gap)
            fig=gap(1);
            drawnow;
            exportapp(fig,fullfile(out,'03-test-gap.png'));
            captureState.gap=true;
            feval(fig.CloseRequestFcn,fig,[]);
        end
    end
end

function fig=find_named_figure(name)
    fig=findall(groot,'Type','figure','Name',name);
    if isempty(fig), error('capture_v19_ui:missingFigure','Screen did not open: %s',name); end
    fig=fig(1);
end

function button=find_button(fig,text)
    buttons=findall(fig,'Type','uibutton');
    match=arrayfun(@(b)strcmp(b.Text,text),buttons);
    button=buttons(match);
    if isempty(button), error('capture_v19_ui:missingButton','Button not found: %s',text); end
    button=button(1);
end

function invoke_button(button)
    feval(button.ButtonPushedFcn,button,[]);
end

function stop_and_delete_timer(watcher)
    if isvalid(watcher)
        if strcmp(watcher.Running,'on'), stop(watcher); end
        delete(watcher);
    end
end

function close_all_figures()
    figures=findall(groot,'Type','figure');
    if ~isempty(figures), delete(figures); end
end
