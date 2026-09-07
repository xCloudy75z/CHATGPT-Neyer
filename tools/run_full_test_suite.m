root = fileparts(fileparts(mfilename('fullpath')));
cd(root);
results = runtests(fullfile(root,'tests'));
disp(results);
fprintf('\nFULL SUITE: %d passed, %d failed, %d incomplete.\n', ...
    sum([results.Passed]), sum([results.Failed]), sum([results.Incomplete]));
if all([results.Passed]), exit(0); end
exit(1);
