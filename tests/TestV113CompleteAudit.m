classdef TestV113CompleteAudit < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addAuditTools(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'tools')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                v113_frozen_sources(testCase.createTemporaryFolder())));
        end
    end

    methods (Test)
        function testFrozenReleaseHash(testCase)
            % Catches accidental replacement or modification of the sealed
            % V1.13 Live Script while the audit is in progress.
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            liveScriptPath = fullfile(projectRoot, 'delivery', ...
                'Neyer_Gap_Test_v1_13.mlx');

            fingerprint = v113_release_fingerprint(liveScriptPath);

            testCase.verifyEqual(fingerprint.sha256, ...
                '2DE2D89EB6156E0C2F9C1F3B08C14B01E9B428993BC3B573BED53406015A222E');
            testCase.verifyGreaterThan(fingerprint.bytes, 0);
        end

        function testComponentMapCoversAllSourceFiles(testCase)
            % Catches audit blind spots caused by omitting an application
            % component from the component inventory.
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            mapPath = fullfile(projectRoot, 'audit', 'v113-complete', ...
                'component-map.csv');
            testCase.assertTrue(isfile(mapPath), ...
                'Run the inventory phase before checking its coverage.');

            componentMap = readtable(mapPath, 'TextType', 'string');
            sourceFiles = dir(fullfile(fileparts(which('neyer_app')), '*.m'));
            expectedNames = sort(string({sourceFiles.name})');
            actualNames = sort(componentMap.source_file);

            testCase.verifyEqual(actualNames, expectedNames);
            testCase.verifyEqual(numel(unique(actualNames)), numel(actualNames));
            testCase.verifyFalse(any(strlength(componentMap.gate) == 0));
            testCase.verifyFalse(any(strlength(componentMap.purpose) == 0));
        end
    end

    methods (Test, TestTags = {'stage'})
        function stageOneStartsAtThePriorMidpoint(testCase)
            % Catches a first request that is biased toward either prior bound.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);

            [requestedGap, estimate] = choose_stage([], [], parameters, ...
                neyer_settings());

            testCase.verifyEqual(requestedGap, 5, 'AbsTol', 1e-12);
            testCase.verifyEqual(estimate.stage, 1);
        end

        function stageOneMovesInTheCorrectGapDirection(testCase)
            % Catches accidentally applying the paper's increasing-stimulus
            % direction without reversing it for a decreasing gap response.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);
            settings = neyer_settings();

            lowerGapAfterNoInteraction = choose_stage(5, false, ...
                parameters, settings);
            higherGapAfterInteraction = choose_stage(5, true, ...
                parameters, settings);

            testCase.verifyEqual(lowerGapAfterNoInteraction, 2.5, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(higherGapAfterInteraction, 7.5, ...
                'AbsTol', 1e-12);
        end

        function separatedWideBracketUsesBinarySearch(testCase)
            % Catches entering the D-optimal probing part before the paper's
            % separated bracket has narrowed to one guessed sigma.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);

            [requestedGap, estimate] = choose_stage([1; 3], ...
                logical([1; 0]), parameters, neyer_settings());

            testCase.verifyEqual(requestedGap, 2, 'AbsTol', 1e-12);
            testCase.verifyEqual(estimate.stage, 1);
        end

        function oneSigmaBoundaryEntersDOptimalPart(testCase)
            % Catches retaining the old reconstructed 1.5-sigma changeover.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);

            [~, estimate] = choose_stage([1; 2], logical([1; 0]), ...
                parameters, neyer_settings());

            testCase.verifyEqual(estimate.stage, 2);
        end

        function stageTwoPartTwoNeverReturnsToBinarySearch(testCase)
            % Catches a backward transition caused by comparing a newly
            % widened bracket against the original guessed sigma.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1, 'working_sigma', 0.8, ...
                'part2_started', true);

            [~, estimate] = choose_stage([1; 3], logical([1; 0]), ...
                parameters, neyer_settings());

            testCase.verifyEqual(estimate.stage, 2);
            testCase.verifyEqual(estimate.sigma, 0.8, 'AbsTol', 1e-12);
        end

        function everySeparatedPartTwoResultShrinksWorkingSigma(testCase)
            % Catches applying the 0.8 shrink once instead of after every
            % still-separated Part-2 test.
            parameters = struct('avg_low', -2, 'avg_high', 2, ...
                'spread_guess', 1);
            settings = neyer_settings();
            settings.min_level = -10;
            settings.max_level = 10;

            [~, record] = run_test(parameters, 15, ...
                @(gap, ~) gap <= -0.5, settings);
            partTwoSigma = record.est_sigma(record.stage == 2);

            testCase.verifyGreaterThanOrEqual(numel(partTwoSigma), 3);
            testCase.verifyEqual(partTwoSigma(1:3), [1; 0.8; 0.64], ...
                'AbsTol', 1e-12);
        end

        function overlapMustBeStrict(testCase)
            % Catches treating opposite outcomes at the same gap as a finite
            % maximum-likelihood fit when the likelihood is still separable.
            testCase.verifyFalse(has_overlap([2; 2], logical([1; 0])));
            testCase.verifyTrue(has_overlap([2; 1], logical([1; 0])));
        end

        function strictOverlapStartsMaximumLikelihoodStage(testCase)
            % Catches delaying Stage 3 after the first genuinely interleaved
            % pair exists in the decreasing-gap model.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);

            [~, estimate] = choose_stage([1; 2], logical([0; 1]), ...
                parameters, neyer_settings());

            testCase.verifyEqual(estimate.stage, 3);
        end

        function publishedTwentyStepSequenceIsReproduced(testCase)
            % Catches trajectory drift while using fixed outcomes only as a
            % reference replay, not as logic embedded in the application.
            expectedGaps = [1.00; 1.20; 1.40; 1.80; 2.60; 4.20; ...
                3.40; 3.80; 4.00; 4.10; 4.28; 4.52; 5.55; 5.24; ...
                6.37; 6.08; 7.38; 7.09; 6.89; 6.74];
            interaction = logical([1; 1; 1; 1; 1; 0; 1; 1; 1; 1; ...
                1; 1; 0; 1; 0; 1; 0; 0; 0; 0]);
            parameters = struct('avg_low', 0.6, 'avg_high', 1.4, ...
                'spread_guess', 0.1);

            [result, record] = run_test(parameters, 20, ...
                @(~, testNumber) interaction(testNumber), neyer_settings());

            testCase.verifyEqual(record.requested_levels, expectedGaps, ...
                'AbsTol', 0.005);
            testCase.verifyEqual(result.mu, 5.3922, 'AbsTol', 1e-4);
            testCase.verifyEqual(result.sigma, 1.0412, 'AbsTol', 1e-4);
        end
    end

    methods (Test, TestTags = {'math'})
        function independentFitMatchesV113(testCase)
            % Catches a sign, likelihood, or positive-variation error by
            % comparing with a separately coded estimator.
            [gaps, interaction] = paperReplayData();

            oracle = v113_independent_oracle(gaps, interaction, [], ...
                0.95, []);
            [middleGap, overallVariation] = best_fit(gaps, interaction, ...
                mean(gaps), std(gaps));

            testCase.verifyEqual(middleGap, oracle.mu, 'AbsTol', 1e-4);
            testCase.verifyEqual(overallVariation, oracle.sigma, ...
                'AbsTol', 1e-4);
            testCase.verifyEqual(oracle.mu, 5.3922, 'AbsTol', 1e-4);
            testCase.verifyEqual(oracle.sigma, 1.0412, 'AbsTol', 1e-4);
        end

        function independentInformationMatchesV113(testCase)
            % Catches an incorrect information determinant even when a
            % familiar trajectory happens to select the expected gap.
            [gaps, interaction] = paperReplayData();
            candidates = (2:0.01:9)';
            oracle = v113_independent_oracle(gaps, interaction, ...
                candidates, 0.95, []);

            [old0, old1, old2] = info_terms(gaps, oracle.mu, ...
                oracle.sigma);
            [new0, new1, new2] = info_terms(candidates, oracle.mu, ...
                oracle.sigma);
            productionDeterminants = (sum(old0) + new0) .* ...
                (sum(old2) + new2) - (sum(old1) + new1).^2;
            [~, productionWinner] = max(productionDeterminants);

            testCase.verifyEqual(productionDeterminants, ...
                oracle.candidate_determinants, 'RelTol', 2e-9, ...
                'AbsTol', 1e-10);
            testCase.verifyEqual(candidates(productionWinner), ...
                oracle.d_optimal_gap, 'AbsTol', 1e-12);
        end

        function independentParameterConfidenceMatchesV113(testCase)
            % Catches profiling the wrong parameter or using the wrong
            % two-sided likelihood threshold.
            [gaps, interaction] = paperReplayData();
            oracle = v113_independent_oracle(gaps, interaction, [], ...
                0.95, []);
            confidence = lr_confidence(gaps, interaction, mean(gaps), ...
                std(gaps), neyer_settings());

            testCase.verifyEqual([confidence.mu_lo confidence.mu_hi], ...
                oracle.mu_ci, 'AbsTol', 2e-3);
            testCase.verifyEqual([confidence.sigma_lo confidence.sigma_hi], ...
                oracle.sigma_ci, 'AbsTol', 2e-3);
        end

        function fixedGapProbabilitiesUseDecreasingDirection(testCase)
            % Catches the easy-to-miss double sign reversal in the legacy
            % fixed-gap reliability calculation.
            [gaps, interaction] = paperReplayData();
            oracle = v113_independent_oracle(gaps, interaction, [], ...
                0.95, [2; 8]);
            result = struct('levels', gaps, 'successes', interaction, ...
                'sigma', oracle.sigma);
            lowGap = reliability_query(result, 'interaction', ...
                'probability_at', 2, 0.95);
            highGap = reliability_query(result, 'interaction', ...
                'probability_at', 8, 0.95);

            testCase.verifyEqual(lowGap.probability, ...
                oracle.interaction_probability(1), 'AbsTol', 1e-6);
            testCase.verifyEqual(highGap.probability, ...
                oracle.interaction_probability(2), 'AbsTol', 1e-6);
            testCase.verifyGreaterThan(lowGap.probability, ...
                highGap.probability);
            testCase.verifyLessThanOrEqual(lowGap.bound, ...
                lowGap.probability);
            testCase.verifyLessThanOrEqual(highGap.bound, ...
                highGap.probability);
        end

        function variedHistoriesMatchIndependentFit(testCase)
            % Catches a fit that only agrees for the published example.
            scenarios = variedMathScenarios();
            for scenarioNumber = 1:size(scenarios, 1)
                scenarioName = scenarios{scenarioNumber, 1};
                gaps = scenarios{scenarioNumber, 2};
                interaction = scenarios{scenarioNumber, 3};
                oracle = v113_independent_oracle(gaps, interaction, ...
                    [], 0.95, []);
                [middleGap, overallVariation] = best_fit(gaps, ...
                    interaction, mean(gaps), std(gaps));
                testCase.verifyEqual(middleGap, oracle.mu, ...
                    sprintf('V1.13 middle mismatch for %s.', scenarioName), ...
                    'AbsTol', 2e-4);
                testCase.verifyEqual(overallVariation, oracle.sigma, ...
                    sprintf('V1.13 variation mismatch for %s.', scenarioName), ...
                    'AbsTol', 2e-4);
            end
        end
    end

    methods (Test, TestTags = {'physical'})
        function approvedRegularStepsStayReachableAndUseTwoDecimals(testCase)
            % Catches requests that fall between the settings the operator
            % has declared buildable.
            for usableStep = [0.05 0.10 0.15 0.50]
                model = reachable_gap_model(struct('mode', 'regular', ...
                    'increment_mm', usableStep), 0, 10);
                rawRequests = [0; 0.07; 2.45; 5.03; 9.99; 10];
                previous = [];
                for requestNumber = 1:numel(rawRequests)
                    [selected, status] = select_reachable_request( ...
                        rawRequests(requestNumber), model, previous, false);
                    testCase.verifyEqual(status.code, 'ok');
                    testCase.verifyTrue(any(abs(model.gaps_mm - selected) ...
                        < 1e-10));
                    testCase.verifyNotEmpty(regexp(char(status.display_gap), ...
                        '^\d+\.\d{2} mm$', 'once'));
                    previous(end + 1, 1) = selected; %#ok<AGROW>
                end
            end
        end

        function irregularListNeverInventsAGap(testCase)
            % Catches snapping to a regular grid when the user supplied only
            % a confirmed irregular list.
            confirmed = [0; 0.50; 1.10; 2.07; 2.57; 3.17; 4.14; 10.00];
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', confirmed), 0, 10);
            for rawRequest = [0.24 0.80 1.95 2.45 3.80 8.00]
                selected = select_reachable_request(rawRequest, model, [], false);
                testCase.verifyTrue(any(abs(confirmed - selected) < 1e-12));
            end
        end

        function requestedAndMeasuredGapsRemainSeparate(testCase)
            % Catches analyzing the requested 2.45 mm when the one measured
            % reading for the actual build is 2.50 mm.
            settings = neyer_settings();
            settings.usable_resolution = 0.05;
            settings.level_increment = 0.05;
            parameters = struct('avg_low', 0, 'avg_high', 4.90, ...
                'spread_guess', 0.5);
            response = @(~, ~) struct('outcome', true, ...
                'measurements', 2.50);

            [~, record] = run_physical_test(parameters, 3, response, settings);

            testCase.verifyEqual(record.requested_levels(1), 2.45, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(record.levels(1), 2.50, 'AbsTol', 1e-12);
            testCase.verifyEqual(record.measurements{1}, 2.50, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(record.measurement_count, ones(3, 1));
        end

        function invalidSingleMeasurementsAreRejected(testCase)
            % Catches silently accepting no reading, several readings, or a
            % physically impossible negative reading.
            badEntries = {'', 'word', '-0.01', '2.49 2.50', 'NaN', 'Inf'};
            for entryNumber = 1:numel(badEntries)
                testCase.verifyError(@() parse_physical_response( ...
                    badEntries{entryNumber}, true), ...
                    'parse_physical_response:badMeasurements');
            end
        end

        function noDifferentUsefulGapPausesWithoutCallingItFailure(testCase)
            % Catches the old repeated-setting trap and a misleading failed
            % test label when the physical capability is exhausted.
            model = reachable_gap_model(struct('mode', 'list', ...
                'gaps_mm', [0.30 0.35]), 0.30, 0.35);
            settings = neyer_settings();
            settings.min_level = 0.30;
            settings.max_level = 0.35;
            settings.usable_resolution = 0.05;
            settings.reachable_model = model;
            settings.stage2_bisect_width_sigmas = 2;
            parameters = struct('avg_low', 0.20, 'avg_high', 0.40, ...
                'spread_guess', 0.03);
            outcomes = logical([true; false]);
            response = @(gap, testNumber) struct( ...
                'outcome', outcomes(testNumber), 'measurements', gap);

            [result, record] = run_physical_test(parameters, 3, ...
                response, settings);

            testCase.verifyEqual(record.status, 'paused');
            testCase.verifyEqual(record.stop_reason, ...
                'no_different_reachable_gap');
            testCase.verifyEqual(result.status, 'paused');
            testCase.verifyEqual(record.N, 2);
        end

        function physicalRunKeepsTwoStepVariationFloor(testCase)
            % Catches weakening the approved protection when a larger usable
            % gap step is selected.
            for usableStep = [0.05 0.10 0.15 0.50]
                settings = neyer_settings();
                settings.usable_resolution = usableStep;
                parameters = struct('avg_low', 0, 'avg_high', 10, ...
                    'spread_guess', 1);
                response = @(gap, ~) struct('outcome', gap < 5, ...
                    'measurements', gap);
                [~, record] = run_physical_test(parameters, 4, ...
                    response, settings);
                testCase.verifyEqual(record.resolution_sigma_floor, ...
                    2 * usableStep, 'AbsTol', 1e-12);
            end
        end
    end

    methods (Test, TestTags = {'workflow'})
        function mainMenuClearlySeparatesDirectRunFromPlanner(testCase)
            % Catches making the optional planner look required for Run a Test.
            close(findall(groot, 'Type', 'figure'));
            cleanupFigures = onCleanup(@() close( ...
                findall(groot, 'Type', 'figure'))); %#ok<NASGU>
            neyer_app();
            drawnow;
            menuFigure = findall(groot, 'Type', 'figure', ...
                'Name', 'Neyer Gap Test');
            testCase.assertNumElements(menuFigure, 1);
            buttons = findall(menuFigure, 'Type', 'uibutton');
            labels = findall(menuFigure, 'Type', 'uilabel');
            buttonText = string({buttons.Text});
            visibleText = strjoin(string({labels.Text}), ' | ');
            testCase.verifyTrue(any(buttonText == "Run a Test"));
            testCase.verifyTrue(any(buttonText == ...
                "Pre-Test Planner (separate)"));
            testCase.verifySubstring(visibleText, ...
                'Run a Test works independently');
        end

        function invalidDirectInputsUsePlainVisibleNames(testCase)
            % Catches raw programmer field names or acceptance of incomplete
            % physical settings.
            invalidCases = {
                {'text','10','1','20','0','10','mm','0.10','0.015'}, ...
                    'parse_run_inputs:badStartingNumber';
                {'10','1','1','20','0','10','mm','0.10','0.015'}, ...
                    'parse_run_inputs:badStartingGuesses';
                {'0','10','0','20','0','10','mm','0.10','0.015'}, ...
                    'parse_run_inputs:badOverallVariation';
                {'0','10','1','2','0','10','mm','0.10','0.015'}, ...
                    'parse_run_inputs:testMaximumTooSmall';
                {'0','10','1','20','0','0','mm','0.10','0.015'}, ...
                    'parse_run_inputs:badMaxLevel';
                {'0','10','1','20','0','10','mm','0.015','0.015'}, ...
                    'parse_run_inputs:badUsableResolution'
                };
            for caseNumber = 1:size(invalidCases, 1)
                testCase.verifyError(@() parse_run_inputs( ...
                    invalidCases{caseNumber, 1}), invalidCases{caseNumber, 2});
            end
        end

        function frozenUnfinishedResultRemainsSaveable(testCase)
            % Catches showing NaN as an answer or blocking preservation of
            % completed tests before a curve can be fitted.
            if ~usejava('desktop')
                source = fileread(which('show_result'));
                testCase.verifySubstring(source, 'result_save_available(result)');
                testCase.verifySubstring(lower(source), ...
                    'no fitted middle gap has been established');
                return;
            end
            close(findall(groot, 'Type', 'figure'));
            cleanupFigures = onCleanup(@() close( ...
                findall(groot, 'Type', 'figure'))); %#ok<NASGU>
            result = unfinishedAuditResult();
            resultFigure = show_result(result);
            drawnow;
            buttons = findall(resultFigure, 'Type', 'uibutton');
            buttonText = string({buttons.Text});
            calculateButton = buttons(buttonText == "Calculate");
            saveButton = buttons(buttonText == "Save results...");
            labels = findall(resultFigure, 'Type', 'uilabel');
            visibleText = lower(strjoin(string({labels.Text}), ' | '));

            testCase.verifyTrue(strcmp(calculateButton.Enable, 'off'));
            testCase.verifyTrue(strcmp(saveButton.Enable, 'on'));
            testCase.verifySubstring(visibleText, ...
                'no fitted middle gap has been established');
            % Frozen V1.13 retains its known empty-chart limitation. V2 has
            % separate tests requiring the corrected unfinished-result view.
            testCase.verifyNumElements(findall(resultFigure, 'Type', 'axes'), 2);
            testCase.verifyFalse(contains(visibleText, 'nan'));
        end

        function calculatedScreenCalculatorMatchesMiddleGapMeaning(testCase)
            % Catches a screen label or callback that presents the middle gap
            % as anything other than an approximately 50% point.
            if ~usejava('desktop')
                source = lower(fileread(which('show_result')));
                testCase.verifySubstring(source, 'best estimated chance');
                testCase.verifySubstring(source, ...
                    'cautious minimum supported by the data');
                testCase.verifySubstring(source, ...
                    'what the fitted result means');
                testCase.verifySubstring(source, ...
                    'middle gap (50%% interaction)');
                return;
            end
            close(findall(groot, 'Type', 'figure'));
            cleanupFigures = onCleanup(@() close( ...
                findall(groot, 'Type', 'figure'))); %#ok<NASGU>
            demo = run_demo();
            resultFigure = show_result(demo.result);
            drawnow;
            gapEdit = findall(resultFigure, 'Type', 'uinumericeditfield');
            outcomeChoice = findall(resultFigure, 'Type', 'uidropdown');
            buttons = findall(resultFigure, 'Type', 'uibutton');
            calculateButton = buttons(string({buttons.Text}) == "Calculate");
            gapEdit.Value = demo.result.mu;
            outcomeChoice.Value = 'Interaction';
            feval(calculateButton.ButtonPushedFcn, calculateButton, []);
            drawnow;
            labels = findall(resultFigure, 'Type', 'uilabel');
            visibleText = strjoin(string({labels.Text}), ' | ');

            testCase.verifySubstring(visibleText, ...
                'best estimated chance 50%');
            testCase.verifySubstring(visibleText, ...
                'cautious minimum');
            testCase.verifyFalse(contains(lower(visibleText), ...
                'middle gap is 99% reliable'));
        end

        function savedCsvAndHtmlAgreeAndCannotBeOverwritten(testCase)
            % Catches mismatched saved answers and silent replacement of an
            % earlier study record.
            demo = run_demo();
            temporaryFolder = testCase.createTemporaryFolder();
            chosenBase = fullfile(temporaryFolder, 'audited-result.html');
            csvText = results_to_csv_text(demo.result);
            htmlText = results_to_html(demo.result, '');

            paths = save_results_files(chosenBase, csvText, htmlText);

            testCase.verifySubstring(fileread(paths.csv), '5.3922');
            testCase.verifySubstring(fileread(paths.html), '5.39');
            testCase.verifySubstring(fileread(paths.csv), '1.0412');
            testCase.verifySubstring(fileread(paths.html), '1.04');
            testCase.verifyError(@() save_results_files( ...
                chosenBase, 'replacement CSV', 'replacement HTML'), ...
                'save_results_files:alreadyExists');
            testCase.verifyEqual(fileread(paths.csv), csvText);
            testCase.verifyEqual(fileread(paths.html), htmlText);
        end
    end
end

function [gaps, interaction] = paperReplayData()
gaps = [1.00; 1.20; 1.40; 1.80; 2.60; 4.20; 3.40; 3.80; 4.00; ...
    4.10; 4.28; 4.52; 5.55; 5.24; 6.37; 6.08; 7.38; 7.09; 6.89; 6.74];
interaction = logical([1; 1; 1; 1; 1; 0; 1; 1; 1; 1; 1; 1; 0; ...
    1; 0; 1; 0; 0; 0; 0]);
end

function scenarios = variedMathScenarios()
scenarios = {
    'balanced', [3; 4; 4.5; 5; 5.5; 6; 7], ...
        logical([1; 1; 0; 1; 1; 0; 0]);
    'narrow', [4.70; 4.80; 4.90; 5.00; 5.10; 5.20; 5.30], ...
        logical([1; 1; 0; 1; 0; 0; 0]);
    'wide', [1; 2; 3; 4; 5; 6; 7; 8; 9], ...
        logical([1; 0; 1; 1; 0; 1; 0; 0; 0]);
    'duplicate gaps', [3; 4; 4; 5; 5; 6; 6; 7], ...
        logical([1; 1; 0; 1; 0; 1; 0; 0]);
    'near physical boundaries', [0; 0.10; 0.20; 0.50; 1; 9; 9.50; 9.80; 9.90; 10], ...
        logical([1; 1; 0; 1; 1; 0; 0; 1; 0; 0])
    };
end

function result = unfinishedAuditResult()
result = struct( ...
    'has_overlap', false, 'status', 'complete', 'stop_reason', '', ...
    'n', 3, 'unit', 'mm', 'levels', [5.50; 3.30; 1.10], ...
    'successes', logical([0; 0; 1]), ...
    'requested_levels', [5.50; 3.30; 1.10], ...
    'measurements', {{5.50, 3.30, 1.10}}, ...
    'mu', NaN, 'mu_lo', NaN, 'mu_hi', NaN, ...
    'sigma', NaN, 'sigma_lo', NaN, 'sigma_hi', NaN, ...
    'confidence_level', 0.95, 'tail_fraction', 0.999);
end
