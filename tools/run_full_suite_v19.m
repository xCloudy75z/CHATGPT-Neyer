root = fileparts(fileparts(mfilename('fullpath')));
cd(root);

try
    run(fullfile(root,'run_gap_tests.m'));
    fid = fopen(fullfile(root,'review-preview','full-suite-v19-passed.txt'),'w');
    fprintf(fid,'Full V1.9 MATLAB regression suite passed.\n');
    fclose(fid);
    exit(0);
catch err
    fprintf(2,'%s\n',getReport(err,'extended','hyperlinks','off'));
    exit(1);
end
