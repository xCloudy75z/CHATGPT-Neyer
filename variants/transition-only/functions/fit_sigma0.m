function s0 = fit_sigma0(levels)
%FIT_SIGMA0  A positive starting spread for best_fit, derived from the data.
%   Used by the reliability-at-confidence units (Mode A/B) to seed best_fit's
%   inner optimiser. Falls back to a quarter of the tested range (min 1) when the
%   sample spread is zero or undefined.  [addendum RAC / RECOMMENDATION]
    lv = levels(:);
    s0 = std(lv);
    if ~(s0 > 0 && isfinite(s0))
        s0 = max((max(lv) - min(lv)) / 4, 1);
    end
end
