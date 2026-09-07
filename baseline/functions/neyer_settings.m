
function s = neyer_settings()
%NEYER_SETTINGS  The single home for every constant the method uses.
%
%   Ground rule from the build brief: nothing is hard-coded out of sight.
%   Every number lives here with its source tagged inline as one of
%     PAPER          - straight from Neyer (1994)
%     PUBLISHED      - from other named work
%     RECOMMENDATION - an engineering judgement made during design
%   This mirrors the table in brief sec.6.
%
%   Usage:  s = settings();  then read fields, e.g. s.search_window_sigmas.

    % --- Stage 1: reach-out search (find the zone) --------------------------
    % First reach from the centre, then the offset doubles each step until both
    % a break and a survive have been seen. Both values are reconstructed to
    % reproduce Neyer Table 1 (offsets 0.2,0.4,0.8,1.6,3.2 = 2*sigma_guess
    % doubling); for the paper's inputs 2*sigma_guess also equals
    % (mu_max-mu_min)/4. brief sec.3 Stage 1 / sec.7.
    s.stage1_reach_sigmas = 2;             % RECOMMENDATION (first reach = 2*sigma_guess)
    s.stage1_growth       = 2;             % PAPER ("roughly doubling the stride each step")

    % --- Stage 2: shrink the assumed spread a little each gap-closing step ---
    % brief sec.6 / sec.3 Stage 2.
    s.stage2_shrink = 0.8;                 % PAPER (tuned by simulation; 0.8-0.85 discussed)

    % --- Stage 2: bisect-vs-probe switch ------------------------------------
    % While the survive/break bracket is wider than this many guessed spreads,
    % close the gap by bisection (test the midpoint). Once it is narrower,
    % bisection stalls, so switch to a D-optimal probe that overshoots the
    % bracket to force the first overlap. Reconstructed from Table 1: the
    % bracket goes 1.6,0.8,0.4,0.2 (bisected) then 0.1 (probed). brief sec.7.
    s.stage2_bisect_width_sigmas = 1.5;    % RECOMMENDATION (between the 2.0 and 1.0 seen in Table 1)

    % --- Most-informative offset from centre --------------------------------
    % This is an EMERGENT target used only as a sanity check; it is NOT fed
    % into the level search (the search finds it on its own). brief sec.6.
    s.most_informative_offset = 1.138;     % PAPER (in units of spread)

    % --- Candidate-search window: fence against useless extreme levels -------
    % Search within +/- this many spreads of the current centre. brief sec.6/8.
    s.search_window_sigmas = 5;            % RECOMMENDATION ("no info beyond ~3 spreads" is PAPER)

    % --- Candidate grid resolution for the level search ---------------------
    % Number of grid points across the full window. brief sec.6.
    s.grid_points = 20001;                 % RECOMMENDATION

    % --- Test stimulus resolution -------------------------------------------
    % A physical test level can only be set to finite resolution, so the chosen
    % level is rounded to this many decimals before it is tested and recorded.
    % This matches the paper's 2-decimal Table 1 (and the acceptance tolerance)
    % and prevents full-precision feedback from drifting the trajectory. sec.6/7.
    s.level_decimals = 2;                  % RECOMMENDATION

    % --- MLE clips (worker #5, sanity_clamp) --------------------------------
    s.clip_mu_to_tested_range    = true;   % PAPER (average kept within tested level range)
    s.clip_sigma_to_tested_range = true;   % PAPER (spread <= max-min tested level)

    % --- Left/right shoulder choice each step -------------------------------
    % Tie-break / balancing policy when both sides are equally informative.
    % The determinant normally picks a clear side on its own; this only
    % matters on a near-tie. brief sec.6.
    s.alternate_sides = true;              % RECOMMENDATION (keeps the answer balanced)

    % --- Acceptance-test tolerance ------------------------------------------
    s.accept_tol_decimals = 2;             % RECOMMENDATION (match to 2 decimal places)

    % --- Keep spread strictly positive inside the optimiser -----------------
    s.enforce_positive_sigma = true;       % RECOMMENDATION (reparameterise / constrain)

    % --- Tail-quantile reporting (addendum B1) ------------------------------
    % report (#9) also prints two tail levels: the all-fire level, where this
    % fraction of items break, and the no-fire level, where this fraction
    % survive. Neyer usually uses 99.9% (some use 99.99% / 99.9999%), so this
    % is an adjustable dial, not a hard-wired number. brief App.B / addendum B1.
    s.tail_fraction = 0.999;               % PAPER (all-fire ~99.9% definition); 0.999 default RECOMMENDATION

    % --- Likelihood-ratio confidence level (addendum LR) --------------------
    % Confidence level used by lr_confidence for the two-sided (mu, sigma) and
    % one-sided (all-fire, no-fire) profile-likelihood bounds.
    s.confidence_level = 0.95;             % RECOMMENDATION (industry standard)

    % --- Reliability-at-confidence presets & sample-size planner (addendum RAC) ---
    % Preset reliability ladder offered by reliability_query, powers of ten up to
    % 1-in-a-million. Free-text percentage is always accepted too.
    s.reliability_presets = [0.99 0.999 0.9999 0.99999 0.999999]; % RECOMMENDATION
    % Floor on the recommended number of tests. Below ~20 the likelihood-ratio
    % confidence bounds are not dependable (large-sample approximation), results
    % must first overlap for any fit to exist (Silvapulle), and the estimates are
    % still settling. See spec 2.4.
    s.sample_floor       = 20;    % RECOMMENDATION (LR asymptotics dependable ~>=20)
    % Planner target: the conservative one-sided margin should be within this
    % fraction of the spread (sigma) -- the natural unit the Banerjee variances
    % are expressed in -- so the bound is meaningful (finite, and for survive
    % stays above zero). The target is a fraction of sigma, NOT of the level's
    % distance-from-centre (k*sigma): tying it to k*sigma would let the target
    % grow alongside the estimate and make the required number of tests SHRINK
    % as the reliability R gets more extreme, which is backwards. See
    % plan_samples.m (banerjee basis) for the matching derivation.
    s.plan_rel_precision = 0.5;   % RECOMMENDATION

    % --- Physical floor on the tested level (addendum MINLEVEL) --------------
    % Lowest stimulus the rig can actually apply. Default -Inf = no floor, so the
    % method stays byte-for-byte pure Neyer out of the box (Table 1 gate unchanged).
    % For a real drop test set this to your rig's minimum (e.g. 0 mm): when the
    % method's chosen level falls below it, the test is done AT the floor.
    s.min_level = -Inf;   % RECOMMENDATION (set to 0 for the drop-test rig)

    % --- Display unit for heights (label only; no conversion) ----------------
    s.unit = 'mm';   % RECOMMENDATION ('mm'/'cm'/'m'/'km' or any short label)
end
