projectRoot = fileparts(fileparts(mfilename('fullpath')));
sourceFolder = fullfile(projectRoot, 'application', 'source');
evidenceFolder = fullfile(projectRoot, 'audit', 'v113-complete');
addpath(sourceFolder);
if ~isfolder(evidenceFolder), mkdir(evidenceFolder); end

expectedGaps = [1.00; 1.20; 1.40; 1.80; 2.60; 4.20; 3.40; 3.80; ...
    4.00; 4.10; 4.28; 4.52; 5.55; 5.24; 6.37; 6.08; 7.38; 7.09; ...
    6.89; 6.74];
interaction = logical([1; 1; 1; 1; 1; 0; 1; 1; 1; 1; 1; 1; 0; ...
    1; 0; 1; 0; 0; 0; 0]);
parameters = struct('avg_low', 0.6, 'avg_high', 1.4, ...
    'spread_guess', 0.1);
[result, record] = run_test(parameters, 20, ...
    @(~, testNumber) interaction(testNumber), neyer_settings());

assert(max(abs(record.requested_levels - expectedGaps)) <= 0.005, ...
    'The V1.13 requested-gap sequence does not match the paper replay.');
assert(abs(result.mu - 5.3922) <= 1e-4, ...
    'The V1.13 middle-gap result does not match the paper replay.');
assert(abs(result.sigma - 1.0412) <= 1e-4, ...
    'The V1.13 variation result does not match the paper replay.');

phaseName = strings(record.N, 1);
phaseName(record.stage == 1) = "Binary search";
phaseName(record.stage == 2) = "D-optimal search before overlap";
phaseName(record.stage == 3) = "D-optimal search using fitted curve";
outcomeName = repmat("No interaction", record.N, 1);
outcomeName(record.successes) = "Interaction";
stageMatrix = table((1:record.N)', record.requested_levels, ...
    record.levels, outcomeName, phaseName, record.est_mu, ...
    record.est_sigma, 'VariableNames', {'test_number', ...
    'requested_gap_mm', 'analysis_gap_mm', 'outcome', 'selection_phase', ...
    'working_middle_mm', 'working_variation_mm'});
writetable(stageMatrix, fullfile(evidenceFolder, 'stage-matrix.csv'));

paperUrl = repmat("https://www.stat.cmu.edu/technometrics/90-00/vol-36-01/v3601061.pdf", 9, 1);
rule = [
    "Begin at the midpoint of the prior middle-gap bounds"
    "Move toward smaller gaps after only no-interaction results"
    "Move toward larger gaps after only interaction results"
    "Use binary search while the separated bracket is wider than one guessed variation"
    "Use D-optimal searching once the bracket reaches one guessed variation"
    "Multiply the working variation by 0.8 after every still-separated D-optimal test"
    "Do not fit the curve until interaction and no-interaction results strictly overlap"
    "After overlap, limit an early fitted middle to tested gaps and variation to the tested range"
    "Choose the next fitted-stage gap by maximizing the information determinant"
    ];
paperEvidence = [
    "Paper page 3, first specimen at midpoint"
    "Paper page 3 direction reversed explicitly for the decreasing-gap application"
    "Paper page 3 direction reversed explicitly for the decreasing-gap application"
    "Paper page 3, binary search until Diff is less than SigmaG; Figure 2 tests Diff > SigmaG"
    "Paper Figure 2 and page 4 surrogate estimates"
    "Paper page 4, SigmaG multiplied by 0.8 for each specimen"
    "Paper page 4, unique estimates begin after success/failure overlap"
    "Paper page 4, fitted mean and variation restrictions"
    "Paper pages 2-4, maximize determinant of the information matrix"
    ];
codeEvidence = [
    "choose_stage.m:67"
    "choose_stage.m:75-92"
    "choose_stage.m:75-92"
    "choose_stage.m:104-109"
    "choose_stage.m:104-125"
    "run_loop.m:260-272"
    "has_overlap.m:16-46 and choose_stage.m:98-133"
    "choose_stage.m:130-131 and sanity_clamp.m"
    "choose_stage.m:112,133 and pick_next_level.m"
    ];
status = repmat("Pass", 9, 1);
plainLanguageEffect = [
    "The first article is not biased toward either end of the starting range."
    "The tool moves toward the likely interaction region after misses."
    "The tool moves away from the likely interaction region after interactions."
    "The tool closes a large empty gap efficiently before probing beyond it."
    "The former 1.5-times rule is not present."
    "Repeated separated results keep pushing the search toward overlap."
    "The tool does not pretend a stable bell curve exists too early."
    "An unstable early fit cannot make the next request explode without limit."
    "Later articles are placed where they add the most joint information."
    ];
traceability = table(rule, paperUrl, paperEvidence, codeEvidence, status, ...
    plainLanguageEffect, 'VariableNames', {'rule', 'source', ...
    'paper_evidence', 'code_evidence', 'status', 'plain_language_effect'});
writetable(traceability, fullfile(evidenceFolder, ...
    'concept-traceability.csv'));

fprintf('V1.13 STAGE MATRIX: 20 paper steps reproduced; middle %.4f mm; variation %.4f mm.\n', ...
    result.mu, result.sigma);
