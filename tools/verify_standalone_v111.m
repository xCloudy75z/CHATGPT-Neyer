project_root = fileparts(fileparts(mfilename('fullpath')));
live_script = fullfile(project_root,'delivery','Neyer_Gap_Test_v1_12.mlx');
build_source = fullfile(project_root,'delivery','Neyer_Gap_Test_v1_12.m');
evidence_path = fullfile(project_root,'audit','v112','standalone-clean-start.txt');
temporary_folder = tempname;
mkdir(temporary_folder);

original_folder = pwd;
original_path = path;
cleanup = onCleanup(@() restore_environment(original_folder, ...
    original_path,temporary_folder));

if ~isfile(live_script) || ~isfile(build_source)
    error('verify_standalone_v111:missingFile', ...
        'The V1.12 Live Script or its reviewed build source is missing.');
end
exported_source = fullfile(temporary_folder,'exported_v112.m');
matlab.internal.liveeditor.openAndConvert(live_script,exported_source);
exported_text = fileread(exported_source);
built_text = fileread(build_source);
exported_functions = regexp(exported_text,'(?ms)^function\s.*\z','match','once');
built_functions = regexp(built_text,'(?ms)^function\s.*\z','match','once');
normalise = @(text) strtrim(strrep(text,sprintf('\r\n'),sprintf('\n')));
if ~strcmp(normalise(exported_functions),normalise(built_functions))
    error('verify_standalone_v111:embeddedSourceMismatch', ...
        'The functions embedded in the Live Script differ from the reviewed source.');
end
embedded_count = numel(regexp(exported_text,'(?m)^function\s','match'));

isolated_live_script = fullfile(temporary_folder,'Neyer_Gap_Test_v1_12.mlx');
copyfile(live_script,isolated_live_script);
delete(exported_source);
folder_contents = dir(temporary_folder);
folder_contents = folder_contents(~ismember({folder_contents.name},{'.','..'}));
if numel(folder_contents) ~= 1
    error('verify_standalone_v111:notIsolated', ...
        'The clean-start folder must contain only the V1.12 Live Script.');
end

restoredefaultpath;
cd(temporary_folder);
run(isolated_live_script);
drawnow;
menu_figure = findall(groot,'Type','figure','Name','Neyer Gap Test');
if isempty(menu_figure)
    error('verify_standalone_v111:noMenu', ...
        'The isolated Live Script did not open the application menu.');
end
buttons = findall(menu_figure(1),'Type','uibutton');
demo_button = buttons(arrayfun(@(button) strcmp(button.Text, ...
    'Run the published example'),buttons));
if numel(demo_button) ~= 1
    error('verify_standalone_v111:noDemo','The example button was not found.');
end
feval(demo_button.ButtonPushedFcn,demo_button,[]);
result_figure = [];
wait_start = tic;
while isempty(result_figure) && toc(wait_start) < 5
    drawnow;
    pause(0.1);
    result_figure = findall(groot,'Type','figure', ...
        'Name','Neyer gap-study results');
end
if isempty(result_figure)
    detail = 'No hidden demo error was recorded.';
    menu_state = menu_figure(1).UserData;
    if isstruct(menu_state) && isfield(menu_state,'demo_error_message')
        detail = sprintf('%s: %s',menu_state.demo_error_identifier, ...
            menu_state.demo_error_message);
    end
    error('verify_standalone_v111:noResult', ...
        'The embedded published example did not open its result screen. %s',detail);
end
labels = findall(result_figure(1),'Type','uilabel');
label_text = string({labels.Text});
if ~any(contains(label_text,'5.39')) || ~any(contains(label_text,'1.04'))
    error('verify_standalone_v111:wrongDemoResult', ...
        'The example did not display middle 5.39 and variation 1.04.');
end

file_id = fopen(evidence_path,'w');
assert(file_id >= 0,'Could not record the clean-start evidence.');
fprintf(file_id,'MATLAB %s isolated V1.12 Live Script verification passed.\n', ...
    version('-release'));
fprintf(file_id,'The temporary folder contained only Neyer_Gap_Test_v1_12.mlx.\n');
fprintf(file_id,'Embedded local functions: %d\n',embedded_count);
fprintf(file_id,'Embedded functions match the reviewed build source exactly.\n');
fprintf(file_id,'Published example displayed middle 5.39 and variation 1.04.\n');
fclose(file_id);
exit(0);

function restore_environment(original_folder,original_path,temporary_folder)
figures = findall(groot,'Type','figure');
if ~isempty(figures), delete(figures); end
path(original_path);
cd(original_folder);
if isfolder(temporary_folder), rmdir(temporary_folder,'s'); end
end
