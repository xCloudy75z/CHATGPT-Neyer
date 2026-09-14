%CAPTURE_V2_HELP Save the top of the scrollable V2 operator guide.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
outputFolder = fullfile(projectRoot, 'audit', 'v2', 'ui');
outputPath = fullfile(outputFolder, '06-help.png');
if ~isfolder(outputFolder), mkdir(outputFolder); end

delete(findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer Gap Test - Help'));
show_manual();
drawnow;
helpFigure = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer Gap Test - Help');
assert(numel(helpFigure) == 1, 'The V2 Help screen did not open.');
scrollLayout = findall(helpFigure, 'Tag', 'help_scroll_layout');
assert(numel(scrollLayout) == 1 && strcmp(scrollLayout.Scrollable, 'on'), ...
    'The V2 Help screen is not scrollable.');
scroll(scrollLayout, 'top');
drawnow;
exportapp(helpFigure, outputPath);
delete(helpFigure);
assert(isfile(outputPath), 'The V2 Help audit image was not created.');
fprintf('V2 HELP CAPTURE: %s\n', outputPath);
