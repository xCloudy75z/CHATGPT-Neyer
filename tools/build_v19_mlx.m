root=fileparts(fileparts(mfilename('fullpath')));
source=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.m');
destination=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.mlx');

if ~isfile(source)
    error('build_v19_mlx:missingSource','Live Script source is missing: %s',source);
end

if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source,destination);

if ~isfile(destination)
    error('build_v19_mlx:notCreated','MATLAB did not create the V1.9 Live Script.');
end

fid=fopen(fullfile(root,'review-preview','mlx-build-complete.txt'),'w');
fprintf(fid,'Neyer_Gap_Test_v1_9.mlx created by MATLAB R2022b.\n');
fclose(fid);
exit;
