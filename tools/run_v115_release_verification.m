projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(fullfile(projectRoot, 'tools'));
evidenceFolder = fullfile(projectRoot, 'audit', 'v115');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end
diaryFile = fullfile(evidenceFolder, 'release-verification.txt');
if isfile(diaryFile), delete(diaryFile); end
diary(diaryFile);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

try
    run(fullfile(projectRoot, 'tools', 'build_v115_mlx.m'));
    run_v115_full_suite();
    verify_v115_clean_start();
    fprintf('V1.15 RELEASE VERIFICATION: PASS\n');
catch verificationError
    fprintf(2, '%s\n', getReport(verificationError, 'extended'));
    exit(1);
end
exit(0);
