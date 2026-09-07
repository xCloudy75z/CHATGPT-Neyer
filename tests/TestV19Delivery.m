classdef TestV19Delivery < matlab.unittest.TestCase
    methods (Test)
        function liveScriptSourceIsSelfContainedAndOperatorFriendly(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            sourcePath=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.m');
            livePath=fullfile(root,'delivery','Neyer_Gap_Test_v1_9.mlx');
            testCase.assertTrue(isfile(sourcePath));
            testCase.assertTrue(isfile(livePath));
            text=fileread(sourcePath);
            testCase.verifySubstring(text,'MATLAB R2022b');
            testCase.verifySubstring(text,'4 or 5 times');
            testCase.verifySubstring(text,'CSV data file');
            testCase.verifySubstring(text,'self-contained HTML result report');
            testCase.verifySubstring(text,'shows both complete paths before saving');
            testCase.verifySubstring(text,'never replaces an existing result file');
            testCase.verifySubstring(text,'Requested gap');
            testCase.verifySubstring(text,'Reachable gap');
            testCase.verifySubstring(text,'Measured mean');
            testCase.verifySubstring(text,'Known limitations');
            testCase.verifySubstring(text,'neyer_app');
            testCase.verifyGreaterThanOrEqual(numel(regexp(text,'(?m)^function\s','match')),68, ...
                'The delivered source must embed the complete application as local functions.');
            testCase.verifyFalse(contains(text,'addpath('), ...
                'A standalone Live Script must not add an external function folder.');
            testCase.verifyFalse(contains(text,'Neyer_Gap_Test_v1_9_functions'), ...
                'The obsolete companion function folder must not be required.');
            testCase.verifyFalse(contains(text,'mfilename(''fullpath'')'), ...
                'The Live Script must not locate runtime dependencies beside itself.');
            testCase.verifyFalse(contains(lower(text),'.exe'));
            testCase.verifyFalse(contains(text,'C:\Users\'));
        end
    end
end
