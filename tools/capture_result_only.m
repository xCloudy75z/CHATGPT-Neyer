root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'application','source'));
out=fullfile(root,'review-preview','matlab-v19');
demo=run_demo;
fig=show_result(demo.result);
drawnow;
pause(2);
exportapp(fig,fullfile(out,'04-results.png'));
axesFound=findall(fig,'Type','axes');
if ~isempty(axesFound)
    exportgraphics(axesFound(1),fullfile(out,'04-results-chart.png'),'Resolution',150);
end
delete(fig);
fid=fopen(fullfile(out,'result-capture-complete.txt'),'w');
fprintf(fid,'Corrected result screen captured.\n');
fclose(fid);
exit;
