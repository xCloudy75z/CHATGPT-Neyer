function s = format_result_text(result)
%FORMAT_RESULT_TEXT  Pure: turn a report `result` into the plain-language popup text.
%   s = FORMAT_RESULT_TEXT(result) returns a multi-line char array, reusing the
%   numbers already on `result` (no re-estimation; report.m untouched). If results
%   have not overlapped, returns a single "no result" line. [addendum POPUP]
    if ~isfield(result,'has_overlap') || ~result.has_overlap || isnan(result.mu)
        if isfield(result,'status') && strcmp(result.status,'paused')
            s = 'PAUSED - REVIEW REQUIRED. Completed test data are saved; do not continue automatically.';
        else
            s = 'No result yet - results have not overlapped. Run more tests.';
        end
        return;
    end
    cc = 100 * result.confidence_level;
    pc = 100 * result.tail_fraction;
    lines = {
        sprintf('Tests used: %d', result.n)
        ''
        sprintf('MIDDLE GAP (about 50%% interaction): %.4f', result.mu)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.mu_lo, result.mu_hi)
        ''
        sprintf('TRANSITION WIDTH: %.4f', result.sigma)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.sigma_lo, result.sigma_hi)
        ''
        sprintf('HIGH-INTERACTION GAP (about %.4g%% interaction): %.4f', pc, result.high_interaction_gap)
        sprintf('NEGLIGIBLE-INTERACTION GAP (about %.4g%% no interaction): %.4f', pc, result.negligible_interaction_gap)
        ''
        'Smaller gaps make interaction more likely; larger gaps make it less likely.'
    };
    s = strjoin(lines, sprintf('\n'));
end
