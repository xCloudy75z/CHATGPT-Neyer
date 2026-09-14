classdef TestV112Standalone < matlab.unittest.TestCase
    methods (Test)
        function candidateIsOneSelfContainedLiveScript(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            live_script = fullfile(root,'delivery','Neyer_Gap_Test_v1_12.mlx');

            testCase.assertTrue(isfile(live_script), ...
                'The v1.12 Live Script has not been built.');
            temporary_folder = testCase.createTemporaryFolder();
            exported_source = fullfile(temporary_folder,'exported_v112.m');
            matlab.internal.liveeditor.openAndConvert(live_script,exported_source);
            text = fileread(exported_source);
            normalised_text = regexprep(text,'\s+',' ');
            forbidden = {'addpath(', 'C:\Users\', '.exe', ...
                'application/source', 'application\source', ...
                'measurement uncertainty', 'not assessed'};
            for item = 1:numel(forbidden)
                testCase.verifyFalse(contains(text,forbidden{item}, ...
                    'IgnoreCase',true));
            end
            required = {'MATLAB R2022b','Measure the completed setup once', ...
                'two decimal places','never replaces', ...
                'existing plan or result file silently', ...
                'Foil recipes are unavailable'};
            for item = 1:numel(required)
                testCase.verifyTrue(contains(normalised_text,required{item}, ...
                    'IgnoreCase',true),sprintf( ...
                    'Standalone instructions do not explain: %s',required{item}));
            end
            testCase.verifyFalse(contains(text,'Enter 4 or 5 measured gaps', ...
                'IgnoreCase',true));

            source_files = dir(fullfile(root,'application','source','*.m'));
            for file_number = 1:numel(source_files)
                source_text = fileread(fullfile(source_files(file_number).folder, ...
                    source_files(file_number).name));
                declaration = regexp(source_text, ...
                    '(?m)^\s*function\s+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*)?([A-Za-z]\w*)', ...
                    'tokens','once');
                testCase.assertNotEmpty(declaration);
                built_declarations = regexp(text, ...
                    ['(?m)^\s*function\s+(?:(?:\[[^\]]+\]|[A-Za-z]\w*)' ...
                    '\s*=\s*)?' declaration{1} '\s*\('],'match');
                testCase.verifyNumElements(built_declarations,1,sprintf( ...
                    'Function %s must be embedded exactly once.',declaration{1}));
            end
        end


        function fiveTrialEvidenceIdentifiesFreshV112Run(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            evidence_path = fullfile(root,'audit','direct-62-trials', ...
                'five-trial-audit.txt');
            evidence = fileread(evidence_path);
            testCase.verifySubstring(evidence,'Release: V1.12');
            testCase.verifySubstring(evidence,'Executed:');
            testCase.verifyMatches(evidence, ...
                'V1\.12 Live Script SHA-256: [A-F0-9]{64}');
            testCase.verifySubstring(evidence,'Seeds: 202609081 through 202609085');
        end
    end
end
