project_root = fileparts(fileparts(mfilename('fullpath')));
live_script = fullfile(project_root, 'delivery', ...
    'Neyer_Gap_Test_v1_10.mlx');
build_source = fullfile(project_root, 'delivery', ...
    'Neyer_Gap_Test_v1_10.m');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'standalone-clean-start.txt');
temporary_folder = tempname;
mkdir(temporary_folder);

original_folder = pwd;
original_path = path;
cleanup = onCleanup(@() restore_environment(original_folder, ...
    original_path, temporary_folder));

if ~isfile(live_script)
    error('verify_standalone_v110:missingLiveScript', ...
        'The v1.10 Live Script is missing.');
end
if ~isfile(build_source)
    error('verify_standalone_v110:missingBuildSource', ...
        'The generated review source is missing.');
end

exported_source = fullfile(temporary_folder, 'exported_v110.m');
matlab.internal.liveeditor.openAndConvert(live_script, exported_source);
exported_text = fileread(exported_source);
built_text = fileread(build_source);
exported_functions = regexp(exported_text, '(?ms)^function\s.*\z', ...
    'match', 'once');
built_functions = regexp(built_text, '(?ms)^function\s.*\z', ...
    'match', 'once');
normalise = @(text) strtrim(strrep(text, sprintf('\r\n'), sprintf('\n')));
if ~strcmp(normalise(exported_functions), normalise(built_functions))
    error('verify_standalone_v110:embeddedSourceMismatch', ...
        'The functions embedded in the Live Script differ from the reviewed build source.');
end
embedded_count = numel(regexp(exported_text, '(?m)^function\s', 'match'));

isolated_live_script = fullfile(temporary_folder, ...
    'Neyer_Gap_Test_v1_10.mlx');
copyfile(live_script, isolated_live_script);
delete(exported_source);
folder_contents = dir(temporary_folder);
folder_contents = folder_contents(~ismember({folder_contents.name}, {'.','..'}));
if numel(folder_contents) ~= 1 || ...
        ~strcmp(folder_contents(1).name, 'Neyer_Gap_Test_v1_10.mlx')
    error('verify_standalone_v110:notIsolated', ...
        'The clean-start folder must contain only the Live Script.');
end

restoredefaultpath;
cd(temporary_folder);
run(isolated_live_script);
drawnow;

menu_figure = findall(groot, 'Type', 'figure', 'Name', 'Neyer Gap Test');
if isempty(menu_figure)
    error('verify_standalone_v110:noMenu', ...
        'The isolated Live Script did not open the Neyer Gap Test menu.');
end
buttons = findall(menu_figure(1), 'Type', 'uibutton');
is_demo = arrayfun(@(button) strcmp(button.Text, ...
    'Run the published example'), buttons);
if ~any(is_demo)
    error('verify_standalone_v110:noDemo', ...
        'The published-example button was not found.');
end
demo_button = buttons(find(is_demo, 1));
feval(demo_button.ButtonPushedFcn, demo_button, []);
drawnow;

result_figure = findall(groot, 'Type', 'figure', ...
    'Name', 'Neyer gap-study results');
if isempty(result_figure)
    diagnostic = '';
    if isstruct(menu_figure(1).UserData) && ...
            isfield(menu_figure(1).UserData, 'demo_error_message')
        diagnostic = sprintf(' Internal error: %s (%s)', ...
            menu_figure(1).UserData.demo_error_message, ...
            menu_figure(1).UserData.demo_error_identifier);
    end
    error('verify_standalone_v110:noResult', ...
        'The embedded published example did not open its result screen.%s', ...
        diagnostic);
end
labels = findall(result_figure(1), 'Type', 'uilabel');
label_text = string({labels.Text});
if ~any(contains(label_text, '5.39')) || ...
        ~any(contains(label_text, '1.04'))
    error('verify_standalone_v110:wrongDemoResult', ...
        'The published example did not display middle gap 5.39 and overall variation 1.04.');
end

file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not record the standalone clean-start evidence.');
fprintf(file_id, 'MATLAB %s isolated Live Script verification passed.\n', ...
    version('-release'));
fprintf(file_id, 'The temporary folder contained only Neyer_Gap_Test_v1_10.mlx.\n');
fprintf(file_id, 'Embedded local functions: %d\n', embedded_count);
fprintf(file_id, 'Embedded functions match the reviewed build source exactly.\n');
fprintf(file_id, 'Published example displayed middle gap 5.39 and overall variation 1.04.\n');
fclose(file_id);
exit(0);

function restore_environment(original_folder, original_path, temporary_folder)
    figures = findall(groot, 'Type', 'figure');
    if ~isempty(figures)
        delete(figures);
    end
    path(original_path);
    cd(original_folder);
    if isfolder(temporary_folder)
        rmdir(temporary_folder, 's');
    end
end
