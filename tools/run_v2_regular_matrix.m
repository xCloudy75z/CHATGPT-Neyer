function run_v2_regular_matrix(shard,shards)
if nargin<1, shard=1; end
if nargin<2, shards=1; end
run_v2_matrix('regular',shard,shards);
end
