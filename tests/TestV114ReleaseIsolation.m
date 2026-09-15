classdef TestV114ReleaseIsolation < matlab.unittest.TestCase
    methods (Test)
        function v113LiveScriptRemainsByteForByteFrozen(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            artifact = fullfile(projectRoot, 'delivery', ...
                'Neyer_Gap_Test_v1_13.mlx');
            fingerprint = v113_release_fingerprint(artifact);

            testCase.verifyEqual(fingerprint.sha256, ...
                '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E');
        end
    end
end
