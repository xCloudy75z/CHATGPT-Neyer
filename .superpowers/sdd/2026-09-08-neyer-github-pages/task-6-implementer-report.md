# Task 6 implementer report — desktop and phone visual proof

## Delivered

- `tools/capture_public_site.cjs`: local static-server and Playwright capture helper.
- `tools/capture_public_site.test.cjs`: decoded traversal containment regression.
- `audit/site/site-desktop.png`: 1440 x 1953 px full-page desktop evidence.
- `audit/site/site-phone.png`: 390 x 3626 px full-page phone evidence.
- `audit/site/visual-review.txt`: detailed visual and runtime review record.

The helper serves only `site/`, rejects decoded traversal outside it, uses the
bundled Node and Playwright installation with a verified local Edge executable,
and checks all eight public pages at 1440 x 1100 and 390 x 844. It fails on
non-200 loads, horizontal overflow, and a missing primary-action focus outline.

## Commands and results

```powershell
$env:NODE_PATH = 'C:\Users\games\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'
& 'C:\Users\games\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' --test tools\capture_public_site.test.cjs
& 'C:\Users\games\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' tools\capture_public_site.cjs
& 'C:\Users\games\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m unittest tests.test_public_site_validator -v
& 'C:\Users\games\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools\validate_public_site.py
git diff --check
rg -n 'C:\\Users\\|localhost|transition width|github_pat_|ghp_' site
```

- Capture containment regression: 1 passed.
- Public-site validator suite: 23 passed.
- Public-site static validator: passed.
- `git diff --check`: passed.
- Public content and secret scan: no matches.

## Every-page runtime result

At both viewports each of `index.html`, `method.html`, `planner.html`,
`test-workflow.html`, `results.html`, `physical-setup.html`, `audit.html`, and
`evidence.html` returned 200 and had equal client and scroll widths:

| Viewport | Client / scroll width | Page count | Focus outline |
| --- | --- | ---: | --- |
| Desktop 1440 x 1100 | 1440 / 1440 px | 8 | solid 3 px amber |
| Phone 390 x 844 | 390 / 390 px | 8 | solid 3 px amber |

## Visual review and correction

The retained screenshots show a clear desktop hero and five-step workflow,
compact readable navigation, visible primary-action focus treatment, and
three-column route cards. On phone, the navigation, workflow, status panel,
and route cards stack without clipping; hero and body text remain legible. The
method page shares the one-column gap-ruler rule, and the runtime phone check
found no overflow there.

An initial phone check found `audit.html` at 413 px wide because an unbroken
repository filename inside a code element fixed a two-column child at its
minimum content width. `site/assets/site.css` now allows grid children to
shrink and applies safe code wrapping. The corrected capture reported 390 px
on that page and every other phone page; only corrected images remain.

## Commit and concern

Committed with `test: verify public site layouts`.

The evidence is local Edge/Playwright proof. Task 7 must repeat the visual
checks over published HTTPS before representing the Pages address as live.
