function scale = automatic_search_scale(low_middle_guess, high_middle_guess, ...
        reachable_spacing, permitted_width)
%AUTOMATIC_SEARCH_SCALE Choose only an internal starting scale for a first study.
% This is not a measured variation and is not reported as the final sigma.

values = [low_middle_guess, high_middle_guess, reachable_spacing, permitted_width];
if any(~isfinite(values)) || high_middle_guess <= low_middle_guess || ...
        reachable_spacing <= 0 || permitted_width <= 0
    error('automatic_search_scale:badInputs', ...
        ['The middle-gap guesses, permitted range, and reachable spacing ' ...
         'must be valid positive values.']);
end
middle_range = high_middle_guess - low_middle_guess;
scale = max(middle_range / 6, reachable_spacing);
scale = min(scale, permitted_width);
end
