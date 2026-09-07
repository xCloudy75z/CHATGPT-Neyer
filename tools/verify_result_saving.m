root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'application','source'));
temporaryFolder = tempname;
mkdir(temporaryFolder);
cleanup = onCleanup(@()rmdir(temporaryFolder,'s')); %#ok<NASGU>

chosenBase = fullfile(temporaryFolder,'operator-selected-name.html');
paths = save_results_files(chosenBase,'sample CSV','sample HTML');
assert(strcmp(paths.csv,fullfile(temporaryFolder,'operator-selected-name.csv')));
assert(strcmp(paths.html,fullfile(temporaryFolder,'operator-selected-name.html')));
assert(strcmp(fileread(paths.csv),'sample CSV'));
assert(strcmp(fileread(paths.html),'sample HTML'));

fprintf('Result-save verification passed.\n');
fprintf('CSV path: %s\n',paths.csv);
fprintf('HTML path: %s\n',paths.html);
exit(0);
