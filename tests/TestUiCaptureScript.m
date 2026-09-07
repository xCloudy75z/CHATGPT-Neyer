classdef TestUiCaptureScript < matlab.unittest.TestCase
    methods (Test)
        function captureScriptCoversEveryOperatorScreen(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            script=fullfile(root,'tools','capture_v19_ui.m');
            testCase.assertTrue(isfile(script));
            text=fileread(script);
            expected={'01-main-menu.png','02-settings.png','03-test-gap.png', ...
                      '04-results.png','05-help.png'};
            for k=1:numel(expected)
                testCase.verifySubstring(text,expected{k});
            end
            testCase.verifySubstring(text,'exportapp');
            testCase.verifySubstring(text,'run_test_ui');
            testCase.verifySubstring(text,'show_result');
        end
    end
end
