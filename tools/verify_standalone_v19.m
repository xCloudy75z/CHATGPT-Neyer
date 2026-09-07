root = fileparts(fileparts(mfilename('fullpath')));
liveScript = fullfile(root,'delivery','Neyer_Gap_Test_v1_9.mlx');
deliveryOverride = getenv('NEYER_LIVE_SCRIPT');
if ~isempty(deliveryOverride)
    liveScript = deliveryOverride;
end
temporaryFolder = tempname;
mkdir(temporaryFolder);

originalFolder = pwd;
originalPath = path;
cleanup = onCleanup(@() restore_verification_environment(originalFolder,originalPath,temporaryFolder));

if ~isfile(liveScript)
    error('verify_standalone_v19:missingLiveScript','The V1.9 Live Script is missing.');
end

exportedSource = fullfile(temporaryFolder,'exported_v19.m');
matlab.internal.liveeditor.openAndConvert(liveScript,exportedSource);
exportedText = fileread(exportedSource);
embeddedCount = numel(regexp(exportedText,'(?m)^function\s','match'));
if embeddedCount < 68
    error('verify_standalone_v19:notEmbedded', ...
        'The Live Script exported only %d local functions; at least 68 are required.',embeddedCount);
end

buildSource=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.m');
if ~isfile(buildSource)
    error('verify_standalone_v19:missingBuildSource', ...
        'The generated standalone source is missing.');
end
builtText=fileread(buildSource);
embeddedFunctions=regexp(exportedText,'(?ms)^function\s.*\z','match','once');
builtFunctions=regexp(builtText,'(?ms)^function\s.*\z','match','once');
normalise=@(text)strtrim(strrep(text,sprintf('\r\n'),sprintf('\n')));
if ~strcmp(normalise(embeddedFunctions),normalise(builtFunctions))
    error('verify_standalone_v19:embeddedSourceMismatch', ...
        'The functions embedded in the Live Script do not match the reviewed build source.');
end

isolatedLiveScript = fullfile(temporaryFolder,'Neyer_Gap_Test_v1_9.mlx');
copyfile(liveScript,isolatedLiveScript);
delete(exportedSource);
contents = dir(temporaryFolder);
contents = contents(~ismember({contents.name},{'.','..'}));
if numel(contents) ~= 1 || ~strcmp(contents(1).name,'Neyer_Gap_Test_v1_9.mlx')
    error('verify_standalone_v19:notIsolated','The test folder must contain only the Live Script.');
end

restoredefaultpath;
cd(temporaryFolder);
run(isolatedLiveScript);
drawnow;

menu = findall(groot,'Type','figure','Name','Neyer Gap Test');
if isempty(menu)
    error('verify_standalone_v19:noMenu','The isolated Live Script did not open the Neyer Gap Test menu.');
end
menu = menu(1);

buttons = findall(menu,'Type','uibutton');
isDemo = arrayfun(@(button) strcmp(button.Text,'Run a Demo (verify)'),buttons);
if ~any(isDemo)
    error('verify_standalone_v19:noDemo','The embedded demo button was not found.');
end
demoButton = buttons(find(isDemo,1));
feval(demoButton.ButtonPushedFcn,demoButton,[]);
drawnow;

resultFigure = findall(groot,'Type','figure','Name','Neyer gap-study results');
if isempty(resultFigure)
    error('verify_standalone_v19:noResult','The embedded demo did not open its results screen.');
end
labels = findall(resultFigure(1),'Type','uilabel');
labelText = string({labels.Text});
if ~any(contains(labelText,'5.39')) || ~any(contains(labelText,'1.04'))
    error('verify_standalone_v19:wrongDemoResult', ...
        'The isolated demo did not display middle gap 5.39 and transition width 1.04.');
end

fprintf('Isolated Live Script verification passed.\n');
fprintf('Embedded local functions: %d\n',embeddedCount);
fprintf('Embedded functions match the reviewed build source exactly.\n');
fprintf('Published demo display: middle gap 5.39, transition width 1.04.\n');

marker = fullfile(root,'review-preview','standalone-mlx-passed.txt');
fid = fopen(marker,'w');
if fid < 0
    error('verify_standalone_v19:marker','Could not write the verification marker.');
end
fprintf(fid,'MATLAB R2022b isolated Live Script verification passed.\n');
fprintf(fid,'Embedded local functions: %d\n',embeddedCount);
fprintf(fid,'Published demo display: 5.39 / 1.04.\n');
fclose(fid);
exit(0);

function restore_verification_environment(originalFolder,originalPath,temporaryFolder)
    figures = findall(groot,'Type','figure');
    if ~isempty(figures), delete(figures); end
    path(originalPath);
    cd(originalFolder);
    if isfolder(temporaryFolder), rmdir(temporaryFolder,'s'); end
end
