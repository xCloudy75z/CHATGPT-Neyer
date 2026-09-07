markerPath=fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'review-preview','desktop-startup-ok.txt');
fid=fopen(markerPath,'w');
if fid<0
    error('desktop_startup_smoke:cannotWrite','Could not write the startup marker.');
end
fprintf(fid,'Normal MATLAB desktop startup reached the review script.\n');
fclose(fid);
exit;
