function capture_v2_results()
%CAPTURE_V2_RESULTS Save the unfinished and calculated V2 result screens.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'application', 'source'));
outputFolder = fullfile(v2_audit_folder(projectRoot), 'ui');
if ~isfolder(outputFolder), mkdir(outputFolder); end
delete(findall(groot, 'Type', 'figure'));

unfinishedFigure = show_result(unfinished_result());
drawnow;
exportapp(unfinishedFigure, fullfile(outputFolder, ...
    '04-unfinished-result.png'));
delete(unfinishedFigure);

demo = run_demo();
calculatedFigure = show_result(demo.result);
drawnow;
exportapp(calculatedFigure, fullfile(outputFolder, ...
    '05-calculated-result.png'));
delete(calculatedFigure);

markerPath = fullfile(outputFolder, 'capture-complete.txt');
fileId = fopen(markerPath, 'w');
assert(fileId >= 0, 'Could not write the V2 result capture marker.');
cleanupFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, ...
    'Unfinished and calculated V2 results captured in MATLAB %s.\n', ...
    version('-release'));
fprintf('V2 RESULT CAPTURE: two screens saved.\n');
end

function result = unfinished_result()
result = struct( ...
    'has_overlap', false, 'status', 'complete', 'stop_reason', '', ...
    'n', 3, 'unit', 'mm', 'levels', [5.50; 3.30; 1.10], ...
    'successes', logical([0; 0; 1]), ...
    'requested_levels', [5.50; 3.30; 1.10], ...
    'measurements', {{5.50, 3.30, 1.10}}, ...
    'mu', NaN, 'mu_lo', NaN, 'mu_hi', NaN, ...
    'sigma', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
    'confidence_level', 0.95, 'tail_fraction', 0.999);
end
