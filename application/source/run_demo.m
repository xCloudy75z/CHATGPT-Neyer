function d = run_demo()
%RUN_DEMO Replay Neyer's published example in decreasing-gap terminology.
%   The paper's increasing-response outcomes are mirrored so true means
%   interaction at a smaller gap. This preserves the published test levels and
%   fitted gate (5.3922 / 1.0412) while exercising the V1.9 gap direction.
%   Returns a struct: .result (the run), .expected_mu, .expected_sigma,
%   .got_mu, .got_sigma, .is_match, .tol. [compiled-app]
    paperOutcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    fixed = ~paperOutcomes;
    params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
    result = run_test(params, 20, @(level, k) fixed(k));

    tol = 1e-3;                       % published values are 4 d.p.
    d = struct();
    d.result         = result;
    d.expected_mu    = 5.3922;
    d.expected_sigma = 1.0412;
    d.got_mu         = result.mu;
    d.got_sigma      = result.sigma;
    d.tol            = tol;
    d.is_match       = abs(result.mu - d.expected_mu) <= tol && ...
                       abs(result.sigma - d.expected_sigma) <= tol;
end
