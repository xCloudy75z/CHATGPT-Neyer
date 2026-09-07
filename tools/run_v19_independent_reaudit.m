root=fileparts(fileparts(mfilename('fullpath')));
cd(root);
evidenceFolder=fullfile(root,'audit','v19-reaudit');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

results=runtests(fullfile(root,'tests'));
names=string({results.Name})';
passed=[results.Passed]';
failed=[results.Failed]';
incomplete=[results.Incomplete]';
durationSeconds=[results.Duration]';
evidence=table(names,passed,failed,incomplete,durationSeconds, ...
    'VariableNames',{'test_name','passed','failed','incomplete','duration_seconds'});
writetable(evidence,fullfile(evidenceFolder,'v19-reaudit-tests.csv'));

summaryFile=fullfile(evidenceFolder,'v19-reaudit-test-summary.txt');
fileId=fopen(summaryFile,'w');
if fileId<0
    error('run_v19_independent_reaudit:summaryWrite', ...
        'Could not write the re-audit test summary.');
end
cleanup=onCleanup(@()fclose(fileId));
fprintf(fileId,'MATLAB version: %s\n',version);
fprintf(fileId,'Completed: %s\n',char(datetime('now','TimeZone','Asia/Dubai')));
fprintf(fileId,'Passed: %d\n',sum(passed));
fprintf(fileId,'Failed: %d\n',sum(failed));
fprintf(fileId,'Incomplete: %d\n',sum(incomplete));
fprintf(fileId,'Testing seconds: %.6f\n',sum(durationSeconds));

fprintf('\nV1.9 RE-AUDIT: %d passed, %d failed, %d incomplete.\n', ...
    sum(passed),sum(failed),sum(incomplete));
if any(failed) || any(incomplete)
    error('run_v19_independent_reaudit:testFailure', ...
        'The V1.9 re-audit suite did not pass cleanly.');
end
