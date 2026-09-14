projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
addpath(fullfile(projectRoot, 'tools'));
evidenceFolder = fullfile(projectRoot, 'audit', 'v113-complete');
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

testFile = fullfile(projectRoot, 'tests', 'TestV113CompleteAudit.m');
workflowResults = runtests(testFile, 'Tag', 'workflow');
if isempty(workflowResults)
    error('run_v113_workflow_audit:noTests', ...
        'No workflow audit tests were selected.');
end

screen = [
    "Main menu"
    "Direct-run inputs"
    "Unfinished result"
    "Fitted result and chance calculator"
    "Saved CSV and HTML"
    ];
action = [
    "Open the application"
    "Enter valid and invalid values"
    "Review three completed tests before overlap"
    "Calculate Interaction chance at the fitted middle gap"
    "Save once, then try the same name again"
    ];
expected = [
    "Direct Run a Test is visibly independent from the optional planner"
    "Invalid entries are rejected using visible question names"
    "No fitted number or NaN is shown; completed data remain saveable"
    "Best estimate is 50% and a separate cautious minimum is shown"
    "Screen values agree with both files and earlier files are not replaced"
    ];
observed = strings(numel(workflowResults), 1);
status = strings(numel(workflowResults), 1);
for resultNumber = 1:numel(workflowResults)
    if workflowResults(resultNumber).Passed
        observed(resultNumber) = "Matched the expected behavior";
        status(resultNumber) = "Pass";
    elseif workflowResults(resultNumber).Incomplete
        observed(resultNumber) = "The check did not finish";
        status(resultNumber) = "Incomplete";
    else
        observed(resultNumber) = "Did not match the expected behavior";
        status(resultNumber) = "Fail";
    end
end
workflowMatrix = table(screen, action, expected, observed, status);
writetable(workflowMatrix, fullfile(evidenceFolder, 'workflow-matrix.csv'));

demo = run_demo();
temporaryFolder = tempname;
mkdir(temporaryFolder);
cleanupFolder = onCleanup(@() remove_temporary_folder(temporaryFolder)); %#ok<NASGU>
chosenBase = fullfile(temporaryFolder, 'operator-chosen-study.html');
csvText = results_to_csv_text(demo.result);
htmlText = results_to_html(demo.result, '');
paths = save_results_files(chosenBase, csvText, htmlText);
collisionBlocked = false;
try
    save_results_files(chosenBase, 'replacement CSV', 'replacement HTML');
catch problem
    collisionBlocked = strcmp(problem.identifier, ...
        'save_results_files:alreadyExists');
end
csvMatches = strcmp(fileread(paths.csv), csvText);
htmlMatches = strcmp(fileread(paths.html), htmlText);
fileId = fopen(fullfile(evidenceFolder, 'save-record-audit.txt'), 'w');
assert(fileId >= 0, 'Could not write the save-record audit.');
fprintf(fileId, 'V1.13 save-record audit\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'User-selected base name produced matching CSV: %s\n', ...
    string(csvMatches));
fprintf(fileId, 'User-selected base name produced matching HTML: %s\n', ...
    string(htmlMatches));
fprintf(fileId, 'Second save using the same name was blocked: %s\n', ...
    string(collisionBlocked));
fprintf(fileId, 'Test files were isolated in a temporary folder and removed afterward.\n');
fclose(fileId);

delete(findall(groot, 'Type', 'figure'));
allPassed = all([workflowResults.Passed]) && csvMatches && ...
    htmlMatches && collisionBlocked;
markerPath = fullfile(evidenceFolder, 'workflow-audit-complete.txt');
fileId = fopen(markerPath, 'w');
assert(fileId >= 0, 'Could not write the workflow completion marker.');
fprintf(fileId, 'Complete: %d checks, all passed: %s\n', ...
    numel(workflowResults), string(allPassed));
fclose(fileId);
fprintf('V1.13 WORKFLOW AUDIT: %d checks; all passed: %s.\n', ...
    numel(workflowResults), string(allPassed));
if ~allPassed
    error('run_v113_workflow_audit:failed', ...
        'At least one workflow audit check failed.');
end

function remove_temporary_folder(folderPath)
if isfolder(folderPath), rmdir(folderPath, 's'); end
end
