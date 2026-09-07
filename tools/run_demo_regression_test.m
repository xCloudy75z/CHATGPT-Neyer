root=fileparts(fileparts(mfilename('fullpath')));
cd(root);
result=runtests(fullfile(root,'tests','TestGapDirection.m'), ...
    'Name','TestGapDirection/publishedDemoUsesDecreasingGapOutcomes');
disp(result);
if all([result.Passed])
    fid=fopen(fullfile(root,'review-preview','demo-test-passed.txt'),'w');
    fprintf(fid,'Gap demo regression passed.\n');
    fclose(fid);
end
exit;
