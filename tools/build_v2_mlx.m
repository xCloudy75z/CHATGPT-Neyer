project_root = fileparts(fileparts(mfilename('fullpath')));
source = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v2.m');
destination = fullfile(project_root, 'delivery', 'Neyer_Gap_Test_v2.mlx');
evidence = fullfile(v2_audit_folder(project_root), 'clean-start', ...
    'v2-mlx-build.txt');

if ~isfile(source)
    error('build_v2_mlx:missingSource', ...
        'The generated V2 source is missing: %s', source);
end
if ~isfolder(fileparts(evidence)), mkdir(fileparts(evidence)); end
if isfile(destination), delete(destination); end
matlab.internal.liveeditor.openAndSave(source, destination);
if ~isfile(destination)
    error('build_v2_mlx:notCreated', ...
        'MATLAB did not create the V2 Live Script.');
end

round_trip_source = [tempname '.m'];
round_trip_cleanup = onCleanup(@() delete_if_present(round_trip_source)); %#ok<NASGU>
matlab.internal.liveeditor.openAndConvert(destination, round_trip_source);
source_text = fileread(source);
round_trip_text = fileread(round_trip_source);
normalise = @(text) strtrim(strrep(text, sprintf('\r\n'), sprintf('\n')));
source_functions = regexp(source_text, '(?ms)^function\s.*\z', ...
    'match', 'once');
round_trip_functions = regexp(round_trip_text, '(?ms)^function\s.*\z', ...
    'match', 'once');
assert(strcmp(normalise(source_functions), normalise(round_trip_functions)), ...
    'build_v2_mlx:roundTripMismatch', ...
    'The V2 Live Script did not preserve its embedded functions.');
[function_names, function_indentation] = function_declarations(round_trip_text);
total_function_count = numel(function_names);
script_local_count = sum(strlength(function_indentation) == 0);
nested_function_count = total_function_count - script_local_count;
assert(sum(function_names == "completed_outcome_counts") == 1, ...
    'build_v2_mlx:missingContinuedDeclaration', ...
    'The continued completed_outcome_counts declaration was not counted once.');

file_id = fopen(evidence, 'w', 'n', 'UTF-8');
assert(file_id >= 0, 'Could not record the V2 Live Script build.');
details = dir(destination);
fprintf(file_id, 'Neyer_Gap_Test_v2.mlx created by MATLAB %s.\n', ...
    version('-release'));
fprintf(file_id, 'Bytes: %d\n', details.bytes);
fprintf(file_id, 'Total function declarations: %d\n', total_function_count);
fprintf(file_id, 'Script-local functions (unindented): %d\n', ...
    script_local_count);
fprintf(file_id, 'Nested functions (indented): %d\n', ...
    nested_function_count);
fprintf(file_id, 'Embedded functions match generated source: yes\n');
fprintf(file_id, 'No public-site copy was created.\n');
fclose(file_id);
exit(0);

function delete_if_present(file_path)
if isfile(file_path), delete(file_path); end
end

function [names, indentation] = function_declarations(text)
tokens = regexp(text, ['(?m)^([ \t]*)function[ \t]+' ...
    '(?:(?:\[[^\]]+\]|[A-Za-z]\w*)[ \t]*=[ \t]*' ...
    '(?:\.\.\.[^\r\n]*\r?\n[ \t]*)?)?' ...
    '([A-Za-z]\w*)'], 'tokens');
indentation = string(cellfun(@(token) token{1}, tokens, ...
    'UniformOutput', false));
names = string(cellfun(@(token) token{2}, tokens, ...
    'UniformOutput', false));
names = names(:);
indentation = indentation(:);
end
