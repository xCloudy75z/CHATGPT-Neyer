function [mu_c, sigma_c] = sanity_clamp(mu, sigma, levels, cfg)
%SANITY_CLAMP  Worker #5 — rein in wild best-fits on few results.
%
%   [mu_c, sigma_c] = SANITY_CLAMP(mu, sigma, levels, cfg) keeps an estimate
%   physically sensible when only a handful of results are in:
%     * the average is kept inside the range of levels actually tested, and
%     * the spread is kept no wider than that range (max - min tested level).
%   [brief sec.4 worker #5; sec.6 (both MLE clips); sec.8 #3 -- Neyer specifies
%   exactly this]
%
%   Inputs
%     mu, sigma  the raw best-fit (e.g. straight from worker #2).
%     levels     the test levels run so far (defines the sensible range).
%     cfg        settings struct (optional; defaults to settings()). Honours
%                cfg.clip_mu_to_tested_range and cfg.clip_sigma_to_tested_range
%                so each clip can be turned off independently.
%
%   Outputs
%     mu_c, sigma_c  the clamped estimate.
%
%   Example (acceptance table, going into test 12): the raw MLE from tests
%   1..11 is mu=4.2995, sigma=0.1932; the tested range is [1.00, 4.28], so mu
%   clamps to 4.28 and sigma is left as 0.19 -- the table's "clipped MLE".

    if nargin < 4 || isempty(cfg), cfg = neyer_settings(); end

    levels = levels(:);

    mu_c    = mu;
    sigma_c = sigma;

    if isempty(levels)
        return;   % nothing tested yet -> no range to clamp against
    end

    lo  = min(levels);
    hi  = max(levels);
    rng = hi - lo;

    % Average kept within the tested level range.
    if cfg.clip_mu_to_tested_range
        mu_c = min(max(mu, lo), hi);
    end

    % Spread kept no wider than the tested range (only meaningful if the
    % levels actually span a range; a positive spread is never clamped to 0).
    if cfg.clip_sigma_to_tested_range && rng > 0
        sigma_c = min(sigma, rng);
    end
end
