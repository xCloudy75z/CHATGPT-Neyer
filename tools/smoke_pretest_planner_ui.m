function smoke_pretest_planner_ui()
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
output_path = fullfile(project_root, 'assets', 'screenshots', ...
    'v110-pretest-planner-scratch.png');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'planner-ui-launch.txt');
tick_count = 0;
watcher = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
    'BusyMode', 'drop', 'TimerFcn', @capture_and_close);
cleanup_timer = onCleanup(@() stop_timer(watcher));
start(watcher);
try
    pretest_planner_ui();
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'Planner UI opened, rendered, and closed in MATLAB %s.\n', version);
    fclose(file_id);
catch ui_error
    file_id = fopen(evidence_path, 'w');
    fprintf(file_id, 'PLANNER UI ERROR\n%s\n', ...
        getReport(ui_error, 'extended', 'hyperlinks', 'off'));
    fclose(file_id);
end
stop_timer(watcher);
clear cleanup_timer;
exit(0);

    function capture_and_close(~, ~)
        tick_count = tick_count + 1;
        if tick_count < 32, return; end
        figures = findall(groot, 'Type', 'figure', 'Name', ...
            'Neyer Pre-Test Planner');
        if isempty(figures), return; end
        planner = figures(1);
        drawnow;
        pause(1);
        exportapp(planner, output_path);
        feval(planner.CloseRequestFcn, planner, []);
    end
end

function stop_timer(watcher)
if isvalid(watcher)
    if strcmp(watcher.Running, 'on'), stop(watcher); end
    delete(watcher);
end
end
