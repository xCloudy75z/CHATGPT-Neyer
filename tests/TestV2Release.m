classdef TestV2Release < matlab.unittest.TestCase
    methods (Test)
        function v113RemainsFrozen(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            actual = localSha256(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_13.mlx'));
            testCase.verifyEqual(actual, ...
                '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E');
        end

        function v2StandaloneFilesExist(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v2.m')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v2.mlx')));
        end

        function v2LiveScriptFunctionsMatchBuildSource(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
            buildSource = fullfile(root, 'delivery', 'Neyer_Gap_Test_v2.m');

            testCase.assertTrue(isfile(liveScript), ...
                'The V2 standalone Live Script has not been built.');
            testCase.assertTrue(isfile(buildSource), ...
                'The V2 build source has not been assembled.');

            temporaryFolder = testCase.createTemporaryFolder();
            exportedSource = fullfile(temporaryFolder, 'exported_v2.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exportedSource);
            exportedText = fileread(exportedSource);
            builtText = fileread(buildSource);
            exportedFunctions = regexp(exportedText, '(?ms)^function\s.*\z', ...
                'match', 'once');
            builtFunctions = regexp(builtText, '(?ms)^function\s.*\z', ...
                'match', 'once');
            normalise = @(text) strtrim(strrep(text, sprintf('\r\n'), sprintf('\n')));
            testCase.verifyEqual(normalise(exportedFunctions), ...
                normalise(builtFunctions));
            testCase.verifySubstring(exportedText, 'Neyer Gap Test V2');
        end
    end
end

function sha256 = localSha256(filePath)
fileId = fopen(filePath, 'rb');
assert(fileId >= 0, 'TestV2Release:cannotRead', ...
    'Could not read %s.', filePath);
closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fileBytes = fread(fileId, Inf, '*uint8');
digestEngine = java.security.MessageDigest.getInstance('SHA-256');
digestEngine.update(typecast(fileBytes(:), 'int8'));
digestBytes = typecast(digestEngine.digest(), 'uint8');
sha256 = upper(reshape(dec2hex(digestBytes, 2).', 1, []));
end
