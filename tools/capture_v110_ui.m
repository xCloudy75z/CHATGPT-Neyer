function capture_v110_ui()
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'application', 'source'));
output_folder = fullfile(project_root, 'assets', 'screenshots');
evidence_path = fullfile(project_root, 'audit', 'overnight', ...
    'final-ui-capture.txt');
close_all_figures();

neyer_app();
drawnow;
main_menu = find_named_figure('Neyer Gap Test');
exportapp(main_menu, fullfile(output_folder, 'v110-01-main-menu.png'));
delete(main_menu);

planner_phase = 0;
planner_ticks = 0;
planner_watcher = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.30, ...
    'BusyMode', 'drop', 'TimerFcn', @capture_planner);
planner_cleanup = onCleanup(@() stop_timer(planner_watcher));
start(planner_watcher);
pretest_planner_ui();
stop_timer(planner_watcher);
clear planner_cleanup;
if planner_phase == 99
    error('capture_v110_ui:plannerCaptureFailed', ...
        'The planner capture timer failed; see planner-capture-timer-error.txt.');
end

test_phase = 0;
test_ticks = 0;
test_watcher = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.30, ...
    'BusyMode', 'drop', 'TimerFcn', @capture_test_windows);
test_cleanup = onCleanup(@() stop_timer(test_watcher));
start(test_watcher);
run_test_ui();
stop_timer(test_watcher);
clear test_cleanup;

demo = run_demo();
plan_input = struct( ...
    'mode', 'requirements_first', 'outcome', 'interaction', ...
    'reliability', 0.90, 'confidence', 0.95, 'accuracy_mm', 10, ...
    'interaction_gap_mm', 4, 'no_interaction_gap_mm', 6, ...
    'minimum_gap_mm', 0, 'maximum_gap_mm', 10, ...
    'previous_information', 'first_study', 'available_articles', [], ...
    'physical_setup', struct('mode', 'regular', 'increment_mm', 0.10));
clean_plan_input = validate_plan_inputs(plan_input);
reachable = reachable_gap_model(clean_plan_input.physical_setup, 0, 10);
plan = estimate_study_plan(clean_plan_input, reachable);
result = demo.result;
result.n = 400;
result.study_plan = plan;
result.checkpoint_decision = struct('status', 'complete');
result_figure = show_result(result);
drawnow;
pause(2);
exportapp(result_figure, fullfile(output_folder, 'v110-06-results.png'));
delete(result_figure);

show_manual();
drawnow;
help_figure = find_named_figure('Neyer Gap Test - Help');
exportapp(help_figure, fullfile(output_folder, 'v110-07-help.png'));
delete(help_figure);

file_id = fopen(evidence_path, 'w');
assert(file_id >= 0, 'Could not create UI-capture evidence.');
fprintf(file_id, 'Seven final MATLAB R2022b operator screens captured.\n');
fprintf(file_id, 'Main menu, planner input, planner review, test input, requested gap, results, and help.\n');
fclose(file_id);
close_all_figures();
exit(0);

    function capture_planner(~, ~)
        try
            planner_ticks = planner_ticks + 1;
            figures = findall(groot, 'Type', 'figure', 'Name', ...
                'Neyer Pre-Test Planner');
            if isempty(figures), return; end
            planner = figures(1);
            if planner_phase == 0 && planner_ticks >= 8
                drawnow;
                exportapp(planner, fullfile(output_folder, ...
                    'v110-02-planner-input.png'));
                set_dropdown_value(planner, 'interaction');
                set_number_value(planner, 'Reliability (%)', 90);
                set_number_value(planner, 'Confidence (%)', 95);
                set_number_value(planner, 'Required gap accuracy (+/- mm)', 1);
                set_number_value(planner, ...
                    'Almost-always Interaction gap (mm)', 4);
                set_number_value(planner, ...
                    'Almost-always No-interaction gap (mm)', 6);
                set_number_value(planner, 'Minimum permitted gap (mm)', 0);
                set_number_value(planner, 'Maximum permitted gap (mm)', 10);
                set_number_value(planner, 'Regular increment (mm)', 0.10);
                invoke_button(find_button(planner, 'Review plan'));
                planner_phase = 1;
                planner_ticks = 0;
            elseif planner_phase == 1 && planner_ticks >= 8
                drawnow;
                exportapp(planner, fullfile(output_folder, ...
                    'v110-03-planner-review.png'));
                invoke_button(find_button(planner, 'Close'));
                planner_phase = 2;
            end
        catch planner_error
            file_id = fopen(fullfile(project_root, 'audit', 'overnight', ...
                'planner-capture-timer-error.txt'), 'w');
            if file_id >= 0
                fprintf(file_id, '%s\n', getReport(planner_error, ...
                    'extended', 'hyperlinks', 'off'));
                fclose(file_id);
            end
            figures = findall(groot, 'Type', 'figure', 'Name', ...
                'Neyer Pre-Test Planner');
            if ~isempty(figures)
                invoke_button(find_button(figures(1), 'Close'));
            end
            planner_phase = 99;
        end
    end

    function capture_test_windows(~, ~)
        test_ticks = test_ticks + 1;
        if test_phase == 0
            settings = findall(groot, 'Type', 'figure', 'Name', ...
                'Neyer gap test - inputs');
            if isempty(settings) || test_ticks < 8, return; end
            settings_figure = settings(1);
            drawnow;
            exportapp(settings_figure, fullfile(output_folder, ...
                'v110-04-test-inputs.png'));
            fields = findall(settings_figure, 'Type', 'uieditfield');
            rows = arrayfun(@(control) control.Layout.Row, fields);
            [~, order] = sort(rows);
            fields = fields(order);
            values = {'0','10','1','20','0','mm','0.10','0.015'};
            for field_number = 1:min(numel(fields), numel(values))
                fields(field_number).Value = values{field_number};
            end
            invoke_button(find_button(settings_figure, 'Start test'));
            test_phase = 1;
            test_ticks = 0;
        elseif test_phase == 1
            gaps = findall(groot, 'Type', 'figure', 'Name', ...
                'Neyer gap test');
            if isempty(gaps) || test_ticks < 8, return; end
            gap_figure = gaps(1);
            drawnow;
            exportapp(gap_figure, fullfile(output_folder, ...
                'v110-05-requested-gap.png'));
            feval(gap_figure.CloseRequestFcn, gap_figure, []);
            test_phase = 2;
        end
    end
end

function set_dropdown_value(figure_handle, value)
dropdowns = findall(figure_handle, 'Type', 'uidropdown');
for dropdown_number = 1:numel(dropdowns)
    item_data = string(dropdowns(dropdown_number).ItemsData);
    if any(item_data == string(value))
        dropdowns(dropdown_number).Value = value;
        return;
    end
end
error('capture_v110_ui:dropdownNotFound', ...
    'Could not find the required planner choice: %s', value);
end

function set_number_value(figure_handle, label_text, value)
labels = findall(figure_handle, 'Type', 'uilabel');
label_match = labels(arrayfun(@(label) strcmp(label.Text, label_text), labels));
if isempty(label_match)
    error('capture_v110_ui:labelNotFound', ...
        'Could not find the planner label: %s', label_text);
end
label = label_match(1);
objects = findall(label.Parent);
for object_number = 1:numel(objects)
    candidate = objects(object_number);
    if isprop(candidate, 'Value') && isnumeric(candidate.Value) && ...
            isscalar(candidate.Value) && isprop(candidate, 'Layout') && ...
            isequal(candidate.Layout.Row, label.Layout.Row)
        candidate.Value = value;
        return;
    end
end
error('capture_v110_ui:fieldNotFound', ...
    'Could not find the planner field: %s', label_text);
end

function figure_handle = find_named_figure(name)
figures = findall(groot, 'Type', 'figure', 'Name', name);
if isempty(figures)
    error('capture_v110_ui:missingFigure', 'Screen did not open: %s', name);
end
figure_handle = figures(1);
end

function button = find_button(figure_handle, text)
buttons = findall(figure_handle, 'Type', 'uibutton');
match = arrayfun(@(candidate) strcmp(candidate.Text, text), buttons);
button = buttons(match);
if isempty(button)
    error('capture_v110_ui:missingButton', 'Button not found: %s', text);
end
button = button(1);
end

function invoke_button(button)
feval(button.ButtonPushedFcn, button, []);
end

function stop_timer(watcher)
if isvalid(watcher)
    if strcmp(watcher.Running, 'on'), stop(watcher); end
    delete(watcher);
end
end

function close_all_figures()
figures = findall(groot, 'Type', 'figure');
if ~isempty(figures), delete(figures); end
end
