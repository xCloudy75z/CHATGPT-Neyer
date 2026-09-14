# Reproduce the V2 release gates

Use MATLAB R2022b on Windows. Run commands from the repository root. MATLAB must be able to start normally; the final UI suite requires desktop mode. The gate scripts do not install software or publish files.

1. `powershell -File tools/run_v2_desktop_gate.ps1 -Gate suite`
2. Start four independent MATLAB processes, each with `-batch "addpath('tools'); run_v2_regular_matrix(SHARD,4); run_v2_list_matrix(SHARD,4)"`, replacing SHARD with 1, 2, 3 and 4.
3. `powershell -File tools/run_v2_desktop_gate.ps1 -Gate capture`
4. `powershell -File tools/run_v2_desktop_gate.ps1 -Gate clean`
5. Inspect every PNG in `audit/v2/ui` at original size, including the final Help sections. Record the decision in `ui/visual-review.md`.
6. `matlab -batch "run('tools/v2_release_fingerprint.m')"`

`run_v2_full_suite.m` includes both `tests` and `measurement-recorder/tests`. It records every test name and its pass/fail/incomplete state. Do not call `run_tests` as if it returned results: it is a script. Do not replace the final desktop run with a batch run, which skips a direct-input control test.

The regular matrix has 360 combinations and five repeats: middle 1.5/5/8.5; true variation 0.15/0.25/0.5/1/1.5; step 0.05/0.10/0.15/0.50; starting variation 0.25/1/2; budget 20/62. The list matrix has 90 combinations and five repeats: the same middle, true variation and budgets; starting variation 1; and the three explicit lists in `v2_matrix_cases.m`. Each study has a fixed seed and a separate exact replay, so 2,250 studies mean 4,500 executions.

Each shard saves full request/outcome/stage/measurement transcripts and source fingerprints in MAT checkpoints, plus per-study checks in CSV. It resumes only when its source bytes still match. For a genuinely fresh rerun, preserve the old `matrices` folder under another explicit name before starting. Never mix shard counts or old and new runs in that folder: the collector rejects duplicate or missing study IDs. `pre-final-matrices` is retained only as superseded evidence from before the final Help formatting correction; the release uses `matrices` exclusively.

The clean-start gate begins with only the MLX in a new temporary folder and restores MATLAB's default path. It opens that artifact, reconstructs functions only from the artifact, then performs a 20-result direct run, the published replay, probability calculation, real CSV/HTML saving, and a real collision rejection. The exported CSV and HTML are retained with its text results. The temporary reconstructed files are removed afterwards.

If source changes are intended, rebuild explicitly with `tools/build_standalone_v2.ps1` and `tools/build_v2_mlx.m`, then repeat the gates and fingerprint again. The sealed candidate must never be rebuilt after fingerprinting without recording a new fingerprint. Git preserves the generated V2 `.m`, binary MLX and audit evidence byte-for-byte, so checkout does not invalidate their fingerprints by changing line endings.

Historical evidence in `audit/v113-complete` is preserved as recorded. Its 272-test report describes the earlier audit, not today's expanded V2 suite. `TestV113CompleteAudit` now extracts the sealed V1.13 MLX into temporary function files so later application changes cannot be mistaken for V1.13 behavior. The old audit's blank-chart finding remains a recorded limitation of that frozen release.

Only after every gate passes, copy the V2 MLX and its V2 report into a new versioned folder beneath the approved OneDrive `CHATGPT-Neyer/V2` area. Verify byte size and SHA-256 for both copies. A matching local OneDrive file does not prove cloud upload.
