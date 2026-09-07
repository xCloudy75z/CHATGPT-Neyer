function s = format_result_text(result)
%FORMAT_RESULT_TEXT  Pure: turn a report `result` into the plain-language popup text.
%   s = FORMAT_RESULT_TEXT(result) returns a multi-line char array, reusing the
%   numbers already on `result` (no re-estimation; report.m untouched). If results
%   have not overlapped, returns a single "no result" line. [addendum POPUP]
    if ~isfield(result,'has_overlap') || ~result.has_overlap || isnan(result.mu)
        s = 'No result yet - results have not overlapped. Run more parts.';
        return;
    end
    cc = 100 * result.confidence_level;
    pc = 100 * result.tail_fraction;
    lines = {
        sprintf('Tests used: %d', result.n)
        ''
        sprintf('AVERAGE breaking height: %.4f', result.mu)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.mu_lo, result.mu_hi)
        ''
        sprintf('SPREAD (part-to-part variation): %.4f', result.sigma)
        sprintf('  %.4g%% confident it is between %.4f and %.4f', cc, result.sigma_lo, result.sigma_hi)
        ''
        sprintf('ALL-FIRE height (%.4g%% break): %.4f', pc, result.all_fire)
        sprintf('NO-FIRE height (%.4g%% survive): %.4f', pc, result.no_fire)
        ''
        'For reliability at a height, run reliability_query(result).'
    };
    s = strjoin(lines, sprintf('\n'));
end
