project_root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v1_10.m');
destination = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v1_10.mlx');
evidence = fullfile(project_root, 'audit', 'overnight', ...
    'v110-mlx-build.txt');

if ~isfile(source)
    error('build_v110_mlx:missingSource', ...
        'The generated v1.10 source is missing: %s', source);
end
if isfile(destination)
    delete(destination);
end
matlab.internal.liveeditor.openAndSave(source, destination);
if ~isfile(destination)
    error('build_v110_mlx:notCreated', ...
        'MATLAB did not create the v1.10 Live Script.');
end

file_id = fopen(evidence, 'w');
assert(file_id >= 0, 'Could not record the Live Script build.');
details = dir(destination);
fprintf(file_id, 'Neyer_Gap_Test_v1_10.mlx created by MATLAB %s.\n', ...
    version('-release'));
fprintf(file_id, 'Bytes: %d\n', details.bytes);
fclose(file_id);
exit(0);
