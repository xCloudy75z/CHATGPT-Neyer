function [result, record] = run_test(params, num_parts, outcome_fn, cfg)
%RUN_TEST  The only entry point: check -> run -> report.
%
%   [result, record] = RUN_TEST(params, num_parts, outcome_fn, cfg) runs a Neyer
%   D-optimal sensitivity test end to end. It is pure glue: it validates the
%   inputs (worker #7), runs the loop (worker #8), and reports the answer
%   (worker #9).  [brief sec.5]
%
%   Inputs
%     params      starting guess: .avg_low, .avg_high, .spread_guess.
%     num_parts   item budget (number of destructive tests).
%     outcome_fn  (optional) result = outcome_fn(level, k): true for a break,
%                 false for a survive. If omitted, the operator is prompted at
%                 the console for each item.
%     cfg         (optional) settings struct; defaults to settings().
%
%   Outputs
%     result   struct from report (.mu, .sigma, .se_mu, .se_sigma, ...).
%     record   struct from run_loop (the full trajectory).
%
%   Example (reproduce Neyer Table 1):
%     fixed  = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
%     params = struct('avg_low', 0.6, 'avg_high', 1.4, 'spread_guess', 0.10);
%     run_test(params, 20, @(level,k) fixed(k));


    if nargin < 4 || isempty(cfg),        cfg = neyer_settings();          end
    if nargin < 3 || isempty(outcome_fn), outcome_fn = @ask_operator; end

    check_inputs(params, num_parts);               % #7
    % Adapter: the user builds params with plain-English field names; convert to
    % the internal names the sacred core (choose_stage) expects, untouched.
    internal = struct('mu_min', params.avg_low, 'mu_max', params.avg_high, ...
                      'sigma_guess', params.spread_guess);
    record = run_loop(internal, num_parts, outcome_fn, cfg);   % #8; choose_stage still sees mu_min/mu_max/sigma_guess
    result = report(record, cfg);                  % #9
end

% -------------------------------------------------------------------------
function r = ask_operator(level, k)
%ASK_OPERATOR  Default interactive outcome source: prompt the operator.
    prompt = sprintf('Test %d - set level to %.4f. Did it break? (1=break / 0=survive): ', ...
                     k, level);
    r = logical(input(prompt));
end
