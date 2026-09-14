%V2_RELEASE_FINGERPRINT Seal the tested artifacts; this never rebuilds them.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'tools')); addpath(fullfile(root,'application','source'));
folder=v2_audit_folder(root);
suite=fileread(fullfile(folder,'full-suite-results.txt'));
assert(contains(suite,sprintf('\nFailed: 0\n')) && contains(suite,sprintf('\nIncomplete: 0\n')));
clean=fileread(fullfile(folder,'clean-start','standalone-clean-start.txt'));
assert(contains(clean,'standalone clean-start: PASS'));
regular=v2_collect_results('regular',fullfile(folder,'matrices'));
irregular=v2_collect_results('list',fullfile(folder,'matrices'));
% Tie the CSV totals to the full transcripts and the exact final source bytes.
sourceFiles=[dir(fullfile(root,'application','source','*.m')); ...
    dir(fullfile(root,'tools','*v2*matrix*.m')); ...
    dir(fullfile(root,'tools','v2_check_transcript.m'))];
sourceHashes=strings(numel(sourceFiles),1);
for k=1:numel(sourceFiles)
    fp=v113_release_fingerprint(fullfile(sourceFiles(k).folder,sourceFiles(k).name));
    sourceHashes(k)=string(fp.sha256);
end
checkpoints=dir(fullfile(folder,'matrices','*.mat'));
assert(~isempty(checkpoints),'Full matrix transcripts are missing.');
verifiedTranscripts=0;
for k=1:numel(checkpoints)
    saved=load(fullfile(checkpoints(k).folder,checkpoints(k).name));
    assert(isequal(saved.hashes,sourceHashes),'A matrix checkpoint predates the final source.');
    csv=readtable(fullfile(checkpoints(k).folder,strrep(checkpoints(k).name,'.mat','.csv')));
    assert(isequal(csv.id,[saved.rows.id]') && height(csv)==numel(saved.records));
    for j=1:numel(saved.records)
        item=saved.records{j};
        result=struct('has_overlap',has_overlap(item.record.levels,item.record.successes), ...
            'mu',item.mu,'sigma',item.sigma);
        checks=v2_check_transcript(result,item.record,item.case.gaps);
        assert(sum(struct2array(checks))==0 && saved.rows(j).replay_mismatches==0);
        verifiedTranscripts=verifiedTranscripts+1;
    end
end
assert(verifiedTranscripts==regular.studies+irregular.studies);
names={'Neyer_Gap_Test_v1_13.mlx','Neyer_Gap_Test_v2.m','Neyer_Gap_Test_v2.mlx'};
for k=1:numel(names)
    fingerprints(k)=v113_release_fingerprint(fullfile(root,'delivery',names{k})); %#ok<SAGROW>
end
assert(strcmp(fingerprints(1).sha256,'2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E'));
demo=run_demo();
assert(abs(demo.got_mu-5.3922)<1e-4 && abs(demo.got_sigma-1.0412)<1e-4);
fid=fopen(fullfile(folder,'release-fingerprint.txt'),'w'); assert(fid>=0);
fprintf(fid,'Neyer V2 tested release fingerprints\nMATLAB release: %s\n',version('-release'));
for k=1:numel(names)
    fprintf(fid,'%s\nBytes: %d\nSHA-256: %s\n',names{k},fingerprints(k).bytes,fingerprints(k).sha256);
end
fprintf(fid,'V1.13 unchanged: yes\nNo build performed by fingerprint gate.\n');
fprintf(fid,'Full transcripts rechecked against final source: %d\n',verifiedTranscripts);
fprintf(fid,'%s\n',regexp(clean,'Total function declarations: \d+','match','once'));
fprintf(fid,'%s\n',regexp(suite,'Total: \d+\nPassed: \d+\nFailed: \d+\nIncomplete: \d+','match','once'));
fprintf(fid,'Regular studies: %d; replays: %d; invariant failures: %d; replay mismatches: %d\n', ...
    regular.studies,regular.replays,regular.invariant_failures,regular.replay_mismatches);
fprintf(fid,'Confirmed-list studies: %d; replays: %d; invariant failures: %d; replay mismatches: %d\n', ...
    irregular.studies,irregular.replays,irregular.invariant_failures,irregular.replay_mismatches);
fprintf(fid,'Published example middle / variation: %.4f / %.4f mm\n',demo.got_mu,demo.got_sigma);
fclose(fid);
disp(fileread(fullfile(folder,'release-fingerprint.txt')));
