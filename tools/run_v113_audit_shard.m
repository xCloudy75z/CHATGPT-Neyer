function run_v113_audit_shard()
%RUN_V113_AUDIT_SHARD Entry point for one independent MATLAB process.
shardIndex = str2double(getenv('NEYER_V113_AUDIT_SHARD'));
shardCount = str2double(getenv('NEYER_V113_AUDIT_SHARDS'));
assert(isfinite(shardIndex) && isfinite(shardCount), ...
    'The audit shard environment values are missing.');
run_v113_audit_simulations(shardIndex, shardCount);
end
