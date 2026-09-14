%VERIFY_V2_CLEAN_START Exercise V2 with no project application source.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
liveScript = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v2.mlx');
evidenceFolder = fullfile(projectRoot, 'audit', 'v2', 'clean-start');
evidencePath = fullfile(evidenceFolder, 'standalone-clean-start.txt');
temporaryFolder = tempname;
mkdir(temporaryFolder);
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

originalFolder = pwd;
originalPath = path;
cleanup = onCleanup(@() restore_environment(originalFolder, originalPath, ...
    temporaryFolder)); %#ok<NASGU>

assert(isfile(liveScript), 'verify_v2_clean_start:missingLiveScript', ...
    'The V2 Live Script is missing: %s', liveScript);
isolatedLiveScript = fullfile(temporaryFolder, 'Neyer_Gap_Test_v2.mlx');
copyfile(liveScript, isolatedLiveScript);
assert_only_v2_mlx(temporaryFolder);

restoredefaultpath;
cd(temporaryFolder);
assert(~contains(lower(path), lower(fullfile(projectRoot, ...
    'application', 'source'))), ...
    'The project application source remained on the MATLAB path.');

% The MLX itself must launch before any source is materialised from it.
run(isolatedLiveScript);
drawnow;
menuFigure = findall(groot, 'Type', 'figure', 'Name', 'Neyer Gap Test V2');
assert(numel(menuFigure) == 1, ...
    'The isolated V2 Live Script did not open its application menu.');
delete(menuFigure);
drawnow;

% Convert the sole delivery artifact, then reconstruct its marked source files.
% These files are derived only from the MLX and remain inside the clean folder.
convertedSource = fullfile(temporaryFolder, 'source-derived-from-v2-mlx.m');
matlab.internal.liveeditor.openAndConvert(isolatedLiveScript, convertedSource);
sourceText = fileread(convertedSource);
assert(isempty(regexp(sourceText, 'application[\\/]+source', ...
    'once', 'ignorecase')), ...
    'The embedded source contains an application/source dependency.');
[embeddedFiles, embeddedBodies] = embedded_source_files(sourceText);
assert(numel(embeddedFiles) == 63, ...
    'Expected 63 embedded source files, found %d.', numel(embeddedFiles));

loadedSourceFolder = fullfile(temporaryFolder, 'loaded-from-v2-mlx');
mkdir(loadedSourceFolder);
for fileNumber = 1:numel(embeddedFiles)
    write_utf8(fullfile(loadedSourceFolder, embeddedFiles{fileNumber}), ...
        embeddedBodies{fileNumber});
end
addpath(loadedSourceFolder);
rehash;

primaryFunctions = erase(string(embeddedFiles), '.m');
for functionNumber = 1:numel(primaryFunctions)
    resolved = which(char(primaryFunctions(functionNumber)));
    assert(~isempty(resolved), 'Embedded function %s was not available.', ...
        primaryFunctions(functionNumber));
    assert(strcmpi(fileparts(resolved), loadedSourceFolder), ...
        'Embedded function %s resolved outside the clean folder: %s', ...
        primaryFunctions(functionNumber), resolved);
end
functionNames = embedded_function_names(sourceText);
assert(numel(functionNames) == numel(unique(functionNames)), ...
    'The standalone contains duplicate local function names.');

% Run the normal physical route directly, with no planner or saved plan.
answers = struct('low_guess', '0.6', 'high_guess', '1.4', ...
    'variation_guess', '0.10', 'maximum_tests', '20', ...
    'minimum_gap', '0', 'maximum_gap', '10', 'unit', 'mm', ...
    'physical_mode', 'Regular gap step', 'regular_step', '0.01', ...
    'confirmed_gaps', '', 'foil_thickness', '0.015');
parsed = parse_run_inputs(answers);
fixedOutcomes = logical([1 1 1 1 1 0 1 1 1 1 ...
    1 1 0 1 0 1 0 0 0 0]);
response = @(gap, testNumber) struct( ...
    'outcome', fixedOutcomes(testNumber), 'measurements', gap);
[directResult, directRecord] = run_physical_test(parsed.params, 20, ...
    response, parsed.cfg);
assert(directResult.n == 20 && numel(directRecord.levels) == 20, ...
    'The direct physical workflow did not complete 20 results.');
assert(all(directResult.measurement_count == 1), ...
    'The direct physical workflow did not keep one measurement per setup.');
assert(all(isfinite(directRecord.requested_levels)) && ...
    all(directRecord.requested_levels >= 0) && ...
    all(directRecord.requested_levels <= 10), ...
    'The direct workflow requested a gap outside its permitted range.');
assert(all(cellfun(@(text) ~isempty(regexp(text, ...
    '\d+\.\d{2}\s+mm', 'once')), directRecord.requested_instructions)), ...
    'A direct-workflow build request was not shown with two decimals.');

% Independently exercise the published replay and known result gate.
demo = run_demo();
assert(demo.is_match && abs(demo.got_mu - 5.3922) <= 1e-3 && ...
    abs(demo.got_sigma - 1.0412) <= 1e-3, ...
    'The published replay did not return 5.3922 / 1.0412.');

probability = reliability_query(directResult, 'interaction', ...
    'probability_at', 5.39, 0.95);
assert(isfinite(probability.percent) && ...
    probability.percent >= 0 && probability.percent <= 100 && ...
    isfinite(probability.bound_percent), ...
    'The direct result did not produce a finite probability answer.');

% Use the same path calculation shown by the application, then write real files.
chosenBase = fullfile(temporaryFolder, 'standalone-v2-results.html');
shownPaths = result_output_paths(chosenBase);
csvText = results_to_csv_text(directResult);
htmlText = results_to_html(directResult, '');
assert(contains(lower(htmlText), '<!doctype html>') && ...
    contains(lower(htmlText), '<meta charset="utf-8">') && ...
    isempty(regexp(htmlText, ...
    '(?i)(?:src|href)\s*=\s*["'']https?://', 'once')), ...
    'The HTML result is not a self-contained offline document.');
savedPaths = save_results_files(chosenBase, csvText, htmlText);
assert(strcmp(shownPaths.csv, savedPaths.csv) && ...
    strcmp(shownPaths.html, savedPaths.html), ...
    'The shown save paths did not equal the paths actually written.');
assert(isfile(savedPaths.csv) && isfile(savedPaths.html), ...
    'The CSV and HTML result files were not both written.');
assert(strcmpi(fileparts(savedPaths.csv), temporaryFolder) && ...
    strcmpi(fileparts(savedPaths.html), temporaryFolder), ...
    'A result file was saved outside the selected clean folder.');

csvBefore = fileread(savedPaths.csv);
htmlBefore = fileread(savedPaths.html);
collision = capture_error(@() save_results_files(chosenBase, ...
    'replacement CSV', 'replacement HTML'));
assert(strcmp(collision.identifier, 'save_results_files:alreadyExists') && ...
    contains(collision.message, 'Nothing was saved') && ...
    contains(collision.message, 'Choose a different name'), ...
    'A same-name second save did not give an understandable rejection.');
assert(strcmp(csvBefore, fileread(savedPaths.csv)) && ...
    strcmp(htmlBefore, fileread(savedPaths.html)), ...
    'The rejected second save changed an existing result file.');

invalidAnswers = answers;
invalidAnswers.regular_step = '0.015';
invalidInput = capture_error(@() parse_run_inputs(invalidAnswers));
assert(strcmp(invalidInput.identifier, ...
    'parse_run_inputs:badUsableResolution') && ...
    contains(invalidInput.message, 'two-decimal build requests') && ...
    contains(invalidInput.message, 'Enter'), ...
    'The invalid-input message did not explain what to correct.');

incompleteAnswers = rmfield(answers, 'maximum_gap');
incompleteInput = capture_error(@() parse_run_inputs(incompleteAnswers));
assert(strcmp(incompleteInput.identifier, ...
    'parse_run_inputs:badNamedShape') && ...
    contains(incompleteInput.message, 'Complete all direct-test settings'), ...
    'The incomplete-input message did not explain what to complete.');

invalidListAnswers = answers;
invalidListAnswers.physical_mode = 'Confirmed gap list';
invalidListAnswers.regular_step = '';
invalidListAnswers.confirmed_gaps = '1, wrong, 2';
invalidList = capture_error(@() parse_run_inputs(invalidListAnswers));
assert(strcmp(invalidList.identifier, ...
    'parse_confirmed_gap_list:badEntry') && ...
    contains(invalidList.message, 'Confirmed gap list') && ...
    contains(invalidList.message, 'enter', 'IgnoreCase', true), ...
    'The invalid confirmed-list message did not identify the correction.');

% Preserve real outputs and a concise audit record before deleting the temp run.
auditCsv = fullfile(evidenceFolder, 'standalone-v2-results.csv');
auditHtml = fullfile(evidenceFolder, 'standalone-v2-results.html');
copyfile(savedPaths.csv, auditCsv, 'f');
copyfile(savedPaths.html, auditHtml, 'f');
fileId = fopen(evidencePath, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'Could not write V2 clean-start evidence.');
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer Gap Test V2 standalone clean-start: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Initial clean-folder files: 1 (Neyer_Gap_Test_v2.mlx only)\n');
fprintf(fileId, 'Application menu opened from the isolated MLX: yes\n');
fprintf(fileId, 'Embedded source files reconstructed from MLX: %d\n', ...
    numel(embeddedFiles));
fprintf(fileId, 'Embedded local function declarations: %d\n', ...
    numel(functionNames));
fprintf(fileId, 'Outside application/source or helper dependency used: no\n');
fprintf(fileId, 'Direct physical workflow results: %d\n', directResult.n);
fprintf(fileId, 'One measurement per new setup: yes\n');
fprintf(fileId, 'All direct build requests used two decimals: yes\n');
fprintf(fileId, 'Direct result middle / variation: %.4f / %.4f mm\n', ...
    directResult.mu, directResult.sigma);
fprintf(fileId, 'Published replay middle / variation: %.4f / %.4f mm\n', ...
    demo.got_mu, demo.got_sigma);
fprintf(fileId, 'Interaction probability at 5.39 mm: %.6g%%\n', ...
    probability.percent);
fprintf(fileId, 'Cautious supported probability at 95%% confidence: %.6g%%\n', ...
    probability.bound_percent);
fprintf(fileId, 'Shown CSV path equalled actual CSV path: yes\n');
fprintf(fileId, 'Shown HTML path equalled actual HTML path: yes\n');
fprintf(fileId, 'Same-name second save rejected without replacement: yes\n');
fprintf(fileId, 'Invalid regular-step message: %s\n', ...
    one_line(invalidInput.message));
fprintf(fileId, 'Incomplete-input message: %s\n', ...
    one_line(incompleteInput.message));
fprintf(fileId, 'Invalid confirmed-list message: %s\n', ...
    one_line(invalidList.message));
fprintf(fileId, 'Evidence CSV: %s\n', auditCsv);
fprintf(fileId, 'Evidence HTML: %s\n', auditHtml);
fprintf('V2 STANDALONE CLEAN START: PASS.\n');

function assert_only_v2_mlx(folder)
contents = dir(folder);
contents = contents(~[contents.isdir]);
assert(numel(contents) == 1 && ...
    strcmp(contents(1).name, 'Neyer_Gap_Test_v2.mlx'), ...
    'The clean-start folder did not initially contain only the V2 MLX.');
end

function [fileNames, bodies] = embedded_source_files(sourceText)
tokens = regexp(sourceText, [ ...
    '(?ms)^% === BEGIN EMBEDDED SOURCE: ([^\r\n]+) ===\r?\n' ...
    '(.*?)\r?\n% === END EMBEDDED SOURCE: [^\r\n]+ ==='], 'tokens');
fileNames = cellfun(@(token) token{1}, tokens, 'UniformOutput', false);
bodies = cellfun(@(token) token{2}, tokens, 'UniformOutput', false);
assert(numel(unique(fileNames)) == numel(fileNames), ...
    'An embedded source filename was duplicated.');
end

function names = embedded_function_names(sourceText)
tokens = regexp(sourceText, ['(?m)^\s*function\s+' ...
    '(?:(?:\[[^\]]+\]|[A-Za-z]\w*)\s*=\s*)?' ...
    '([A-Za-z]\w*)'], 'tokens');
names = string(cellfun(@(token) token{1}, tokens, 'UniformOutput', false));
end

function write_utf8(filePath, content)
fileId = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'Could not materialise embedded source %s.', filePath);
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', content);
end

function problem = capture_error(callback)
problem = MException.empty;
try
    callback();
catch caught
    problem = caught;
end
assert(~isempty(problem), 'The invalid operation was unexpectedly accepted.');
end

function text = one_line(text)
text = regexprep(text, '[\r\n]+', ' | ');
end

function restore_environment(originalFolder, originalPath, temporaryFolder)
figures = findall(groot, 'Type', 'figure');
if ~isempty(figures), delete(figures); end
path(originalPath);
cd(originalFolder);
if isfolder(temporaryFolder), rmdir(temporaryFolder, 's'); end
end
