root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'application','source'));
demo=run_demo;
fig=show_result(demo.result);
drawnow;
axesFound=findall(fig,'Type','axes');
fprintf('UI axes found: %d\n',numel(axesFound));
for k=1:numel(axesFound)
    fprintf('Axis %d title: %s\n',k,string(axesFound(k).Title.String));
    fprintf('Axis %d children: %d\n',k,numel(axesFound(k).Children));
end
pause(1);
delete(fig);
exit;
