function fingerprint = v113_release_fingerprint(filePath)
%V113_RELEASE_FINGERPRINT Return the size and SHA-256 of one release file.
% The audit uses this independent byte-level check to ensure the sealed
% V1.13 Live Script is not changed while it is being examined.

if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
    error('v113_release_fingerprint:invalidPath', ...
        'The release file path must be one line of text.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('v113_release_fingerprint:missingFile', ...
        'The release file does not exist: %s', filePath);
end

fileId = fopen(filePath, 'rb');
if fileId < 0
    error('v113_release_fingerprint:cannotRead', ...
        'The release file could not be read: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fileBytes = fread(fileId, Inf, '*uint8');

digestEngine = java.security.MessageDigest.getInstance('SHA-256');
digestEngine.update(typecast(fileBytes(:), 'int8'));
digestBytes = typecast(digestEngine.digest(), 'uint8');
sha256 = upper(reshape(dec2hex(digestBytes, 2).', 1, []));

fileInformation = dir(filePath);
fingerprint = struct( ...
    'path', filePath, ...
    'bytes', fileInformation.bytes, ...
    'sha256', sha256);
end
