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
    decision = result_decision_summary(result);
    if decision.supported
        decision_lines = { ...
            'SUPPORTED OPERATING INSTRUCTION'
            decision.operating_instruction
            char(decision.physical_build_instruction)};
    else
        decision_lines = { ...
            'SUPPORTED OPERATING INSTRUCTION: Not established'
            decision.explanation};
    end
    result_lines = {
        ''
        sprintf('Tests used: %d', result.n)
        ''
        sprintf('MIDDLE GAP (about 50%% interaction): %.2f mm', result.mu)
        sprintf('  %.4g%% confident it is between %.2f and %.2f mm', cc, result.mu_lo, result.mu_hi)
        ''
        sprintf('OVERALL VARIATION: %.2f mm', result.sigma)
        sprintf('  %.4g%% confident it is between %.2f and %.2f mm', cc, result.sigma_lo, result.sigma_hi)
        '  This describes how much the entire tested process varies from article to article.'
        ''
        'Smaller gaps make interaction more likely; larger gaps make it less likely.'
    };
    lines = [decision_lines(:); result_lines(:)];
    s = strjoin(lines, sprintf('\n'));
end
