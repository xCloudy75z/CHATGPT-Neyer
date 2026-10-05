function verify_v115_clean_start()
%VERIFY_V115_CLEAN_START Test V1.15 with only the standalone MLX available.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
liveScript = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_15.mlx');
evidenceFolder = fullfile(projectRoot, 'audit', 'v115');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
temporaryFolder = tempname;
mkdir(temporaryFolder);
originalFolder = pwd;
originalPath = path;
cleanup = onCleanup(@() restore_environment(originalFolder, originalPath, ...
    temporaryFolder)); %#ok<NASGU>

isolatedLiveScript = fullfile(temporaryFolder, 'Neyer_Gap_Test_v1_15.mlx');
copyfile(liveScript, isolatedLiveScript);
contents = dir(temporaryFolder);
contents = contents(~[contents.isdir]);
assert(numel(contents) == 1 && strcmp(contents.name, ...
    'Neyer_Gap_Test_v1_15.mlx'), ...
    'The clean folder did not begin with only the V1.15 MLX.');

defaultEntries = strsplit(pathdef, pathsep);
defaultEntries = defaultEntries(cellfun(@isfolder, defaultEntries));
path(strjoin(defaultEntries, pathsep));
cd(temporaryFolder);
run(isolatedLiveScript);
drawnow;
menuFigure = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer Gap Test V1.15');
assert(numel(menuFigure) == 1, ...
    'The isolated Live Script did not open the V1.15 menu.');
menuButtons = findall(menuFigure, 'Type', 'uibutton');
menuButtonText = string({menuButtons.Text});
assert(any(menuButtonText == "Start a Gap Study"), ...
    'The isolated menu is missing Start a Gap Study.');
assert(any(menuButtonText == "Help and Definitions"), ...
    'The isolated menu is missing Help and Definitions.');
assert(~any(menuButtonText == "Run the Published Example"), ...
    'The isolated menu exposes the removed example shortcut.');
delete(menuFigure);

convertedSource = fullfile(temporaryFolder, 'from-v115-mlx.m');
matlab.internal.liveeditor.openAndConvert(isolatedLiveScript, convertedSource);
sourceText = lower(fileread(convertedSource));
assert(isempty(regexp(sourceText, 'application[\\/]+source', ...
    'once', 'ignorecase')), 'The MLX contains an outside source path.');
assert(numel(regexp(sourceText, ...
    '^% === begin embedded source:', 'lineanchors')) == 64, ...
    'The standalone file does not contain all 64 embedded sources.');
assert(contains(sourceText, 'neyer gap test v1.15'), ...
    'The standalone file does not identify itself as V1.15.');
assert(contains(sourceText, 'best estimated chance %.4g%%.'), ...
    'The central probability estimate wording is missing.');
assert(~contains(sourceText, 'cautious minimum supported by the data'), ...
    'The removed cautious-minimum wording remains in the standalone file.');
assert(~contains(sourceText, ...
    'direction: smaller gaps make interaction more likely'), ...
    'The removed direction sentence remains in the standalone file.');
assert(~contains(sourceText, 'this 95% view describes uncertainty'), ...
    'The removed 95% explanation remains in the standalone file.');

evidencePath = fullfile(evidenceFolder, 'clean-start-results.txt');
fileId = fopen(evidencePath, 'w');
assert(fileId >= 0, 'Could not write V1.15 clean-start evidence.');
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer Gap Test V1.15 clean-start: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Initial files: one MLX only\n');
fprintf(fileId, 'Menu opened from isolated MLX: yes\n');
fprintf(fileId, 'Embedded source files: 64\n');
fprintf(fileId, 'Confidence-only result wording absent: yes\n');
fprintf(fileId, 'Direction sentence absent: yes\n');
fprintf('V1.15 CLEAN START: PASS.\n');
end

function restore_environment(originalFolder, originalPath, temporaryFolder)
figures = findall(groot, 'Type', 'figure');
if ~isempty(figures), delete(figures); end
path(originalPath);
cd(originalFolder);
if isfolder(temporaryFolder), rmdir(temporaryFolder, 's'); end
end
