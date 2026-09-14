project_root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v2.m');
destination = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
evidence = fullfile(project_root, 'audit', 'v2', 'v2-mlx-build.txt');

if ~isfile(source)
    error('build_v2_mlx:missingSource', ...
        'The generated V2 source is missing: %s', source);
end
if ~isfolder(fileparts(evidence)), mkdir(fileparts(evidence)); end
if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source, destination);
if ~isfile(destination)
    error('build_v2_mlx:notCreated', ...
        'MATLAB did not create the V2 Live Script.');
end

file_id = fopen(evidence, 'w');
assert(file_id >= 0, 'Could not record the V2 Live Script build.');
details = dir(destination);
fprintf(file_id, 'Neyer_Gap_Test_v2.mlx created by MATLAB %s.\n', ...
    version('-release'));
fprintf(file_id, 'Bytes: %d\n', details.bytes);
fprintf(file_id, 'No public-site copy was created.\n');
fclose(file_id);
exit(0);
