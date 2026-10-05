classdef TestV115Standalone < matlab.unittest.TestCase
    methods (Test)
        function standaloneFilesExistAndV114RemainsAvailable(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_15.m')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_15.mlx')));
            testCase.verifyTrue(isfile(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_14.mlx')));
        end

        function mlxBuilderCreatesItsGeneratedInput(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            builder = fileread(fullfile(root, 'tools', 'build_v115_mlx.m'));
            testCase.verifySubstring(builder, 'build_standalone_v115.ps1');
            testCase.verifySubstring(builder, 'assert(builderStatus == 0');
        end

        function liveScriptMatchesAssembledFunctions(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            liveScript = fullfile(root, 'delivery', 'Neyer_Gap_Test_v1_15.mlx');
            assembled = fullfile(root, 'delivery', 'Neyer_Gap_Test_v1_15.m');
            exported = fullfile(testCase.createTemporaryFolder(), ...
                'exported_v115.m');
            matlab.internal.liveeditor.openAndConvert(liveScript, exported);
            exportedFunctions = regexp(fileread(exported), ...
                '(?ms)^function\s.*\z', 'match', 'once');
            assembledFunctions = regexp(fileread(assembled), ...
                '(?ms)^function\s.*\z', 'match', 'once');
            normalise = @(value) strtrim(strrep(value, sprintf('\r\n'), sprintf('\n')));
            testCase.verifyEqual(normalise(exportedFunctions), ...
                normalise(assembledFunctions));
        end

        function userFacingResultTextOmitsRemovedClaims(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            source = lower(fileread(fullfile(root, 'delivery', ...
                'Neyer_Gap_Test_v1_15.m')));
            testCase.verifySubstring(source, '%% neyer gap test v1.15');
            testCase.verifySubstring(source, ...
                'at %.2f %s: best estimated chance %.4g%%.');
            testCase.verifyFalse(contains(source, ...
                'direction: smaller gaps make interaction more likely'));
            testCase.verifyFalse(contains(source, ...
                'this 95% view describes uncertainty'));
            testCase.verifyFalse(contains(source, ...
                'cautious minimum supported by the data'));
            testCase.verifyFalse(contains(source, ...
                'isnan(answer.bound_percent)'));
        end
    end
end
