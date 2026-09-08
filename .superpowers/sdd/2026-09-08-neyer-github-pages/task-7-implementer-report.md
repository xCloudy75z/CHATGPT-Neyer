# Task 7 implementer report — GitHub Pages publication

## Published address

The verified public address is
<https://xcloudy75z.github.io/CHATGPT-Neyer/>.

Publication branch: `codex/neyer-v110`.

## Commits and workflow

| Commit | Purpose |
| --- | --- |
| `21c7bff0de10095e2a8c6bbed64213fe55a5a23e` | `ci: publish Neyer review site` |
| `02a69d5bbf5836bb347bd327ca6af935a4c59de3` | `docs: add verified Neyer site` |

The workflow is `.github/workflows/pages.yml`.  It validates `site/` before
uploading that exact artifact and contains the required `pages: write` and
`id-token: write` permissions.  The regression test also confirms that both
`codex/neyer-v110` and `main` are configured push triggers.

GitHub Pages was created through the Pages API with this returned configuration:

```json
{
  "html_url": "https://xcloudy75z.github.io/CHATGPT-Neyer/",
  "build_type": "workflow",
  "public": true,
  "https_enforced": true
}
```

Initial workflow run [34193848873](https://github.com/xCloudy75z/CHATGPT-Neyer/actions/runs/34193848873)
was blocked before steps by the automatically created `github-pages`
environment, whose custom deployment policy allowed only `codex/neyer-audit`.
After adding the requested `codex/neyer-v110` deployment policy, the same run
was rerun successfully: checkout, validator, Pages configuration, artifact
upload, and deployment all completed.  The final manual run on the README
commit, [34194144256](https://github.com/xCloudy75z/CHATGPT-Neyer/actions/runs/34194144256),
also succeeded with all those steps.

Both successful runs emitted GitHub's non-failing advisory that the referenced
Pages actions still target Node.js 20 and were forced to Node.js 24 by the
runner.

## Local validation

- The new focused workflow regression first failed because `pages.yml` was
  absent, then passed after the workflow was added.
- `python.exe -m unittest tests.test_public_site_validator -v`: 24 passed.
- `python.exe tools/validate_public_site.py`: `Public site validation passed`.
- `git diff --check`: no output.
- Sensitive-content scan of `site/` for machine paths, `localhost`, retired
  wording, and GitHub token prefixes: no matches.
- Before each commit, the staged diff check was clean.  The branch was pushed
  normally; no history was rewritten.

## Live HTTPS verification

Each required resource returned HTTPS `200`, its expected content type, and a
non-empty payload on the final recheck:

| Resource | Content type | Bytes | SHA-256 where required |
| --- | --- | ---: | --- |
| `/` | `text/html; charset=utf-8` | 4,276 | Home contains `Plan the study. Run each test. Understand the answer.` |
| `/test-workflow.html` | `text/html; charset=utf-8` | 6,216 | — |
| `/assets/screens/v110-01-main-menu.png` | `image/png` | 15,658 | `d664ab5d3fd21d2bdff87e4147eeb2e2270642e5244f05dd9bdb86a0f47271f3` |
| `/downloads/Neyer_Gap_Test_v1_10.mlx` | `application/octet-stream` | 70,204 | `6dd1a2f790d2f917601a4629c3df6397a98d6643e87a777651a0f9ce68767a7b` |
| `/reports/Neyer_Overnight_Verification_Report.html` | `text/html; charset=utf-8` | 593,082 | `e90bdaa57c9eb32c177ab6ca3d9ca634daeda56f25432b2dc0d24c1fd3427996` |

The three displayed hashes equal the reviewed local screenshot, Live Script,
and report copies respectively.

## Live layout and README checks

Headless Edge rendered every public route (`index`, `method`, `planner`,
`test-workflow`, `results`, `physical-setup`, `audit`, and `evidence`) over
the public HTTPS address at both 1440 × 1100 desktop and 390 × 844 phone
viewports.  All 16 page loads returned 200, had no broken images or page-load
failures, and had equal client and scroll widths (1440/1440 desktop,
390/390 phone), so no horizontal overflow was observed.

`README.md` was updated only after the first successful live verification.  It
links the verified address and plain-language method, planning, workflow,
results, physical-setup, audit, and evidence routes.  Commit `02a69d5` was
pushed, successfully deployed in run `34194144256`, and the public address was
checked again afterward.

## Remaining limitations

The review site continues to state the substantive physical limitation: the
provisional 0.05 mm usable resolution still requires repeated physical
confirmation.

The workflow deliberately includes `main` as a push trigger, but the existing
`github-pages` environment uses custom branch policies and currently permits
`codex/neyer-audit` and `codex/neyer-v110`, not `main`.  Adding `main` to that
security-sensitive deployment allowlist was rejected by the execution policy;
a future push from `main` would therefore require a repository administrator
to add that environment policy before it can deploy.
