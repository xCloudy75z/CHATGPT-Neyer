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

        function v2LiveScriptContainsEveryReviewedFunctionExactlyOnce(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            sourceRoot = fullfile(root, 'application', 'source');
            liveScript = fullfile(root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
            temporaryFolder = testCase.createTemporaryFolder();
            exportedSource = fullfile(temporaryFolder, 'exported_v2.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exportedSource);
            exportedNames = localFunctionNames(fileread(exportedSource));

            sourceFiles = dir(fullfile(sourceRoot, '*.m'));
            sourceNames = strings(0, 1);
            for fileNumber = 1:numel(sourceFiles)
                fileNames = localFunctionNames(fileread( ...
                    fullfile(sourceFiles(fileNumber).folder, ...
                    sourceFiles(fileNumber).name)));
                if strcmp(sourceFiles(fileNumber).name, ...
                        'parse_confirmed_gap_list.m')
                    fileNames(fileNames == "validate_bounds") = ...
                        "validate_confirmed_gap_bounds";
                end
                sourceNames = [sourceNames; fileNames]; %#ok<AGROW>
            end

            testCase.assertEqual(numel(unique(sourceNames)), ...
                numel(sourceNames), ...
                'Standalone-local function names must be unique.');
            testCase.verifyEqual(sort(exportedNames), sort(sourceNames), ...
                ['The V2 Live Script must contain every reviewed source ' ...
                 'function exactly once, with no extra functions.']);
        end

        function v2LiveScriptHasNoSourcePathAndKeepsOperatingSections(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
            temporaryFolder = testCase.createTemporaryFolder();
            exportedSource = fullfile(temporaryFolder, 'exported_v2.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exportedSource);
            exportedText = fileread(exportedSource);

            testCase.verifyEmpty(regexp(exportedText, ...
                'application[\\/]+source', 'once', 'ignorecase'), ...
                'The standalone must not refer to application/source.');
            requiredSections = { ...
                '%% Start a direct test without the planner', ...
                '%% Physical gap settings', ...
                '%% Procedure for every destructive article', ...
                '%% Saving and reopening', ...
                '%% Important limits', ...
                '%% Start the application'};
            for sectionNumber = 1:numel(requiredSections)
                testCase.verifySubstring(exportedText, ...
                    requiredSections{sectionNumber});
            end
        end

        function v2AssemblyPreservesUtf8SourceComments(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            sourceRoot = fullfile(root, 'application', 'source');
            builtText = localNormaliseNewlines(fileread(fullfile(root, ...
                'delivery', 'Neyer_Gap_Test_v2.m')));
            sourceFiles = dir(fullfile(sourceRoot, '*.m'));

            for fileNumber = 1:numel(sourceFiles)
                sourceText = localNormaliseNewlines(fileread(fullfile( ...
                    sourceFiles(fileNumber).folder, ...
                    sourceFiles(fileNumber).name)));
                comments = regexp(sourceText, '(?m)^\s*%[^\n]*', 'match');
                for commentNumber = 1:numel(comments)
                    testCase.verifySubstring(builtText, ...
                        comments{commentNumber}, sprintf( ...
                        'The generated source changed UTF-8 text from %s.', ...
                        sourceFiles(fileNumber).name));
                end
            end
        end

        function v2CleanStartBeginsWithOnlyTheLiveScript(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
            temporaryFolder = testCase.createTemporaryFolder();
            isolatedLiveScript = fullfile(temporaryFolder, ...
                'Neyer_Gap_Test_v2.mlx');

            copyfile(liveScript, isolatedLiveScript);
            contents = dir(temporaryFolder);
            contents = contents(~[contents.isdir]);

            testCase.verifyEqual({contents.name}, {'Neyer_Gap_Test_v2.mlx'});
            testCase.verifyTrue(isfile(isolatedLiveScript));
        end
    end
end

function names = localFunctionNames(text)
tokens = regexp(text, ['(?m)^\s*function\s+' ...
    '(?:(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*)?' ...
    '([A-Za-z]\w*)'], 'tokens');
names = string(cellfun(@(token) token{1}, tokens, 'UniformOutput', false));
names = names(:);
end

function text = localNormaliseNewlines(text)
text = strrep(text, sprintf('\r\n'), sprintf('\n'));
text = strrep(text, sprintf('\r'), sprintf('\n'));
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
