project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root,'application','source'));
addpath(fullfile(project_root,'tools'));
setappdata(groot,'v111_one_reading_ui_checked',false);
setappdata(groot,'v111_one_reading_ui_error', ...
    'The one-reading workflow did not finish.');
setappdata(groot,'v111_ui_screen_path',fullfile(project_root,'assets', ...
    'screenshots','v111-05-one-measured-gap.png'));

ui_timer = timer('StartDelay',0.25,'ExecutionMode','fixedSpacing', ...
    'Period',0.25,'TasksToExecute',80, ...
    'TimerFcn',@verify_v111_one_reading_ui_callback, ...
    'StopFcn',@verify_v111_one_reading_ui_timeout);
timer_cleanup = onCleanup(@() stop_and_delete_timer(ui_timer)); %#ok<NASGU>
start(ui_timer);
run_test_ui([],[]);
wait_start = tic;
while ~getappdata(groot,'v111_one_reading_ui_checked') && toc(wait_start) < 5
    drawnow;
    pause(0.1);
end

if ~getappdata(groot,'v111_one_reading_ui_checked')
    error('verify_v111_one_reading_ui:notCompleted','%s', ...
        getappdata(groot,'v111_one_reading_ui_error'));
end

evidence_path = fullfile(project_root,'audit','v111','one-reading-ui.txt');
file_id = fopen(evidence_path,'w');
assert(file_id >= 0,'Could not record the one-reading UI evidence.');
fprintf(file_id,'MATLAB %s one-reading direct UI check passed.\n', ...
    version('-release'));
fprintf(file_id,'The physical screen requested one measured gap.\n');
fprintf(file_id,'The example contained one value: 2.507.\n');
fprintf(file_id,['A measured gap of 5.007 was accepted once per setup ' ...
    'in the smallest valid three-article run, and the result screen opened.\n']);
fclose(file_id);
exit(0);

function stop_and_delete_timer(timer_object)
if isvalid(timer_object)
    stop(timer_object);
    delete(timer_object);
end
end

function verify_v111_one_reading_ui_timeout(varargin) %#ok<INUSD>
if getappdata(groot,'v111_one_reading_ui_checked'), return; end
detail = '';
if isappdata(groot,'v111_one_reading_ui_last_transient')
    detail = getappdata(groot,'v111_one_reading_ui_last_transient');
end
setappdata(groot,'v111_one_reading_ui_error', ...
    sprintf('The UI did not complete within 20 seconds. Last detail: %s',detail));
figures = findall(groot,'Type','figure');
if ~isempty(figures), delete(figures); end
end
