# Neyer GitHub Pages Review Site Design

## Purpose

Create a public, phone-friendly project site for the final ChatGPT Neyer work. The site must let the user review the complete v1.10 workflow from a college computer without MATLAB, OneDrive, local file paths, or `localhost`.

The public address will be:

`https://xcloudy75z.github.io/CHATGPT-Neyer/`

## Audience and main job

The first audience is the project owner reviewing from a college computer or phone. A second audience is a classmate or instructor who has no programming background.

The site's main job is to answer five questions:

1. What problem does the Neyer tool solve?
2. What information does the user enter?
3. What happens during a test?
4. What do the middle gap, overall variation, reliability and confidence mean?
5. What was corrected and how was v1.10 checked?

## Selected approach

Use a hybrid project hub inspired by the existing Car Service project hub and the plain-language guides in the older NyerS site.

- The front page gives a short project explanation, current status and clear routes into the material.
- Focused pages explain one subject at a time, preventing one extremely long and tiring report.
- A guided walkthrough presents the seven verified MATLAB screens in their real order.
- The old Claude-era NyerS site is not presented as the current implementation.

Rejected alternatives:

- A single long report page: too dense for the user's visual review style.
- A large directory of documents: too many choices before the reader understands where to begin.
- A live web copy of the calculation tool: outside the current goal and risks creating a second implementation whose mathematics could drift from MATLAB.

## Site map

### Home

- Project name and one-sentence purpose.
- A simple path: Plan, Prepare, Test, Check, Finish.
- Current v1.10 status, supported MATLAB release and recorded test totals.
- Primary action: Start the guided walkthrough.
- Secondary actions: Understand the method, see audit findings, inspect testing evidence and download the standalone Live Script.

### How the method works

- Interaction becomes less likely as the physical gap increases.
- A simple response-curve visual.
- Middle gap explained as the approximately 50/50 point.
- Overall variation explained as how much the result changes from article to article around the middle.
- Reliable operating gap explained separately from the middle gap.
- A worked example using the published demonstration values, clearly labelled as an example rather than a real project result.

### Pre-Test Planner

- Every question shown in the order used by the MATLAB screen.
- For each entry: what it means, why it is needed, what the user should enter, a gap example and a caution where required.
- Main articles and reserve groups kept separate.
- The 400-article reliability safety rule described as a conservative rule supported by this project's simulations, not a universal Neyer number.

### Run a Test

- The seven verified MATLAB screens shown in order.
- Requested gap and measured mean kept visibly separate.
- Four or five readings described as repeated measurements of one unchanged spacer build.
- Each destructive test described as requiring a newly built setup.
- Interaction and No interaction direction shown clearly.
- Boundary confirmation and safe pause explained without calling the specimen result a software failure.

### Understand the results

- Decision shown first.
- Middle gap, overall variation and their confidence ranges explained in plain language.
- Reliable operating instruction kept separate from the 50/50 middle.
- Values outside the tested range identified as estimates, not usable settings.
- Saving behaviour explained: the user chooses a location, sees the exact CSV and HTML paths, confirms them, and existing files are not silently replaced.

### Physical spacers and reachable gaps

- Current physical information listed as provisional: approximately 0.015 mm foil and nominal 0.5, 1 and 2 mm printed spacers with observed variation.
- Foil thickness described as construction information, not proof of a usable 0.015 mm testing step.
- Requested gaps displayed with two decimal places.
- The statistical calculation uses the measured mean while the construction request remains the reachable build setting.
- A visible note states that final reachable combinations still depend on the user's physical confirmation measurements.

### Audit and corrections

- A before-and-after table covering Stage 1, Stage 2 changeover, 0.8 narrowing, MLE confidence handling, D-optimal selection, bounds, rounding and stopping.
- Problems found in v1.8 kept separate from changes made in v1.10.
- The final independent-review corrections included: fail-closed safety fields, no false 0.015 mm resolution inference and no post-selection clamp that creates an unreachable request.

### Testing evidence

- 211 complete MATLAB checks passed with zero failures or incomplete checks.
- 191 mock-laboratory checks across seven routes passed.
- 63 focused final-review safety regressions passed.
- Frozen 12-scenario simulation: eight supported cases accepted, zero supported cases rejected and four unsupported confidence cases deliberately withheld.
- Seven final screen captures displayed.
- Every number sourced from the committed audit evidence; no invented claim is allowed.

### Downloads and reports

- Standalone `Neyer_Gap_Test_v1_10.mlx` served directly from the Pages site.
- `Neyer_Overnight_Verification_Report.html` available as a browser-readable detailed report.
- GitHub repository and exact release commit linked.
- MATLAB R2022b requirement and remaining physical-measurement limitation stated beside the download.

## Plain-language rules

- Use `overall variation` as the main label and explain `sigma` only as its mathematical name.
- Do not use `transition width`.
- Define a technical term in the same paragraph where it first appears.
- Prefer physical gap examples in millimetres to formulas.
- Keep sentences short and use active voice.
- Do not call the middle gap reliable or safe.
- Do not describe 298 or 299 articles as the Neyer estimation quantity.
- Clearly label published demonstration numbers as examples.

## Visual design

The page will resemble a calm engineering workbook rather than a software marketing page.

### Colour tokens

- Ink: `#17313B` for primary text.
- Paper: `#F7F8F5` for the main background.
- Blueprint blue: `#216C8D` for explanation and navigation.
- Verified green: `#2F7D68` only for supported or passed results.
- Caution amber: `#B56A1B` for limitations and checks.
- Action red: `#B84E3B` only when the user must stop or correct something.

### Type and layout

- Use system fonts so the site has no external font dependency.
- Left-align explanations and keep text lines comfortably short.
- Use a clear two-column layout on wide screens and one column on phones.
- Use real sequence numbers only for the genuine Plan-to-Finish workflow.
- Avoid generic repeated cards, decorative gradients and unnecessary motion.
- Use borders, callouts and colour only when they communicate meaning.

### Memorable visual element

The main visual is a horizontal physical-gap ruler connected to the response curve. It shows that smaller gaps make Interaction more likely and larger gaps make No interaction more likely. The middle and reliable operating gap are shown as different markers.

## Technical structure

- A static website under `site/` with no server, database, login, tracking or external runtime dependency.
- Shared local CSS and minimal local JavaScript for navigation and optional expand/collapse explanations.
- All screenshots and icons stored inside `site/assets/`.
- All internal links use relative paths so the project-site address works correctly.
- The final `.mlx` and HTML report are copied into `site/downloads/` during the verified build.
- The website never performs the Neyer calculations; it explains and documents the reviewed MATLAB implementation.

## Publishing

A GitHub Actions workflow will publish only the `site/` folder through GitHub Pages when the release branch or later `main` branch is updated. The workflow will use GitHub's official Pages actions and the standard `github-pages` deployment environment.

The Pages setting will be changed to GitHub Actions only after the local site passes validation. The live address will not be given to the user until the deployment succeeds and the actual HTTPS page and key assets return successfully.

## Validation

Before publication:

- Check every internal link, image and download target.
- Check required headings, exact test totals and required definitions.
- Reject unexplained jargon and the phrase `transition width`.
- Confirm no external script, style, font, tracker or analytics request exists.
- Render and inspect the site at a desktop width and a phone width.
- Check visible keyboard focus, useful image descriptions and readable colour contrast.
- Check the site contains no secrets, temporary logs or machine-specific paths.
- Confirm the `.mlx` and HTML download fingerprints match the verified delivery files.

After publication:

- Confirm the GitHub Pages deployment reports success.
- Confirm the public home page returns successfully over HTTPS.
- Confirm at least one walkthrough image, the `.mlx` download and the HTML report return successfully.
- Recheck the live page at both desktop and phone widths.

## Boundaries

- This site is documentation and a review aid, not a browser replacement for MATLAB.
- It makes no new reliability claim and changes none of the reviewed Neyer mathematics.
- Physical spacer combinations remain provisional until the user completes the planned measurements.
- The PowerPoint remains outside this website task unless separately requested.
