projectRoot = fileparts(fileparts(mfilename('fullpath')));
assemblyScript = fullfile(projectRoot, 'tools', 'build_standalone_v115.ps1');
builderCommand = sprintf([ ...
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%s" ' ...
    '-ProjectRoot "%s"'], assemblyScript, projectRoot);
[builderStatus, builderOutput] = system(builderCommand);
assert(builderStatus == 0, ...
    'Could not assemble the V1.15 working source. %s', builderOutput);
fprintf('%s', builderOutput);
source = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_15.m');
destination = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_15.mlx');
evidenceFolder = fullfile(projectRoot, 'audit', 'v115');
evidence = fullfile(evidenceFolder, 'v115-mlx-build.txt');
assert(isfile(source), 'The assembled V1.15 source is missing.');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source, destination);
assert(isfile(destination), 'MATLAB did not create the V1.15 Live Script.');

roundTrip = fullfile(tempdir, 'neyer-v115-round-trip.m');
if isfile(roundTrip), delete(roundTrip); end
matlab.internal.liveeditor.openAndConvert(destination, roundTrip);
sourceText = fileread(source);
roundTripText = fileread(roundTrip);
sourceFunctions = regexp(sourceText, '(?ms)^function\s.*\z', 'match', 'once');
roundTripFunctions = regexp(roundTripText, '(?ms)^function\s.*\z', 'match', 'once');
normalise = @(value) strtrim(strrep(value, sprintf('\r\n'), sprintf('\n')));
assert(strcmp(normalise(sourceFunctions), normalise(roundTripFunctions)), ...
    'The Live Script round trip changed its embedded functions.');

details = dir(destination);
fileId = fopen(evidence, 'w');
assert(fileId >= 0, 'Could not write V1.15 build evidence.');
cleanFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer_Gap_Test_v1_15.mlx build: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Bytes: %d\n', details.bytes);
fprintf(fileId, 'Embedded function round trip matched: yes\n');
