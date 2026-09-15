function fingerprint = v114_release_manifest()
%V114_RELEASE_MANIFEST Record the preserved V1.13 artifact before V1.14 work.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
artifact = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_13.mlx');
fingerprint = v113_release_fingerprint(artifact);
expected = '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E';
assert(strcmp(fingerprint.sha256, expected), ...
    'V1.13 does not match the preserved release fingerprint.');

evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
evidencePath = fullfile(evidenceFolder, 'v113-preserved.txt');
fileId = fopen(evidencePath, 'w');
assert(fileId >= 0, 'Could not write the V1.13 preservation record.');
closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Preserved release: delivery/Neyer_Gap_Test_v1_13.mlx\n');
fprintf(fileId, 'SHA-256: %s\n', fingerprint.sha256);
fprintf(fileId, 'Bytes: %d\n', fingerprint.bytes);
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Recorded: %s\n', char(datetime('now', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z')));
end
