function answer = v113_independent_oracle(gaps, interaction, candidateGaps, confidence, fixedGaps)
%V113_INDEPENDENT_ORACLE Recalculate V1.13 results without its math helpers.
% This audit-only implementation intentionally does not call the production
% likelihood, fit, information, confidence, or reliability functions.

gaps = gaps(:);
interaction = logical(interaction(:));
candidateGaps = candidateGaps(:);
fixedGaps = fixedGaps(:);
if numel(gaps) ~= numel(interaction) || isempty(gaps)
    error('v113_independent_oracle:badHistory', ...
        'Gap and outcome histories must be nonempty and the same length.');
end
if ~(isscalar(confidence) && isfinite(confidence) && ...
        confidence > 0 && confidence < 1)
    error('v113_independent_oracle:badConfidence', ...
        'Confidence must be one number between 0 and 1.');
end
if isempty(gaps(interaction)) || isempty(gaps(~interaction)) || ...
        max(gaps(interaction)) <= min(gaps(~interaction))
    error('v113_independent_oracle:noOverlap', ...
        'Independent fitting requires strictly overlapping outcomes.');
end

[middleGap, overallVariation, maximumLogLikelihood] = independent_fit( ...
    gaps, interaction);

answer = struct();
answer.mu = middleGap;
answer.sigma = overallVariation;
answer.log_likelihood = maximumLogLikelihood;

if isempty(fixedGaps)
    answer.interaction_probability = zeros(0, 1);
    answer.no_interaction_probability = zeros(0, 1);
else
    standardized = (middleGap - fixedGaps) ./ overallVariation;
    answer.interaction_probability = 0.5 .* erfc(-standardized ./ sqrt(2));
    answer.no_interaction_probability = 0.5 .* erfc(standardized ./ sqrt(2));
end

if isempty(candidateGaps)
    answer.candidate_determinants = zeros(0, 1);
    answer.d_optimal_gap = NaN;
else
    [history0, history1, history2] = independent_information( ...
        gaps, middleGap, overallVariation);
    [candidate0, candidate1, candidate2] = independent_information( ...
        candidateGaps, middleGap, overallVariation);
    determinants = (sum(history0) + candidate0) .* ...
        (sum(history2) + candidate2) - ...
        (sum(history1) + candidate1).^2;
    [~, winner] = max(determinants);
    answer.candidate_determinants = determinants;
    answer.d_optimal_gap = candidateGaps(winner);
end

testedRange = max(gaps) - min(gaps);
twoSidedThreshold = (sqrt(2) * erfinv(confidence))^2;
profileMiddle = @(value) profile_middle(gaps, interaction, value, ...
    overallVariation);
profileVariation = @(value) profile_variation(gaps, interaction, value, ...
    middleGap);
middleStatistic = @(value) 2 * (maximumLogLikelihood - profileMiddle(value));
variationStatistic = @(value) 2 * (maximumLogLikelihood - profileVariation(value));

middleLower = crossing_root(middleStatistic, middleGap, -1, ...
    twoSidedThreshold, testedRange / 200, 5 * testedRange, -Inf);
middleUpper = crossing_root(middleStatistic, middleGap, +1, ...
    twoSidedThreshold, testedRange / 200, 5 * testedRange, +Inf);
variationLower = crossing_root(variationStatistic, overallVariation, -1, ...
    twoSidedThreshold, overallVariation / 50, ...
    overallVariation - 1e-8, 1e-8);
variationUpper = crossing_root(variationStatistic, overallVariation, +1, ...
    twoSidedThreshold, overallVariation / 50, 5 * testedRange, +Inf);
answer.mu_ci = [middleLower middleUpper];
answer.sigma_ci = [variationLower variationUpper];
end

function [middleGap, overallVariation, maximumLogLikelihood] = independent_fit(gaps, interaction)
testedRange = max(gaps) - min(gaps);
middleStarts = [mean(gaps), median(gaps), ...
    (max(gaps(interaction)) + min(gaps(~interaction))) / 2];
variationStarts = unique(max([std(gaps), testedRange / 4, ...
    testedRange / 2, testedRange / 10], 1e-3));
options = optimset('Display', 'off', 'TolX', 1e-11, 'TolFun', 1e-13, ...
    'MaxFunEvals', 2e5, 'MaxIter', 2e5);
bestObjective = Inf;
bestParameters = [middleStarts(1), log(variationStarts(1))];
for middleStart = middleStarts
    for variationStart = variationStarts
        initial = [middleStart, log(variationStart)];
        [candidate, objective] = fminsearch( ...
            @(parameters) independent_negative_log_likelihood( ...
            parameters, gaps, interaction), initial, options);
        if isfinite(objective) && objective < bestObjective
            bestObjective = objective;
            bestParameters = candidate;
        end
    end
end
middleGap = bestParameters(1);
overallVariation = exp(bestParameters(2));
maximumLogLikelihood = -bestObjective;
end

function negativeLogLikelihood = independent_negative_log_likelihood(parameters, gaps, interaction)
middleGap = parameters(1);
overallVariation = exp(parameters(2));
standardized = (middleGap - gaps) ./ overallVariation;
interactionChance = max(0.5 .* erfc(-standardized ./ sqrt(2)), realmin);
noInteractionChance = max(0.5 .* erfc(standardized ./ sqrt(2)), realmin);
negativeLogLikelihood = -(sum(log(interactionChance(interaction))) + ...
    sum(log(noInteractionChance(~interaction))));
end

function [term0, term1, term2] = independent_information(gaps, middleGap, overallVariation)
standardized = (middleGap - gaps) ./ overallVariation;
density = exp(-0.5 .* standardized.^2) ./ sqrt(2 * pi);
interactionChance = 0.5 .* erfc(-standardized ./ sqrt(2));
noInteractionChance = 0.5 .* erfc(standardized ./ sqrt(2));
base = density.^2 ./ (interactionChance .* noInteractionChance .* overallVariation.^2);
base(~isfinite(base)) = 0;
term0 = base;
term1 = base .* standardized;
term2 = base .* standardized.^2;
end

function value = profile_middle(gaps, interaction, fixedMiddle, variationStart)
options = optimset('Display', 'off', 'TolX', 1e-10, 'TolFun', 1e-12, ...
    'MaxFunEvals', 1e5, 'MaxIter', 1e5);
objective = @(logVariation) independent_negative_log_likelihood( ...
    [fixedMiddle, logVariation], gaps, interaction);
bestLogVariation = fminsearch(objective, log(variationStart), options);
value = -objective(bestLogVariation);
end

function value = profile_variation(gaps, interaction, fixedVariation, middleStart)
options = optimset('Display', 'off', 'TolX', 1e-10, 'TolFun', 1e-12, ...
    'MaxFunEvals', 1e5, 'MaxIter', 1e5);
objective = @(middleGap) independent_negative_log_likelihood( ...
    [middleGap, log(fixedVariation)], gaps, interaction);
bestMiddle = fminsearch(objective, middleStart, options);
value = -objective(bestMiddle);
end

function root = crossing_root(statistic, center, direction, target, firstStep, maximumDistance, hardLimit)
root = NaN;
if ~(maximumDistance > 0) || ~(firstStep > 0)
    return;
end
distances = unique([0; logspace(log10(firstStep), ...
    log10(maximumDistance), 180)']);
previousPoint = center;
previousDifference = statistic(previousPoint) - target;
for index = 2:numel(distances)
    point = center + direction * distances(index);
    if direction < 0 && isfinite(hardLimit)
        point = max(point, hardLimit);
    elseif direction > 0 && isfinite(hardLimit)
        point = min(point, hardLimit);
    end
    difference = statistic(point) - target;
    if isfinite(difference) && difference >= 0 && previousDifference <= 0
        bracket = sort([previousPoint, point]);
        root = fzero(@(value) statistic(value) - target, bracket);
        return;
    end
    previousPoint = point;
    previousDifference = difference;
    if point == hardLimit
        return;
    end
end
end
