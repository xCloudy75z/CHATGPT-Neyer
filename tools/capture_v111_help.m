project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root,'application','source'));
output_path = fullfile(project_root,'assets','screenshots', ...
    'v112-07-help.png');

show_manual();
drawnow;
pause(1);
help_figure = findall(groot,'Type','figure','Name','Neyer Gap Test - Help');
assert(numel(help_figure) == 1,'The V1.12 Help screen did not open.');
exportapp(help_figure,output_path);
delete(help_figure);
exit(0);
