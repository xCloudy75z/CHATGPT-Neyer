root=fileparts(mfilename('fullpath'));
results=runtests(fullfile(root,'tests','TestResolutionAwareStage2.m'));
disp(results);
assertSuccess(results);
