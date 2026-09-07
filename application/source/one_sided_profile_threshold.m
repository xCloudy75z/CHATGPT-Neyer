function threshold = one_sided_profile_threshold(confidence)
%ONE_SIDED_PROFILE_THRESHOLD Monotonic likelihood threshold for a lower bound.
% At 50% confidence the cautious boundary is the best estimate. A requested
% confidence below 50% must not accidentally become a stronger claim, so it
% remains at that same estimate. Above 50%, caution increases continuously.
    if ~(isnumeric(confidence) && isscalar(confidence) && isreal(confidence) && ...
            isfinite(confidence) && confidence > 0 && confidence < 1)
        error('one_sided_profile_threshold:badConfidence', ...
            'Confidence must be one number between 0 and 1.');
    end
    signed_distance = shape_model(confidence, 'quantile');
    threshold = max(signed_distance, 0)^2;
end
