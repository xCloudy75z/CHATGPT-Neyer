%RUN_V2_FULL_SUITE All application, historical audit, V2, and recorder tests.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root);
assert(usejava('desktop'),'Run the final suite with -desktop -r to exercise every UI test.');
started=tic;
main=testsuite(fullfile(root,'tests'));
recorder=testsuite(fullfile(root,'measurement-recorder','tests'));
suite=[main(:); recorder(:)];
results=run(suite);
folder=fullfile(root,'audit','v2');
fid=fopen(fullfile(folder,'full-suite-results.txt'),'w'); assert(fid>=0);
fprintf(fid,'Neyer V2 complete release suite\nMATLAB release: %s\nDesktop UI: enabled\nTotal: %d\nPassed: %d\nFailed: %d\nIncomplete: %d\nElapsed seconds: %.3f\n', ...
    version('-release'),numel(results),sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]),toc(started));
for k=1:numel(results)
    fprintf(fid,'%s | Passed=%d Failed=%d Incomplete=%d\n',results(k).Name,results(k).Passed,results(k).Failed,results(k).Incomplete);
    if results(k).Failed
        d=results(k).Details.DiagnosticRecord;
        for j=1:numel(d), fprintf(fid,'%s\n',d(j).Report); end
    end
end
fclose(fid);
fprintf('V2 FULL SUITE: %d passed, %d failed, %d incomplete.\n',sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]));
assertSuccess(results);
assert(~any([results.Incomplete]));
