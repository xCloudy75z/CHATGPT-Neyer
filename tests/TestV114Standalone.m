classdef TestV114Standalone < matlab.unittest.TestCase
    methods (Test)
        function standaloneFilesExistAndV113IsStillFrozen(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.m')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.mlx')));
            frozen = v113_release_fingerprint(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_13.mlx'));
            testCase.verifyEqual(frozen.sha256, ...
                '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E');
        end

        function liveScriptMatchesAssembledFunctions(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.mlx');
            assembled = fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.m');
            exported = fullfile(testCase.createTemporaryFolder(), ...
                'exported_v114.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exported);
            exportedFunctions = regexp(fileread(exported), ...
                '(?ms)^function\s.*\z', 'match', 'once');
            assembledFunctions = regexp(fileread(assembled), ...
                '(?ms)^function\s.*\z', 'match', 'once');
            normalise = @(value) strtrim(strrep(value, sprintf('\r\n'), sprintf('\n')));
            testCase.verifyEqual(normalise(exportedFunctions), ...
                normalise(assembledFunctions));
        end

        function liveScriptContainsReviewedSourceAndFocusedMenu(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.mlx');
            exported = fullfile(testCase.createTemporaryFolder(), ...
                'exported_v114.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exported);
            text = fileread(exported);

            testCase.verifySubstring(text, '%% Neyer Gap Test V1.14');
            testCase.verifySubstring(text, 'First study - variation unknown');
            testCase.verifySubstring(text, 'Start a Gap Study');
            testCase.verifyFalse(contains(text, ...
                '''Pre-Test Planner (separate)'''));
            testCase.verifyEmpty(regexp(text, ...
                'application[\\/]+source', 'once', 'ignorecase'));
            testCase.verifyEqual(numel(regexp(text, ...
                '^% === BEGIN EMBEDDED SOURCE:', 'lineanchors')), 64);
        end
    end
end
