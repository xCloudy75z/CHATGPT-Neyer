root=fileparts(fileparts(mfilename('fullpath')));
liveScript=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.mlx');
run(liveScript);
drawnow;
fig=findall(groot,'Type','figure','Name','Neyer Gap Test');
if isempty(fig)
    error('verify_v19_mlx:noMenu','The V1.9 Live Script did not open the Neyer Gap Test menu.');
end
exportapp(fig(1),fullfile(root,'review-preview','matlab-v19','06-mlx-launch.png'));
delete(fig);
fid=fopen(fullfile(root,'review-preview','mlx-launch-passed.txt'),'w');
fprintf(fid,'MATLAB R2022b opened the V1.9 .mlx and displayed the Neyer Gap Test menu.\n');
fclose(fid);
exit;
