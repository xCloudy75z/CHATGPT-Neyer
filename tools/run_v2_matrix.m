function run_v2_matrix(mode,shard,shards,folder)
%RUN_V2_MATRIX Resume deterministic studies only for the same source bytes.
validateattributes(shard,{'numeric'},{'scalar','integer','positive','<=',shards});
validateattributes(shards,{'numeric'},{'scalar','integer','positive'});
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'application','source'));
if nargin<4, folder=fullfile(root,'audit','v2','matrices'); end
if ~isfolder(folder), mkdir(folder); end
sourceFiles=[dir(fullfile(root,'application','source','*.m')); ...
    dir(fullfile(root,'tools','*v2*matrix*.m')); ...
    dir(fullfile(root,'tools','v2_check_transcript.m'))];
hashes=strings(numel(sourceFiles),1);
for j=1:numel(sourceFiles)
    fp=v113_release_fingerprint(fullfile(sourceFiles(j).folder,sourceFiles(j).name));
    hashes(j)=string(fp.sha256);
end
checkpoint=fullfile(folder,sprintf('%s-%d-of-%d.mat',mode,shard,shards));
csvPath=fullfile(folder,sprintf('%s-%d-of-%d.csv',mode,shard,shards));
cases=v2_matrix_cases(mode); ids=find(mod([cases.id]-1,shards)+1==shard);
rows=struct([]); records=cell(0,1);
if isfile(checkpoint)
    saved=load(checkpoint);
    assert(isequal(hashes,saved.hashes),'Source changed: use a fresh checkpoint folder.');
    rows=saved.rows; records=saved.records;
end
for pos=numel(rows)+1:numel(ids)
    c=cases(ids(pos)); started=tic;
    [result,record]=one_run(c,mode);
    [again,replayed]=one_run(c,mode);
    failures=v2_check_transcript(result,record,c.gaps);
    replay=isequaln(record.requested_levels,replayed.requested_levels) && ...
        isequaln(record.successes,replayed.successes) && ...
        isequaln(record.stage,replayed.stage) && ...
        isequaln([result.mu result.sigma],[again.mu again.sigma]);
    row=struct('id',c.id,'scenario',c.scenario,'repetition',c.repetition, ...
        'seed',c.seed,'middle',c.middle,'variation',c.variation,'step',c.step, ...
        'starting',c.starting,'budget',c.budget,'completed',record.N, ...
        'status',string(record.status),'reason',string(record.stop_reason), ...
        'invariant_failures',sum(struct2array(failures)), ...
        'replay_mismatches',double(~replay),'seconds',toc(started));
    names=fieldnames(failures);
    for j=1:numel(names), row.(names{j})=failures.(names{j}); end
    if isempty(rows), rows=row; else, rows(pos)=row; end %#ok<AGROW>
    records{pos}=struct('case',c,'record',record,'mu',result.mu,'sigma',result.sigma); %#ok<AGROW>
    % Save every ten studies; the fixed seeds make interrupted work repeatable.
    if mod(pos,10)==0 || pos==numel(ids)
        save(checkpoint,'rows','records','hashes');
        writetable(struct2table(rows),csvPath);
        fprintf('%s shard %d/%d: %d/%d studies, %d failures, %d replay mismatches.\n', ...
            mode,shard,shards,pos,numel(ids),sum([rows.invariant_failures]),sum([rows.replay_mismatches]));
    end
end
assert(all([rows.invariant_failures]==0) && all([rows.replay_mismatches]==0), ...
    'The release matrix found a failure. See the checkpoint transcripts.');
end
function [result,record]=one_run(c,mode)
stream=RandStream('mt19937ar','Seed',c.seed);
thresholds=c.middle+c.variation*randn(stream,c.budget,1);
params=struct('avg_low',0,'avg_high',10,'spread_guess',c.starting);
cfg=neyer_settings(); cfg.min_level=0; cfg.max_level=10; cfg.level_increment=c.step;
if strcmp(mode,'regular'), setup=struct('mode','regular','increment_mm',c.step);
else, setup=struct('mode','list','gaps_mm',c.gaps); end
cfg.reachable_model=reachable_gap_model(setup,0,10);
response=@(gap,k) struct('outcome',gap<=thresholds(k),'measurements',gap);
evalc('[result,record]=run_physical_test(params,c.budget,response,cfg);');
end
