project_root = fileparts(fileparts(mfilename('fullpath')));
cd(project_root);
start_time = tic;
main_suite = testsuite(fullfile(project_root,'tests'));
recorder_suite = testsuite(fullfile(project_root,'measurement-recorder','tests'));
suite = [main_suite(:); recorder_suite(:)];
results = run(suite);
elapsed_seconds = toc(start_time);

evidence_folder = fullfile(project_root,'audit','v113');
if ~isfolder(evidence_folder), mkdir(evidence_folder); end
output_path = fullfile(evidence_folder,'full-suite-results.txt');
file_id = fopen(output_path,'w');
assert(file_id >= 0,'Could not create the V1.13 full-suite evidence.');
fprintf(file_id,'Neyer V1.13 and general measurement recorder test suite\n');
fprintf(file_id,'MATLAB release: %s\n',version('-release'));
fprintf(file_id,'Passed: %d\nFailed: %d\nIncomplete: %d\n', ...
    sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]));
fprintf(file_id,'Elapsed seconds: %.3f\n',elapsed_seconds);
fclose(file_id);
fprintf('\nV1.13 FULL SUITE: %d passed, %d failed, %d incomplete.\n', ...
    sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]));
if any([results.Failed]) || any([results.Incomplete]), exit(1); end
exit(0);
