function summary=v2_collect_results(mode,folder)
%V2_COLLECT_RESULTS Refuse missing, duplicated, failed or mixed shard evidence.
expected=numel(v2_matrix_cases(mode));
files=dir(fullfile(folder,[mode '-*-of-*.csv']));
rows=table();
for k=1:numel(files)
    part=readtable(fullfile(files(k).folder,files(k).name));
    % Empty reason columns can infer as numeric in one shard and text in
    % another. Only the numeric certification fields belong in this sum.
    rows=[rows;part(:,{'id','invariant_failures','replay_mismatches'})]; %#ok<AGROW>
end
if height(rows)~=expected || ~isequal(sort(rows.id),(1:expected)')
    error('v2Matrix:incomplete','Expected exactly %d distinct %s studies.',expected,mode);
end
summary=struct('mode',mode,'studies',height(rows),'replays',height(rows), ...
    'invariant_failures',sum(rows.invariant_failures), ...
    'replay_mismatches',sum(rows.replay_mismatches));
assert(summary.invariant_failures==0 && summary.replay_mismatches==0, ...
    'v2Matrix:failed','The matrix contains failed checks.');
end
