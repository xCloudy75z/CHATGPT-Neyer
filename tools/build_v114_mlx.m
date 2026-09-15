projectRoot = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_14.m');
destination = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_14.mlx');
evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
evidence = fullfile(evidenceFolder, 'v114-mlx-build.txt');
assert(isfile(source), 'The assembled V1.14 source is missing.');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source, destination);
assert(isfile(destination), 'MATLAB did not create the V1.14 Live Script.');

roundTrip = fullfile(tempdir, 'neyer-v114-round-trip.m');
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
assert(fileId >= 0, 'Could not write V1.14 build evidence.');
cleanFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer_Gap_Test_v1_14.mlx build: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Bytes: %d\n', details.bytes);
fprintf(fileId, 'Embedded function round trip matched: yes\n');
