# Neyer GitHub Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, verify, and publish a jargon-free visual review site for Neyer v1.10 at `https://xcloudy75z.github.io/CHATGPT-Neyer/`.

**Architecture:** A static multi-page site lives under `site/`. Shared local CSS gives every page one visual language; native HTML provides optional depth without a framework. A Python standard-library validator checks content, links, assets, and release-file fingerprints before an official GitHub Pages workflow deploys only `site/`.

**Tech Stack:** HTML5, CSS, native browser controls, Python 3 standard library, GitHub Actions, GitHub Pages, and Playwright used only for local visual evidence.

**Spec:** `docs/superpowers/specs/2026-09-08-neyer-github-pages-design.md`

## Global Constraints

- The site must work from a college computer or phone without MATLAB, OneDrive, a local path, or `localhost`.
- All user-facing wording must be jargon-free; define an unavoidable technical term where it first appears.
- Use `overall variation` as the main label; explain `sigma` only as its mathematical name.
- Never call the middle gap a safe or reliable operating gap.
- Interaction becomes less likely as the physical gap increases.
- Treat approximately `0.015 mm` foil thickness as construction information, not proof of a `0.015 mm` usable test step.
- Display requested gaps with two decimal places; explain that the measured mean keeps the entered precision.
- Use only committed v1.10 evidence: 211 complete checks, 191 mock-laboratory checks, 63 final-review regressions, and the recorded 12-scenario result.
- The website explains the MATLAB implementation; it does not reproduce or change the Neyer calculation.
- Do not use external fonts, trackers, analytics, frameworks, or runtime content services.
- Do not claim the public address works until the live HTTPS checks pass.

## File Map

- `site/index.html`: project hub.
- `site/method.html`: response direction, middle, overall variation, and operating-gap example.
- `site/planner.html`: every Pre-Test Planner question explained.
- `site/test-workflow.html`: seven-screen walkthrough.
- `site/results.html`: decision, graphs, confidence, and saving.
- `site/physical-setup.html`: foil, printed spacers, readings, and remaining physical confirmation.
- `site/audit.html`: v1.8 problems separated from v1.10 corrections.
- `site/evidence.html`: executed tests and simulations.
- `site/assets/site.css`: responsive visual system.
- `site/assets/screens/`: seven checked MATLAB screenshots.
- `site/downloads/Neyer_Gap_Test_v1_10.mlx`: exact standalone release copy.
- `site/reports/Neyer_Overnight_Verification_Report.html`: exact detailed report copy.
- `tools/prepare_public_site.ps1`: non-destructive asset preparation.
- `tools/validate_public_site.py`: site validator.
- `tests/test_public_site_validator.py`: validator regressions.
- `tools/capture_public_site.cjs`: desktop and phone rendering evidence.
- `.github/workflows/pages.yml`: validated GitHub Pages deployment.
- `README.md`: verified public address after deployment.

---

### Task 1: Build the validator first

**Files:**
- Create: `tools/validate_public_site.py`
- Create: `tests/test_public_site_validator.py`

**Interfaces:**
- Consumes: site and repository directories represented by `pathlib.Path`.
- Produces: `validate_site(site_root: Path, repository_root: Path) -> list[str]` and `validate_page_shell(site_root: Path) -> list[str]`; an empty list means pass.

- [ ] **Step 1: Write failing validator tests**

Create temporary-site tests with these exact cases:

```python
class PublicSiteValidatorTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)

    def make_site(self, body, assets=None):
        root = Path(self.temporary_directory.name)
        (root / "index.html").write_text(body, encoding="utf-8")
        for relative_path, content in (assets or {}).items():
            target = root / relative_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        return root

    def test_reports_missing_internal_link(self):
        root = self.make_site('<a href="missing.html">Missing</a>')
        self.assertIn("missing internal target", "\n".join(validate_site(root, root)))

    def test_rejects_machine_specific_path(self):
        root = self.make_site('<p>C:\\Users\\games\\secret</p>')
        self.assertIn("machine-specific path", "\n".join(validate_site(root, root)))

    def test_rejects_external_runtime_asset(self):
        root = self.make_site('<script src="https://cdn.example/app.js"></script>')
        self.assertIn("external runtime asset", "\n".join(validate_site(root, root)))

    def test_requires_image_description(self):
        root = self.make_site('<img src="screen.png">', {"screen.png": b"png"})
        self.assertIn("missing alt text", "\n".join(validate_site(root, root)))
```

- [ ] **Step 2: Run the red test**

Run `python -m unittest tests.test_public_site_validator -v`.

Expected: import failure because `tools.validate_public_site` does not exist.

- [ ] **Step 3: Implement the validator**

Use `html.parser`, `pathlib`, `hashlib`, and `urllib.parse`. Define:

```python
REQUIRED_PAGES = {
    "index.html", "method.html", "planner.html", "test-workflow.html",
    "results.html", "physical-setup.html", "audit.html", "evidence.html",
}
FORBIDDEN_TEXT = ("transition width", "C:\\Users\\", "localhost")
REQUIRED_TEXT = (
    "middle gap", "overall variation", "reliable operating gap",
    "211", "191", "63", "0.015 mm", "two decimal places",
)
```

Collect `href` and `src`; check that relative targets exist; reject remote scripts, styles, images, media, and frames; require useful `alt` text. `validate_page_shell` checks one `h1`, the skip link, title, viewport, navigation label, and local stylesheet for every required page. Compare SHA-256 for the public `.mlx`, report, and seven screenshots with the reviewed repository sources. The command prints every problem and returns code 1, or prints `Public site validation passed` and returns code 0.

- [ ] **Step 4: Run the green validator tests**

Run `python -m unittest tests.test_public_site_validator -v`.

Expected: all validator tests pass.

- [ ] **Step 5: Commit**

```powershell
git add tools/validate_public_site.py tests/test_public_site_validator.py
git commit -m "test: add public site safety validator"
```

---

### Task 2: Build the visual foundation and starting pages

**Files:**
- Create: `site/assets/site.css`
- Create: `site/index.html`
- Create: `site/method.html`
- Modify: `tests/test_public_site_validator.py`

**Interfaces:**
- Consumes: wording and colours from the approved specification.
- Produces: `.site-header`, `.workflow`, `.route-grid`, `.definition`, `.example`, `.caution`, `.verified`, `.gap-ruler`, and `.page-nav`.

- [ ] **Step 1: Add failing shell tests**

Require one `h1`, a skip link, descriptive title, viewport meta, labelled navigation, and `assets/site.css` on each real page.

```python
def test_real_pages_have_accessible_shell(self):
    self.assertEqual([], validate_page_shell(REPOSITORY_ROOT / "site"))
```

- [ ] **Step 2: Confirm the missing-page failure**

Run the validator unit suite. Expected: failure because the site shell does not exist.

- [ ] **Step 3: Create the visual system**

```css
:root {
  --ink: #17313b; --paper: #f7f8f5; --blue: #216c8d;
  --green: #2f7d68; --amber: #b56a1b; --red: #b84e3b;
  --line: #c8d2d5; --measure: 72ch;
}
body { margin: 0; color: var(--ink); background: var(--paper); font-family: "Segoe UI", Arial, sans-serif; line-height: 1.6; }
main { width: min(1180px, calc(100% - 2rem)); margin-inline: auto; }
@media (max-width: 760px) { .two-column, .route-grid { grid-template-columns: 1fr; } }
@media (prefers-reduced-motion: reduce) { *, *::before, *::after { scroll-behavior: auto !important; } }
```

Add visible `:focus-visible` styling and keep explanation lines comfortably short.

- [ ] **Step 4: Create the home page**

```html
<h1>Plan the study. Run each test. Understand the answer.</h1>
<p>Neyer Gap Test helps you choose useful physical gaps, record Interaction or No interaction, and estimate where the result changes.</p>
<a class="primary-action" href="test-workflow.html">Start the guided walkthrough</a>
```

Show Plan → Prepare → Test → Check → Finish, v1.10 status, and links to every focused page.

- [ ] **Step 5: Create the method page**

Use the physical-gap ruler and response curve. Include:

```html
<aside class="example">
  <h2>Example, not a real study result</h2>
  <p>A middle gap of 5.39 mm means approximately half of similar articles may interact there. It does not make 5.39 mm a safe operating gap.</p>
  <p>The example operating instruction is 2.30 mm or smaller for the planned Interaction target. That is a different answer for a different question.</p>
</aside>
```

- [ ] **Step 6: Verify and commit**

Run `python -m unittest tests.test_public_site_validator -v`, then commit the two pages, CSS, and updated tests with message `feat: add Neyer site foundation`.

---

### Task 3: Explain planning and the seven-screen workflow

**Files:**
- Create: `site/planner.html`
- Create: `site/test-workflow.html`
- Modify: `tests/test_public_site_validator.py`

**Interfaces:**
- Consumes: final planner wording and the seven verified screenshots.
- Produces: a line-by-line planner guide and ordered operator walkthrough.

- [ ] **Step 1: Add failing content tests**

Require planner explanations for result direction, reliability, confidence, required gap accuracy, endpoints, previous-study information, usable gap step, and available articles. Require workflow explanations for a new build, four or five readings, measured mean, two-decimal request, direction, and boundary pause.

- [ ] **Step 2: Confirm the missing-page failures**

Run the unit suite and verify the new assertions fail because the pages do not exist.

- [ ] **Step 3: Create the planner guide**

Use this pattern for every entry:

```html
<section class="definition" id="confidence">
  <h2>Confidence (%)</h2>
  <p><strong>What it means:</strong> How strongly the completed evidence must support the reliability answer.</p>
  <p><strong>Example:</strong> 95% confidence asks for a stronger evidence margin than 90% confidence.</p>
  <p class="caution"><strong>Important:</strong> Confidence is not the percentage of articles expected to interact. Reliability answers that different question.</p>
</section>
```

Explain the main estimate, reserve groups, and 400-article rule without presenting 400 as universal.

- [ ] **Step 4: Create the seven-screen guide**

Use seven numbered figures in the tested order. Give each image a useful description. Beside the requested-gap screen, explain:

```html
<p>If a requested 2.45 mm build measures 2.50, 2.50, 2.49, 2.52 and 2.48 mm, enter all five readings. Their mean, 2.498 mm, is used by the calculation.</p>
<p>The construction request remains 2.45 mm. The requested setting and measured mean are related but are not the same value.</p>
```

- [ ] **Step 5: Verify and commit**

Run the unit suite and commit the pages and tests with message `feat: add planner and test walkthrough`.

---

### Task 4: Explain results, physical setup, audit, and evidence

**Files:**
- Create: `site/results.html`
- Create: `site/physical-setup.html`
- Create: `site/audit.html`
- Create: `site/evidence.html`
- Modify: `tests/test_public_site_validator.py`

**Interfaces:**
- Consumes: final screenshots, audit records, and simulation summaries under `audit/overnight/`.
- Produces: the four remaining focused pages with no unsupported claim.

- [ ] **Step 1: Add failing evidence tests**

Parse `final-full-suite.txt`, `full-test-summary.txt`, `final-review-regressions.txt`, and `planner-validation-summary.csv`. Compare their recorded values with the visible evidence page.

- [ ] **Step 2: Confirm the missing-page failures**

Run the suite. Expected: failures naming the four missing pages.

- [ ] **Step 3: Create results and physical-setup pages**

Lead with the operating decision, then explain the middle and overall variation. Show this physical information without claiming it is fully confirmed:

| Item | Current information | Software treatment |
|---|---|---|
| Aluminium foil | Approximately 0.015 mm | Construction information only |
| 0.5 mm print | Observed around 0.49–0.52 mm | Measure the actual build |
| 1 mm print | One observation near 1.10 mm | Provisional |
| 2 mm print | One observation near 2.09 mm | Provisional |
| 0.5 + 1 + 2 mm | One combined observation near 3.67 mm | Does not prove every combination |

- [ ] **Step 4: Create audit and evidence pages**

Use a three-column audit table: area, v1.8 problem, v1.10 result. Cover Stage 1, 1.0× Stage-2 changeover, 0.8 narrowing, one-way Stage 2, confidence handling, reachable D-optimal selection, boundary confirmation, two-decimal request, and useful-setting stop.

Show exact evidence totals and frozen simulation outcomes. Link claims to repository evidence filenames without local paths.

- [ ] **Step 5: Verify and commit**

Run the unit suite and commit the four pages and tests with message `feat: document results audit and evidence`.

---

### Task 5: Package assets and run full local validation

**Files:**
- Create: `tools/prepare_public_site.ps1`
- Create: `site/.nojekyll`
- Create: files under `site/assets/screens/`, `site/downloads/`, and `site/reports/`
- Modify: `tools/validate_public_site.py`
- Modify: `tests/test_public_site_validator.py`

**Interfaces:**
- Consumes: seven repository screenshots and two files under `delivery/`.
- Produces: byte-identical public copies and a complete static site.

- [ ] **Step 1: Add failing fingerprint tests**

Require SHA-256 equality for the seven screenshots, `.mlx`, and report. A failure must name both relative paths.

- [ ] **Step 2: Confirm full validation fails before packaging**

Run `python tools/validate_public_site.py`. Expected: missing public copies.

- [ ] **Step 3: Implement non-destructive preparation**

The script creates required folders and uses `Copy-Item -LiteralPath`. Resolve each screenshot pattern to exactly one source. Stop if a source is missing. Do not recursively delete or clean a directory.

- [ ] **Step 4: Prepare and validate**

Run `tools/prepare_public_site.ps1` and then `python tools/validate_public_site.py`.

Expected: `Public site validation passed` with eight pages, seven screenshots, and two matching downloads.

- [ ] **Step 5: Scan and commit**

Run `rg -n "C:\\Users\\|localhost|transition width|github_pat_|ghp_" site` and `git diff --check`. The content scan must print no matches. Commit with `feat: package verified Neyer review site`.

---

### Task 6: Render desktop and phone layouts

**Files:**
- Create: `tools/capture_public_site.cjs`
- Create: `audit/site/site-desktop.png`
- Create: `audit/site/site-phone.png`
- Create: `audit/site/visual-review.txt`

**Interfaces:**
- Consumes: completed `site/` and locally available Playwright.
- Produces: deterministic desktop and phone images plus written inspection evidence.

- [ ] **Step 1: Implement capture script**

Serve only files inside `site/`, reject path traversal, launch Chromium, and capture:

```javascript
const viewports = [
  { name: "desktop", width: 1440, height: 1100 },
  { name: "phone", width: 390, height: 844 },
];
```

Report an error if `document.documentElement.scrollWidth > window.innerWidth`.

- [ ] **Step 2: Capture both layouts**

Set `NODE_PATH` to the bundled dependency directory returned by `load_workspace_dependencies`, then run the bundled Node executable. Expected: two PNGs and no horizontal-overflow error.

- [ ] **Step 3: Inspect both images**

Check hero, workflow, navigation, gap ruler, text size, phone stacking, and focus styling. Record concrete observations in `audit/site/visual-review.txt`.

- [ ] **Step 4: Correct and recapture if needed**

When a visual problem appears, edit CSS, rerun the validator, and regenerate both images. Retain only corrected evidence.

- [ ] **Step 5: Commit visual evidence**

Commit the script and evidence with message `test: verify public site layouts`.

---

### Task 7: Publish through GitHub Pages

**Files:**
- Create: `.github/workflows/pages.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: validated `site/` artifact.
- Produces: verified live GitHub Pages site.

- [ ] **Step 1: Create workflow**

```yaml
name: Publish Neyer review site
on:
  push:
    branches: [codex/neyer-v110, main]
    paths: ["site/**", "tools/validate_public_site.py", ".github/workflows/pages.yml"]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
  actions: read
jobs:
  validate-and-deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: python3 tools/validate_public_site.py
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v5
        with:
          path: site
      - id: deployment
        uses: actions/deploy-pages@v5
```

- [ ] **Step 2: Run release checks**

Run the site validator, unit tests, `git diff --check`, sensitive-string scan, and `git status --short`.

- [ ] **Step 3: Commit, enable, and push**

Commit with `ci: publish Neyer review site`. Use the GitHub Pages API to set build type to `workflow`, then push `codex/neyer-v110` normally. Do not force-push.

- [ ] **Step 4: Wait for real workflow status**

Use the GitHub workflow result rather than a guessed delay. On failure, inspect logs, correct the cause, rerun local checks, and push a normal follow-up commit.

- [ ] **Step 5: Verify live resources**

Require successful HTTPS responses for the home page, `test-workflow.html`, first walkthrough image, `.mlx` download, and HTML report. Confirm the home page contains `Plan the study. Run each test. Understand the answer.` and live download hashes match the reviewed files.

- [ ] **Step 6: Inspect live desktop and phone views**

Render both widths again. Only after they are correct, add the verified address to `README.md`, run `git diff --check`, commit with `docs: add verified Neyer site`, and push normally.

- [ ] **Step 7: Report completion**

Give the user the live address, exact branch and commit, local and live validation results, workflow outcome, download checks, remaining physical-measurement limitation, and any observed college-network limitation.
