root=fileparts(fileparts(mfilename('fullpath')));
cd(root);
run(fullfile(root,'run_gap_tests.m'));
fid=fopen(fullfile(root,'review-preview','full-suite-passed.txt'),'w');
fprintf(fid,'Complete V1.9 MATLAB gap suite passed.\n');
fclose(fid);
exit;
