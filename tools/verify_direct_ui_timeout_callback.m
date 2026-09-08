function verify_direct_ui_timeout_callback(varargin) %#ok<INUSD>
%VERIFY_DIRECT_UI_TIMEOUT_CALLBACK End the smoke check cleanly if UI never settles.
    if getappdata(groot, 'direct_ui_checked'), return; end
    setappdata(groot, 'direct_ui_error', ...
        'The direct-test settings window did not finish loading within 15 seconds.');
    settings_figure = findall(groot, 'Type', 'figure', ...
        'Name', 'Neyer gap test - inputs');
    if ~isempty(settings_figure), delete(settings_figure); end
end
