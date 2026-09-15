function verify_v114_clean_start()
%VERIFY_V114_CLEAN_START Test the MLX with no project source on the path.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
liveScript = fullfile(projectRoot, 'delivery', 'Neyer_Gap_Test_v1_14.mlx');
evidenceFolder = fullfile(projectRoot, 'audit', 'v114');
uiFolder = fullfile(evidenceFolder, 'ui');
if ~isfolder(uiFolder), mkdir(uiFolder); end
temporaryFolder = tempname;
mkdir(temporaryFolder);
originalFolder = pwd;
originalPath = path;
cleanup = onCleanup(@() restore_environment(originalFolder, originalPath, ...
    temporaryFolder)); %#ok<NASGU>

isolatedLiveScript = fullfile(temporaryFolder, 'Neyer_Gap_Test_v1_14.mlx');
copyfile(liveScript, isolatedLiveScript);
contents = dir(temporaryFolder);
contents = contents(~[contents.isdir]);
assert(numel(contents) == 1 && strcmp(contents.name, ...
    'Neyer_Gap_Test_v1_14.mlx'), ...
    'The clean folder did not begin with only the V1.14 MLX.');

defaultEntries = strsplit(pathdef, pathsep);
defaultEntries = defaultEntries(cellfun(@isfolder, defaultEntries));
path(strjoin(defaultEntries, pathsep));
cd(temporaryFolder);
run(isolatedLiveScript);
drawnow;
menuFigure = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer Gap Test V1.14');
assert(numel(menuFigure) == 1, ...
    'The isolated Live Script did not open the V1.14 menu.');
exportapp(menuFigure, fullfile(uiFolder, '01-menu.png'));
delete(menuFigure);

convertedSource = fullfile(temporaryFolder, 'from-v114-mlx.m');
matlab.internal.liveeditor.openAndConvert(isolatedLiveScript, convertedSource);
sourceText = fileread(convertedSource);
assert(isempty(regexp(sourceText, 'application[\\/]+source', ...
    'once', 'ignorecase')), 'The MLX contains an outside source path.');
[embeddedFiles, embeddedBodies] = embedded_source_files(sourceText);
assert(numel(embeddedFiles) == 64, ...
    'Expected 64 embedded source files, found %d.', numel(embeddedFiles));

loadedFolder = fullfile(temporaryFolder, 'loaded-from-mlx');
mkdir(loadedFolder);
for fileNumber = 1:numel(embeddedFiles)
    write_utf8(fullfile(loadedFolder, embeddedFiles{fileNumber}), ...
        embeddedBodies{fileNumber});
end
addpath(loadedFolder);
rehash;
assert(contains(which('run_test'), loadedFolder), ...
    'The clean test did not use code extracted from the MLX.');

answers = struct('study_mode', 'First study - variation unknown', ...
    'low_guess', '0.6', 'high_guess', '1.4', ...
    'variation_guess', '', 'maximum_tests', '20', ...
    'minimum_gap', '0', 'maximum_gap', '10', 'unit', 'mm', ...
    'physical_mode', 'Regular gap step', 'regular_step', '0.01', ...
    'confirmed_gaps', '', 'foil_thickness', '0.015');
parsed = parse_run_inputs(answers);
assert(strcmp(parsed.cfg.study_mode, 'first_study') && ...
    strcmp(parsed.cfg.search_scale_source, 'automatic'), ...
    'The isolated first-study route was not active.');

example = run_demo();
assert(example.is_match, 'The isolated published example did not match.');
low = reliability_query(example.result, 'interaction', ...
    'probability_at', 2, 0.95);
high = reliability_query(example.result, 'interaction', ...
    'probability_at', 8, 0.95);
assert(low.probability > high.probability, ...
    'The isolated Interaction probability did not fall as gap increased.');

base = fullfile(temporaryFolder, 'clean-start-result.html');
saved = save_results_files(base, results_to_csv_text(example.result), ...
    results_to_html(example.result, ''));
beforeCsv = fileread(saved.csv);
collision = capture_error(@() save_results_files(base, 'replace', 'replace'));
assert(strcmp(collision.identifier, 'save_results_files:alreadyExists'), ...
    'The isolated app did not reject a same-name save.');
assert(strcmp(beforeCsv, fileread(saved.csv)), ...
    'The rejected save altered an existing file.');

evidencePath = fullfile(evidenceFolder, 'clean-start-results.txt');
fileId = fopen(evidencePath, 'w');
assert(fileId >= 0, 'Could not write clean-start evidence.');
fileCleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Neyer Gap Test V1.14 clean-start: PASS\n');
fprintf(fileId, 'MATLAB release: %s\n', version('-release'));
fprintf(fileId, 'Initial files: one MLX only\n');
fprintf(fileId, 'Menu opened from isolated MLX: yes\n');
fprintf(fileId, 'Embedded source files: %d\n', numel(embeddedFiles));
fprintf(fileId, 'First-study unknown-variation route: yes\n');
fprintf(fileId, 'Published example: %.4f / %.4f mm\n', ...
    example.got_mu, example.got_sigma);
fprintf(fileId, 'Interaction probability fell with larger gap: yes\n');
fprintf(fileId, 'Same-name save rejected without replacement: yes\n');
fprintf('V1.14 CLEAN START: PASS.\n');
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

function write_utf8(filePath, content)
fileId = fopen(filePath, 'w', 'n', 'UTF-8');
assert(fileId >= 0, 'Could not reconstruct %s.', filePath);
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '%s', content);
end

function problem = capture_error(callback)
problem = MException.empty;
try
    callback();
catch caught
    problem = caught;
end
assert(~isempty(problem), 'The repeated save was unexpectedly accepted.');
end

function restore_environment(originalFolder, originalPath, temporaryFolder)
figures = findall(groot, 'Type', 'figure');
if ~isempty(figures), delete(figures); end
path(originalPath);
cd(originalFolder);
if isfolder(temporaryFolder), rmdir(temporaryFolder, 's'); end
end
