function check_inputs(params, num_parts)
%CHECK_INPUTS  Worker #7 — refuse bad starting guesses up front.
%
%   CHECK_INPUTS(params, num_parts) validates the run configuration and throws a
%   clear error if anything is wrong, so the method never starts from a
%   nonsensical state. It is the first thing run_test does.  [brief sec.4 worker #7]
%
%   Requirements:
%     * params.avg_low < params.avg_high       (a real bracket on the average)
%     * params.spread_guess > 0  and finite    (a positive guessed spread)
%     * num_parts a positive integer >= 3       (a sensible item budget; two
%                                              parameters cannot be pinned from
%                                              fewer than a few destructive tests)
%
%   All three bounds are finite real scalars. On success the function returns
%   quietly; on failure it errors with an identifier under "check_inputs:".

    % --- params must carry the three fields -------------------------------
    needed = {'avg_low', 'avg_high', 'spread_guess'};
    for i = 1:numel(needed)
        if ~isfield(params, needed{i})
            error('check_inputs:missingField', ...
                  'params is missing required field "%s".', needed{i});
        end
    end

    avg_low  = params.avg_low;
    avg_high = params.avg_high;
    sg       = params.spread_guess;

    % --- each bound a finite real scalar ----------------------------------
    check_scalar(avg_low,  'avg_low');
    check_scalar(avg_high, 'avg_high');
    check_scalar(sg,       'spread_guess');

    % --- the actual sanity rules ------------------------------------------
    if ~(avg_low < avg_high)
        error('check_inputs:badBounds', ...
              'avg_low (%.4g) must be strictly less than avg_high (%.4g).', avg_low, avg_high);
    end
    if ~(sg > 0)
        error('check_inputs:badSigma', ...
              'spread_guess (%.4g) must be strictly positive.', sg);
    end

    if ~isscalar(num_parts) || ~isreal(num_parts) || ~isfinite(num_parts) || num_parts ~= floor(num_parts)
        error('check_inputs:badBudget', ...
              'num_parts must be a finite integer.');
    end
    if num_parts < 3
        error('check_inputs:budgetTooSmall', ...
              'num_parts (%d) is too small; need at least 3 tests to estimate two parameters.', num_parts);
    end
end

% -------------------------------------------------------------------------
function check_scalar(v, name)
    if ~isscalar(v) || ~isreal(v) || ~isfinite(v)
        error('check_inputs:notFiniteScalar', ...
              '%s must be a finite real scalar.', name);
    end
end
