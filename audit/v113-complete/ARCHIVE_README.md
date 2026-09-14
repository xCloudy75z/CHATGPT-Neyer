# Preserved V1.13 audit

These existing audit records and their original report are archived as historical evidence. Their reported 272-test run and simulation results belong to the frozen V1.13 audit. They are not the current V2 test counts. No historical conclusion or numerical claim has been rewritten to imply a later V2 improvement was present in V1.13.

The original audit tools and planning documents are retained for provenance. They were written while `application/source` represented V1.13; several old scripts directly read that directory and must not be used to regenerate a V1.13-labelled report from today's V2 source. The current `TestV113CompleteAudit` uses `v113_frozen_sources` to extract the hash-checked frozen MLX into temporary files. Use that test class for the historical comparison and the separate V2 gate scripts for the current release.

The previously uncommitted archive, its independent mathematical oracle, and byte-fingerprint helper are now intentionally included so the final suite and its comparisons do not depend on local uncommitted files. Ignored console diaries are not required; the original concise evidence, report, CSVs and screenshots are retained. The original evidence manifest remains unchanged.
