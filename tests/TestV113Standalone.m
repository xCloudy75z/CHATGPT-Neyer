classdef TestV113Standalone < matlab.unittest.TestCase
    methods (Test)
        function candidateContainsTheReviewedApplication(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            liveScript=fullfile(root,'delivery','Neyer_Gap_Test_v1_13.mlx');
            buildSource=fullfile(root,'delivery','Neyer_Gap_Test_v1_13.m');

            testCase.assertTrue(isfile(liveScript), ...
                'The corrected V1.13 standalone Live Script has not been built.');
            testCase.assertTrue(isfile(buildSource), ...
                'The tracked V1.13 build source is missing.');

            temporaryFolder=testCase.createTemporaryFolder();
            exportedSource=fullfile(temporaryFolder,'exported_v113.m');
            matlab.internal.liveeditor.openAndConvert(liveScript,exportedSource);
            exportedText=fileread(exportedSource);
            builtText=fileread(buildSource);
            exportedFunctions=regexp(exportedText,'(?ms)^function\s.*\z','match','once');
            builtFunctions=regexp(builtText,'(?ms)^function\s.*\z','match','once');
            normalise=@(text)strtrim(strrep(text,sprintf('\r\n'),sprintf('\n')));
            testCase.verifyEqual(normalise(exportedFunctions), ...
                normalise(builtFunctions));
            testCase.verifySubstring(exportedText,'Neyer Gap Test v1.13');
        end
    end
end
