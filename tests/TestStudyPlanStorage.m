classdef TestStudyPlanStorage < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addApplicationSource(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'application', 'source')));
        end
    end

    methods (Test)
        function savesReadableVersionedPlanAtExactSelectedPath(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'my-study-plan.json');
            plan = completePlan();

            savedPath = save_study_plan(plan, selectedPath);
            decoded = jsondecode(fileread(selectedPath));

            testCase.verifyEqual(savedPath, selectedPath);
            testCase.verifyEqual(decoded.schema_version, '1.1');
            testCase.verifyEqual(decoded.mode, 'requirements_first');
            testCase.verifyEqual(decoded.outcome, 'interaction');
            testCase.verifyEqual(decoded.minimum_gap_mm, 0);
            testCase.verifyEqual(decoded.maximum_gap_mm, 10);
            testCase.verifyTrue(isfield(decoded, 'reachable_model'));
            testCase.verifyTrue(isfield(decoded, 'main_articles'));
            testCase.verifyTrue(isfield(decoded, 'validation_basis'));
            testCase.verifyTrue(isfield(decoded, 'checkpoint_status'));
            testCase.verifyTrue(isfield(decoded, ...
                'reliability_validation_floor_articles'));
            testCase.verifyTrue(isfield(decoded, ...
                'reliability_instruction_supported'));
        end

        function savedPlanRoundTripsImportantValues(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'round-trip.json');
            plan = completePlan();
            save_study_plan(plan, selectedPath);

            [loaded, loadedPath] = load_study_plan(selectedPath);

            testCase.verifyEqual(loadedPath, selectedPath);
            testCase.verifyEqual(loaded.reliability, plan.reliability, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(loaded.confidence, plan.confidence, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(loaded.reachable_model.gaps_mm(:), ...
                plan.reachable_model.gaps_mm(:), 'AbsTol', 1e-12);
            testCase.verifyEqual(loaded.total_articles, plan.total_articles);
        end

        function refusesToReplaceExistingPlan(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'existing.json');
            writeText(selectedPath, 'keep this exact text');

            testCase.verifyError(@() save_study_plan(completePlan(), ...
                selectedPath), 'save_study_plan:alreadyExists');
            testCase.verifyEqual(fileread(selectedPath), 'keep this exact text');
        end

        function missingPlanHasUnderstandableNamedError(testCase)
            folder = testCase.createTemporaryFolder();
            testCase.verifyError(@() load_study_plan(fullfile(folder, ...
                'missing.json')), 'load_study_plan:notFound');
        end

        function invalidJsonHasUnderstandableNamedError(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'broken.json');
            writeText(selectedPath, '{this is not valid json');
            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:invalidJson');
        end

        function unsupportedPlanVersionIsRejected(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'future.json');
            writeText(selectedPath, '{"schema_version":"99.0"}');
            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:unsupportedVersion');
        end

        function olderPlanWithoutSafetyFieldsIsRejected(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'old-plan.json');
            writeText(selectedPath, ['{"schema_version":"1.0",' ...
                '"mode":"requirements_first"}']);

            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:unsupportedVersion');
        end

        function editedArticleFloorIsRejected(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'edited-floor.json');
            plan = completePlan();
            plan.reliability_validation_floor_articles = 399;
            writeText(selectedPath, jsonencode(plan));

            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:unsafePlan');
        end

        function confidenceAndSupportFlagMustAgree(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'edited-confidence.json');
            plan = completePlan();
            plan.confidence = 0.499;
            plan.reliability_instruction_supported = true;
            writeText(selectedPath, jsonencode(plan));

            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:unsafePlan');
        end

        function editedReliabilityOutsidePlannerRangeIsRejected(testCase)
            folder = testCase.createTemporaryFolder();
            selectedPath = fullfile(folder, 'edited-reliability.json');
            plan = completePlan();
            plan.reliability = 0.9999;
            writeText(selectedPath, jsonencode(plan));

            testCase.verifyError(@() load_study_plan(selectedPath), ...
                'load_study_plan:unsafePlan');
        end
    end
end

function plan = completePlan()
raw = struct( ...
    'mode', 'requirements_first', 'outcome', 'interaction', ...
    'reliability', 0.90, 'confidence', 0.95, 'accuracy_mm', 0.20, ...
    'interaction_gap_mm', 4, 'no_interaction_gap_mm', 6, ...
    'minimum_gap_mm', 0, 'maximum_gap_mm', 10, ...
    'previous_information', 'first_study', 'available_articles', [], ...
    'physical_setup', struct('mode', 'regular', 'increment_mm', 0.10));
clean = validate_plan_inputs(raw);
model = reachable_gap_model(clean.physical_setup, 0, 10);
plan = estimate_study_plan(clean, model);
end

function writeText(path, text)
fileId = fopen(path, 'w');
assert(fileId >= 0);
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', text);
clear cleanup;
end
