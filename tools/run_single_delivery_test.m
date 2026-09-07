root = fileparts(fileparts(mfilename('fullpath')));
cd(root);

results = runtests(fullfile(root,'tests','TestV19Delivery.m'));
disp(results);

if all([results.Passed])
    exit(0);
end
exit(1);
