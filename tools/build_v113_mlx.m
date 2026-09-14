project_root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v1_13.m');
destination = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v1_13.mlx');
site_destination = fullfile(project_root, 'site', 'downloads', ...
    'Neyer_Gap_Test_v1_13.mlx');
evidence = fullfile(project_root, 'audit', 'v113', 'v113-mlx-build.txt');

if ~isfile(source)
    error('build_v113_mlx:missingSource', ...
        'The generated V1.13 source is missing: %s', source);
end
if ~isfolder(fileparts(evidence)), mkdir(fileparts(evidence)); end
if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source, destination);
if ~isfile(destination)
    error('build_v113_mlx:notCreated', ...
        'MATLAB did not create the V1.13 Live Script.');
end
copyfile(destination,site_destination,'f');

file_id = fopen(evidence, 'w');
assert(file_id >= 0, 'Could not record the Live Script build.');
details = dir(destination);
fprintf(file_id, 'Neyer_Gap_Test_v1_13.mlx created by MATLAB %s.\n', ...
    version('-release'));
fprintf(file_id, 'Bytes: %d\n', details.bytes);
fprintf(file_id, 'Public-site copy created with the same filename.\n');
fclose(file_id);
exit(0);
