# Reproduce candidate-02 gates

Run from the repository root using MATLAB R2022b on Windows. Keep candidate-02 sealed. For a fresh rerun choose a new unused folder such as candidate-03; do not reuse an existing evidence folder unless deliberately resuming identical-source matrix checkpoints.

The run recorded here used `candidate-02` throughout:

1. Preserve the previous delivery M/MLX under `audit/v2/candidate-01-artifacts`, checking their old fingerprint before rebuilding.
2. Run `powershell -File tools/build_standalone_v2.ps1`.
3. Set `$env:NEYER_V2_AUDIT_VERSION='candidate-02'`, then run `& 'C:/Program Files/MATLAB/R2022b/bin/matlab.exe' -batch "addpath('tools'); run('tools/build_v2_mlx.m')"`.
4. Run `powershell -File tools/run_v2_desktop_gate.ps1 -Gate suite -AuditVersion candidate-02`.
5. In each of four independent processes set the same environment variable, then run MATLAB with `-batch "addpath('tools'); run_v2_regular_matrix(SHARD,4); run_v2_list_matrix(SHARD,4)"`, replacing SHARD with 1, 2, 3 and 4. Start all four for parallel execution.
6. Run `powershell -File tools/run_v2_desktop_gate.ps1 -Gate capture -AuditVersion candidate-02` and inspect all 16 PNGs at original size, including the bottom of Help.
7. Run `powershell -File tools/run_v2_desktop_gate.ps1 -Gate clean -AuditVersion candidate-02`.
8. Set the environment variable again in the fingerprint process and run MATLAB with `-batch "run('tools/v2_release_fingerprint.m')"`.
9. Record the visual review/report and hash the candidate evidence plus final delivery artifacts. Commit those files with byte-preserving audit attributes. Never rebuild after fingerprinting without repeating the affected gates and fingerprints.

The desktop launcher requires `matlab.exe` on PATH. Where sandbox restrictions prevent MATLAB startup, use the approved full executable route. Do not call `run_tests` for an output value: it is a script. The dedicated full-suite runner executes `tests` plus `measurement-recorder/tests` and records actual counts. A desktop run is required so UI tests are not skipped.

The seed and case definitions are in `tools/v2_matrix_cases.m`. Regular coverage is 360 combinations times five repeats; confirmed-list coverage is 90 combinations times five repeats. Each has a full seeded replay. Every ten cases, each shard saves complete transcripts and source hashes in MAT plus summary checks in CSV. Resume requires matching source bytes. Final collection requires unique, complete study IDs, zero failures and zero mismatches; fingerprinting rechecks all transcripts and source hashes.

The clean-start gate opens the MLX alone in a new temporary folder with MATLAB's default path. Any subsequently reconstructed functions come only from that artifact. It runs the physical workflow, published replay, probability calculation, actual CSV/HTML save and actual collision rejection. The retained files are in `clean-start`.

No conclusion relies on ignored `.log` files. `full-suite-results.txt`, `release-fingerprint.txt`, the complete matrix checkpoints, `clean-start`, this report and `ui/visual-review.md` are the durable evidence. Previous candidate evidence was neither reused for the fresh matrices nor overwritten. OneDrive copying is explicitly outside this wave.
