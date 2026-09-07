classdef TestResultDecision < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function interactionInstructionUsesGapOrSmaller(testCase)
            result = resultWithPlan('interaction', 0.90);
            summary = result_decision_summary(result);
            testCase.verifyTrue(summary.supported);
            testCase.verifySubstring(lower(summary.operating_instruction), ...
                'or smaller');
            testCase.verifyEqual(summary.display_gap, ...
                string(sprintf('%.2f mm', summary.reachable_gap_mm)));
        end

        function noInteractionInstructionUsesGapOrLarger(testCase)
            result = resultWithPlan('no_interaction', 0.90);
            summary = result_decision_summary(result);
            testCase.verifyTrue(summary.supported);
            testCase.verifySubstring(lower(summary.operating_instruction), ...
                'or larger');
        end

        function outOfRangeBoundaryIsNotPresentedAsUsable(testCase)
            result = resultWithPlan('interaction', 0.999);
            summary = result_decision_summary(result);
            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.display_gap, "Not established");
            testCase.verifySubstring(lower(summary.explanation), ...
                'permitted range');
        end

        function unplannedResultIsClearlyEstimateOnly(testCase)
            result = referenceResult();
            summary = result_decision_summary(result);
            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.status, 'estimate_only');
            testCase.verifySubstring(lower(summary.explanation), ...
                'not linked to a saved plan');
        end

        function planSafetyRulesOverrideACompleteFlag(testCase)
            result = resultWithPlan('interaction', 0.90);
            result.study_plan.reliability_instruction_supported = false;
            result.study_plan.reliability_instruction_status = ...
                'exploratory_confidence';
            result.study_plan.confidence = 0.50;
            result.study_plan.reliability_validation_floor_articles = 400;
            result.n = 400;

            summary = result_decision_summary(result);

            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.status, 'outside_validation_envelope');
            testCase.verifySubstring(lower(summary.explanation), ...
                'not safety-supported');
        end

        function articleFloorOverridesACompleteFlag(testCase)
            result = resultWithPlan('interaction', 0.90);
            result.study_plan.reliability_instruction_supported = true;
            result.study_plan.reliability_instruction_status = ...
                'supported_after_final_checkpoint';
            result.study_plan.reliability_validation_floor_articles = 400;
            result.n = 399;

            summary = result_decision_summary(result);

            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.status, 'article_floor_not_reached');
            testCase.verifySubstring(summary.explanation, '400');
        end

        function missingSafetyFieldsCannotIssueInstruction(testCase)
            result = resultWithPlan('interaction', 0.90);
            result.study_plan = rmfield(result.study_plan, ...
                'reliability_validation_floor_articles');

            summary = result_decision_summary(result);

            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.status, 'plan_incomplete');
            testCase.verifySubstring(lower(summary.explanation), 'safety');
        end

        function editedSafetyRulesCannotIssueInstruction(testCase)
            result = resultWithPlan('interaction', 0.90);
            result.study_plan.reliability_validation_floor_articles = 399;

            summary = result_decision_summary(result);

            testCase.verifyFalse(summary.supported);
            testCase.verifyEqual(summary.status, 'plan_incomplete');
        end

        function textUsesOverallVariationAndSeparatesMiddleFromReliability(testCase)
            result = resultWithPlan('interaction', 0.90);
            text = format_result_text(result);
            testCase.verifySubstring(text, 'OVERALL VARIATION');
            testCase.verifySubstring(lower(text), ...
                'entire tested process varies');
            testCase.verifySubstring(text, 'MIDDLE GAP (about 50% interaction)');
            testCase.verifyFalse(contains(lower(text), ...
                'middle gap is 99% reliable'));
        end

        function resultWindowKeepsBothVisualExplanations(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            source = fileread(fullfile(projectRoot, 'application', 'source', ...
                'show_result.m'));
            testCase.verifySubstring(source, 'draw_distribution');
            testCase.verifySubstring(source, 'draw_interaction_curve');
            testCase.verifySubstring(source, 'Supported operating instruction');
            testCase.verifySubstring(source, 'Overall variation');
        end

        function savedHtmlUsesSamePlainMeanings(testCase)
            html = results_to_html(resultWithPlan('interaction', 0.90), '');
            testCase.verifySubstring(html, 'Middle gap');
            testCase.verifySubstring(html, 'Overall variation');
            testCase.verifySubstring(html, 'entire tested process');
            testCase.verifyFalse(contains(lower(html), ...
                'middle gap is 99% reliable'));
        end

        function distributionChartUsesOverallVariationLanguage(testCase)
            figureHandle = figure('Visible', 'off');
            cleanupFigure = onCleanup(@() close(figureHandle)); %#ok<NASGU>
            axesHandle = axes('Parent', figureHandle);
            draw_distribution(axesHandle, referenceResult());
            textObjects = findall(axesHandle, 'Type', 'text');
            visibleWords = strings(0, 1);
            for textIndex = 1:numel(textObjects)
                textValue = textObjects(textIndex).String;
                if iscell(textValue)
                    visibleWords = [visibleWords; string(textValue(:))]; %#ok<AGROW>
                else
                    visibleWords(end + 1, 1) = string(textValue); %#ok<AGROW>
                end
            end
            legendObjects = findall(figureHandle, 'Type', 'legend');
            for legendIndex = 1:numel(legendObjects)
                legendValue = legendObjects(legendIndex).String;
                visibleWords = [visibleWords; string(legendValue(:))]; %#ok<AGROW>
            end
            combined = lower(strjoin(visibleWords, ' | '));
            testCase.verifySubstring(combined, 'overall variation');
            testCase.verifyFalse(contains(combined, 'width'));
        end

        function compactDistributionLeavesReliabilityLimitsToProbabilityChart(testCase)
            figureHandle = figure('Visible', 'off');
            cleanupFigure = onCleanup(@() close(figureHandle)); %#ok<NASGU>
            axesHandle = axes('Parent', figureHandle);
            compactSettings = neyer_settings();
            compactSettings.compact = true;
            draw_distribution(axesHandle, referenceResult(), compactSettings);
            textObjects = findall(axesHandle, 'Type', 'text');
            combined = lower(flatten_visible_text(textObjects));
            testCase.verifySubstring(combined, 'overall variation');
            testCase.verifyFalse(contains(combined, '99.9% interaction'));
            testCase.verifyFalse(contains(combined, 'negligible interaction'));
        end
    end
end

function combined = flatten_visible_text(textObjects)
words = strings(0, 1);
for textIndex = 1:numel(textObjects)
    textValue = textObjects(textIndex).String;
    if iscell(textValue)
        words = [words; string(textValue(:))]; %#ok<AGROW>
    else
        words(end + 1, 1) = string(textValue); %#ok<AGROW>
    end
end
combined = strjoin(words, ' | ');
end

function result = resultWithPlan(outcome, reliability)
result = referenceResult();
plan = struct( ...
    'outcome', outcome, 'reliability', reliability, 'confidence', 0.95, ...
    'accuracy_mm', 10, 'minimum_gap_mm', 0, 'maximum_gap_mm', 10, ...
    'main_articles', 20, 'reserve_1_articles', 0, 'reserve_2_articles', 0, ...
    'reliability_validation_floor_articles', 400, ...
    'reliability_instruction_supported', true, ...
    'reliability_instruction_status', 'supported_after_final_checkpoint', ...
    'reachable_model', reachable_gap_model( ...
        struct('mode', 'regular', 'increment_mm', 0.10), 0, 10));
result.study_plan = plan;
result.checkpoint_decision = struct('status', 'complete');
result.n = 400;
end

function result = referenceResult()
persistent savedResult
if isempty(savedResult)
    outcomes = logical([0 0 0 0 0 1 0 0 0 0 0 0 1 0 1 0 1 1 1 1]);
    parameters = struct('avg_low', 8.6, 'avg_high', 9.4, ...
        'spread_guess', 0.1);
    evalc('[savedResult,~]=run_test(parameters,20,@(~,testNumber)outcomes(testNumber));');
end
result = savedResult;
end
