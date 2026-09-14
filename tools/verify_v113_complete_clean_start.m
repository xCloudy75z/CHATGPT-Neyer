function verify_v113_complete_clean_start()
%VERIFY_V113_COMPLETE_CLEAN_START Audit the MLX with no project helpers.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
liveScript = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_13.mlx');
evidencePath = fullfile(projectRoot, 'audit', 'v113-complete', ...
    'standalone-clean-start.txt');
temporaryFolder = tempname;
mkdir(temporaryFolder);
originalFolder = pwd;
originalPath = path;
cleanup = onCleanup(@() restore_environment(originalFolder, originalPath, ...
    temporaryFolder)); %#ok<NASGU>

isolatedLiveScript = fullfile(temporaryFolder, 'Neyer_Gap_Test_v1_13.mlx');
copyfile(liveScript, isolatedLiveScript);
assert_only_one_file(temporaryFolder, 'before the clean start');

exportedSource = fullfile(temporaryFolder, 'source-derived-from-mlx.m');
matlab.internal.liveeditor.openAndConvert(isolatedLiveScript, exportedSource);
sourceText = fileread(exportedSource);
embeddedFunctionCount = numel(regexp(sourceText, '(?m)^function\s', 'match'));
assert(embeddedFunctionCount >= 60, ...
    'The Live Script does not contain the expected application functions.');
delete(exportedSource);
assert_only_one_file(temporaryFolder, 'before opening the application');

evalin('base', 'restoredefaultpath');
cd(temporaryFolder);
run(isolatedLiveScript);
drawnow;
menuFigure = require_one_figure('Neyer Gap Test');

state = struct('inputDone', false, 'submittedTests', 0, 'error', '');
setappdata(groot, 'v113StandaloneAuditState', state);
automationTimer = timer('StartDelay', 0.25, 'ExecutionMode', ...
    'fixedSpacing', 'Period', 0.20, 'TasksToExecute', 500, ...
    'BusyMode', 'drop', 'TimerFcn', @(~, ~) automate_direct_run());
timerCleanup = onCleanup(@() stop_and_delete_timer(automationTimer)); %#ok<NASGU>
start(automationTimer);
runButton = require_button(menuFigure, 'Run a Test');
feval(runButton.ButtonPushedFcn, runButton, []);
stop(automationTimer);
state = getappdata(groot, 'v113StandaloneAuditState');
if ~isempty(state.error)
    error('v113Standalone:automationFailed', '%s', state.error);
end
assert(state.inputDone && state.submittedTests == 20, ...
    'The isolated direct workflow did not complete all 20 tests.');

directResult = require_one_figure('Neyer gap-study results');
verify_result_labels(directResult, '5.39', '1.04');
gapField = findall(directResult, 'Type', 'uinumericeditfield');
assert(numel(gapField) == 1, 'The result gap field was not found.');
gapField.Value = 5.39;
calculateButton = require_button(directResult, 'Calculate');
feval(calculateButton.ButtonPushedFcn, calculateButton, []);
drawnow;
resultLabels = string({findall(directResult, 'Type', 'uilabel').Text});
assert(any(contains(resultLabels, 'Best estimated chance', ...
    'IgnoreCase', true)), 'The fixed-gap chance result was not displayed.');
saveButton = require_button(directResult, 'Save results...');
assert(strcmp(saveButton.Enable, 'on') && ~isempty(saveButton.ButtonPushedFcn), ...
    'The standalone fitted result did not enable its save action.');
write_dialog_test_doubles(temporaryFolder);
rehash;
feval(saveButton.ButtonPushedFcn, saveButton, []);
drawnow;
savedHtml = fullfile(temporaryFolder, 'standalone-audit-results.html');
savedCsv = fullfile(temporaryFolder, 'standalone-audit-results.csv');
assert(isfile(savedHtml) && isfile(savedCsv), ...
    'The standalone save action did not create both result files.');
htmlBefore = fileread(savedHtml);
csvBefore = fileread(savedCsv);
feval(saveButton.ButtonPushedFcn, saveButton, []);
drawnow;
assert(strcmp(htmlBefore, fileread(savedHtml)) && ...
    strcmp(csvBefore, fileread(savedCsv)), ...
    'The second standalone save silently replaced an existing result.');
delete(directResult);

demoButton = require_button(menuFigure, 'Run the published example');
feval(demoButton.ButtonPushedFcn, demoButton, []);
drawnow;
demoResult = require_one_figure('Neyer gap-study results');
verify_result_labels(demoResult, '5.39', '1.04');
delete(demoResult);

fileId = fopen(evidencePath, 'w');
assert(fileId >= 0, 'Could not write standalone evidence.');
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'V1.13 complete standalone clean-start audit: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Initial clean folder files: 1 (Neyer_Gap_Test_v1_13.mlx only)\n');
fprintf(fileId, 'Embedded local functions: %d\n', embeddedFunctionCount);
fprintf(fileId, ['Outside project helper dependencies used during the ' ...
    'clean-start run: 0\n']);
fprintf(fileId, ['Note: MATLAB dependency-library scan was unavailable ' ...
    'because R2022b could not load libmwdepfun_analysis.dll.\n']);
fprintf(fileId, 'Direct workflow completed tests: 20\n');
fprintf(fileId, 'Direct fitted result: middle 5.39 mm, variation 1.04 mm\n');
fprintf(fileId, 'Fixed-gap chance calculation displayed: yes\n');
fprintf(fileId, 'Save action present and enabled: yes\n');
fprintf(fileId, 'Save action created matching HTML and CSV files: yes\n');
fprintf(fileId, 'Second same-name save left both files unchanged: yes\n');
fprintf(fileId, 'Published example displayed: middle 5.39 mm, variation 1.04 mm\n');
fprintf('V1.13 STANDALONE CLEAN START: PASS.\n');

    function automate_direct_run()
        state = getappdata(groot, 'v113StandaloneAuditState');
        try
            if ~state.inputDone
                inputFigure = findall(groot, 'Type', 'figure', ...
                    'Name', 'Neyer gap test - inputs');
                if numel(inputFigure) == 1
                    edits = findall(inputFigure, 'Type', 'uieditfield');
                    rows = arrayfun(@(control) control.Layout.Row, edits);
                    [~, order] = sort(rows);
                    edits = edits(order);
                    values = {'0.6','1.4','0.10','20','0','10', ...
                        'mm','0.01','0.015'};
                    assert(numel(edits) == numel(values), ...
                        'The direct input fields changed unexpectedly.');
                    for index = 1:numel(values)
                        edits(index).Value = values{index};
                    end
                    startButton = require_button(inputFigure, 'Start test');
                    state.inputDone = true;
                    setappdata(groot, 'v113StandaloneAuditState', state);
                    feval(startButton.ButtonPushedFcn, startButton, []);
                    return;
                end
            end
            testFigure = findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer gap test');
            if state.inputDone && numel(testFigure) == 1 && ...
                    state.submittedTests < 20
                labels = string({findall(testFigure, 'Type', 'uilabel').Text});
                instruction = labels(contains(labels, 'Build a gap of'));
                assert(numel(instruction) == 1, ...
                    'The requested build gap was not found.');
                token = regexp(instruction, ...
                    'Build a gap of\s+([0-9.]+)\s+mm', 'tokens', 'once');
                assert(~isempty(token), 'The requested gap could not be read.');
                measurementField = findall(testFigure, 'Type', 'uieditfield');
                assert(numel(measurementField) == 1, ...
                    'The one-measurement field was not found.');
                measurementField.Value = token{1};
                fixedOutcomes = logical([1 1 1 1 1 0 1 1 1 1 ...
                    1 1 0 1 0 1 0 0 0 0]);
                state.submittedTests = state.submittedTests + 1;
                setappdata(groot, 'v113StandaloneAuditState', state);
                if fixedOutcomes(state.submittedTests)
                    outcomeButton = require_button(testFigure, 'Interaction');
                else
                    outcomeButton = require_button(testFigure, 'No interaction');
                end
                feval(outcomeButton.ButtonPushedFcn, outcomeButton, []);
            end
        catch problem
            state.error = problem.message;
            setappdata(groot, 'v113StandaloneAuditState', state);
            delete(findall(groot, 'Type', 'figure'));
        end
    end
end

function assert_only_one_file(folder, stage)
contents = dir(folder);
contents = contents(~[contents.isdir]);
assert(numel(contents) == 1 && strcmp(contents(1).name, ...
    'Neyer_Gap_Test_v1_13.mlx'), ...
    'The isolated folder did not contain only the MLX %s.', stage);
end

function figureHandle = require_one_figure(name)
figureHandle = findall(groot, 'Type', 'figure', 'Name', name);
assert(numel(figureHandle) == 1, 'Expected one window named "%s".', name);
end

function button = require_button(parent, text)
buttons = findall(parent, 'Type', 'uibutton');
button = buttons(string({buttons.Text}) == string(text));
assert(numel(button) == 1, 'Expected one "%s" button.', text);
end

function verify_result_labels(figureHandle, middleText, variationText)
labels = string({findall(figureHandle, 'Type', 'uilabel').Text});
assert(any(contains(labels, "Middle gap", 'IgnoreCase', true) & ...
    contains(labels, middleText)) && ...
    any(contains(labels, "Overall variation", 'IgnoreCase', true) & ...
    contains(labels, variationText)), ...
    'The expected middle and variation were not displayed.');
end

function stop_and_delete_timer(timerObject)
if isvalid(timerObject)
    stop(timerObject);
    delete(timerObject);
end
end

function write_dialog_test_doubles(folder)
% Supply predetermined dialog answers; no application calculation is replaced.
write_text_file(fullfile(folder, 'uiputfile.m'), sprintf([ ...
    'function [fileName, folder] = uiputfile(varargin)\n' ...
    'fileName = ''standalone-audit-results.html'';\n' ...
    'folder = [pwd filesep];\n' ...
    'end\n']));
write_text_file(fullfile(folder, 'uiconfirm.m'), sprintf([ ...
    'function choice = uiconfirm(varargin)\n' ...
    'choice = ''Save'';\n' ...
    'end\n']));
write_text_file(fullfile(folder, 'uialert.m'), sprintf([ ...
    'function handle = uialert(varargin)\n' ...
    'handle = [];\n' ...
    'end\n']));
end

function write_text_file(path, content)
fileId = fopen(path, 'w');
assert(fileId >= 0, 'Could not create a temporary dialog test control.');
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', content);
end

function restore_environment(originalFolder, originalPath, temporaryFolder)
figures = findall(groot, 'Type', 'figure');
if ~isempty(figures), delete(figures); end
path(originalPath);
cd(originalFolder);
if isfolder(temporaryFolder), rmdir(temporaryFolder, 's'); end
end
