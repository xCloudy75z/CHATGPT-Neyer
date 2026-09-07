function hash_text = planner_validation_hash(config_path)
%PLANNER_VALIDATION_HASH Identify the exact configuration used by every shard.
    if ~(ischar(config_path) || (isstring(config_path) && isscalar(config_path))) || ...
            ~isfile(config_path)
        error('planner_validation_hash:missingConfig', ...
            'The planner-validation configuration file was not found.');
    end
    raw_text = fileread(config_path);
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(uint8(unicode2native(raw_text, 'UTF-8')));
    bytes = typecast(digest.digest(), 'uint8');
    hash_text = lower(reshape(dec2hex(bytes, 2).', 1, []));
end
