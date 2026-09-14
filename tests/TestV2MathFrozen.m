classdef TestV2MathFrozen < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addV2Source(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'application', 'source')));
        end
    end

    methods (Test)
        function publishedReplayIsUnchanged(testCase)
            % Catches drift from the published V1.13 replay fit.
            demo = run_demo();

            testCase.verifyEqual(demo.got_mu, 5.3922, 'AbsTol', 5e-5);
            testCase.verifyEqual(demo.got_sigma, 1.0412, 'AbsTol', 5e-5);
            testCase.verifyTrue(demo.is_match);
        end

        function stageTwoTransitionsAtOneGuessedSigma(testCase)
            % Catches a return to the superseded wider Stage-2 threshold.
            parameters = struct('mu_min', 0, 'mu_max', 10, ...
                'sigma_guess', 1);
            [~, estimate] = choose_stage([1; 2], logical([1; 0]), ...
                parameters, neyer_settings());

            testCase.verifyEqual(estimate.stage, 2);
        end

        function separatedStageTwoResultsShrinkRepeatedly(testCase)
            % Catches shrinking only the first Part-2 request.
            parameters = struct('avg_low', -2, 'avg_high', 2, ...
                'spread_guess', 1);
            settings = neyer_settings();
            settings.min_level = -10;
            settings.max_level = 10;
            [~, record] = run_test(parameters, 15, ...
                @(gap, ~) gap <= -0.5, settings);
            stageTwoSigma = record.est_sigma(record.stage == 2);

            testCase.verifyGreaterThanOrEqual(numel(stageTwoSigma), 3);
            testCase.verifyEqual(stageTwoSigma(1:3), [1; 0.8; 0.64], ...
                'AbsTol', 1e-12);
        end

        function physicalPlanningFloorRemainsTwoUsableSteps(testCase)
            % Catches weakening the physical Stage-2 planning safeguard.
            parameters = struct('avg_low', 0, 'avg_high', 10, ...
                'spread_guess', 1);
            settings = neyer_settings();
            settings.usable_resolution = 0.10;
            response = @(gap, ~) struct('outcome', gap < 5, ...
                'measurements', gap);
            [~, record] = run_physical_test(parameters, 4, response, settings);

            testCase.verifyEqual(record.resolution_sigma_floor, 0.20, ...
                'AbsTol', 1e-12);
        end

        function interactionFallsAsGapIncreases(testCase)
            % Catches reversing the decreasing-gap interaction direction.
            model = shape_model([4; 6], 5, 1);

            testCase.verifyGreaterThan(model.p(1), model.p(2));
        end

        function regularRequestSequenceMatchesFrozenV113Evidence(testCase)
            % Oracle: audit/v113-complete/stage-matrix.csv, captured from the
            % frozen V1.13 paper replay. This deliberately does not execute
            % the frozen MLX from a test.
            expectedGaps = [1.00; 1.20; 1.40; 1.80; 2.60; 4.20; ...
                3.40; 3.80; 4.00; 4.10; 4.28; 4.52; 5.55; 5.24; ...
                6.37; 6.08; 7.38; 7.09; 6.89; 6.74];
            interaction = logical([1; 1; 1; 1; 1; 0; 1; 1; 1; 1; ...
                1; 1; 0; 1; 0; 1; 0; 0; 0; 0]);
            parameters = struct('avg_low', 0.6, 'avg_high', 1.4, ...
                'spread_guess', 0.10);
            [~, record] = run_test(parameters, 20, ...
                @(~, testNumber) interaction(testNumber), neyer_settings());

            testCase.verifyEqual(record.requested_levels, expectedGaps, ...
                'AbsTol', 0.005);
        end

        function twoSigmaReachProvenanceAndLegacyTermsAreTraceable(testCase)
            % Catches restoring the audit-identified misleading provenance
            % or making the compatibility terminology ambiguous.
            root = fileparts(fileparts(mfilename('fullpath')));
            settingsSource = fileread(fullfile(root, 'application', ...
                'source', 'neyer_settings.m'));
            appSource = fileread(fullfile(root, 'application', 'source', ...
                'neyer_app.m'));

            testCase.verifySubstring(settingsSource, ...
                'PAPER (first reach = 2*sigma_guess)');
            testCase.verifySubstring(appSource, ...
                'break = Interaction; survive = No interaction');
        end
    end
end
