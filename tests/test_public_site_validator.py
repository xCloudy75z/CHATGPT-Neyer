import csv
import re
import subprocess
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path

from tools.validate_public_site import validate_page_shell, validate_site


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]

VOID_ELEMENTS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


class ContentStructureParser(HTMLParser):
    """Parse the planner and walkthrough contracts, including closing tags."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.open_tags = []
        self.errors = []
        self.definitions = []
        self.figures = []
        self._definition = None
        self._heading_definition = None
        self._figure = None
        self._in_caption = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag not in VOID_ELEMENTS:
            self.open_tags.append(tag)
        if tag == "section" and "definition" in attributes.get("class", "").split():
            if self._definition is not None:
                self.errors.append("nested definition")
            self._definition = {
                "id": attributes.get("id", ""),
                "heading": [],
                "text": [],
                "closed": False,
            }
        if tag == "h2" and self._definition is not None:
            self._heading_definition = self._definition
        if tag == "figure":
            if self._figure is not None:
                self.errors.append("nested figure")
            self._figure = {"src": "", "alt": "", "style": "", "caption": [], "closed": False}
        if tag == "img" and self._figure is not None:
            self._figure["src"] = attributes.get("src", "")
            self._figure["alt"] = attributes.get("alt", "")
            self._figure["style"] = attributes.get("style", "")
        if tag == "figcaption" and self._figure is not None:
            self._in_caption = True

    def handle_endtag(self, tag):
        if tag not in VOID_ELEMENTS:
            if not self.open_tags or self.open_tags[-1] != tag:
                self.errors.append(f"unmatched closing tag: {tag}")
            else:
                self.open_tags.pop()
        if tag == "h2":
            self._heading_definition = None
        if tag == "figcaption":
            self._in_caption = False
        if tag == "figure":
            if self._figure is None:
                self.errors.append("figure closed without opening")
            else:
                self._figure["closed"] = True
                self.figures.append(self._figure)
                self._figure = None
        if tag == "section" and self._definition is not None:
            self._definition["closed"] = True
            self.definitions.append(self._definition)
            self._definition = None

    def handle_data(self, data):
        if self._definition is not None:
            self._definition["text"].append(data)
        if self._heading_definition is not None:
            self._heading_definition["heading"].append(data)
        if self._in_caption and self._figure is not None:
            self._figure["caption"].append(data)

    def finish(self):
        if self.open_tags:
            self.errors.append(f"unclosed tags: {', '.join(self.open_tags)}")
        if self._definition is not None:
            self.errors.append("unclosed definition")
        if self._figure is not None:
            self.errors.append("unclosed figure")
        return self


def parse_content_structure(markup):
    parser = ContentStructureParser()
    parser.feed(markup)
    parser.close()
    return parser.finish()


def normalise_text(parts):
    return " ".join("".join(parts).split())


class VisibleTextParser(HTMLParser):
    """Collect reader-visible text while ignoring comments and hidden content."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.text = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        style = attributes.get("style", "").replace(" ", "").lower()
        inherited_hidden = bool(self.stack and self.stack[-1]["hidden"])
        is_hidden = inherited_hidden or (
            tag in {"script", "style", "template"}
            or "hidden" in attributes
            or attributes.get("aria-hidden", "").lower() == "true"
            or "display:none" in style
            or "visibility:hidden" in style
        )
        if tag not in VOID_ELEMENTS:
            self.stack.append({"tag": tag, "hidden": is_hidden})

    def handle_endtag(self, tag):
        if tag not in VOID_ELEMENTS and self.stack and self.stack[-1]["tag"] == tag:
            self.stack.pop()

    def handle_data(self, data):
        if not self.stack or not self.stack[-1]["hidden"]:
            self.text.append(data)


def visible_text(markup):
    parser = VisibleTextParser()
    parser.feed(markup)
    parser.close()
    return normalise_text(parser.text)


class EvidenceResultParser(HTMLParser):
    """Parse visible, direct result rows from the one evidence-results list."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.result_list_count = 0
        self.items = []
        self.active_item = None

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        style = attributes.get("style", "").replace(" ", "").lower()
        parent = self.stack[-1] if self.stack else None
        inherited_hidden = bool(parent and parent["hidden"])
        hidden = inherited_hidden or (
            tag in {"script", "style", "template"}
            or "hidden" in attributes
            or attributes.get("aria-hidden", "").lower() == "true"
            or "display:none" in style
            or "visibility:hidden" in style
        )
        is_result_list = (
            tag == "ul" and "evidence-results" in attributes.get("class", "").split()
        )
        entry = {"tag": tag, "hidden": hidden, "result_list": is_result_list}
        if tag not in VOID_ELEMENTS:
            self.stack.append(entry)
        if is_result_list:
            self.result_list_count += 1
        if tag == "li" and parent and parent["result_list"]:
            self.active_item = {"text": [], "hidden": hidden}
            self.items.append(self.active_item)

    def handle_endtag(self, tag):
        if tag in VOID_ELEMENTS or not self.stack or self.stack[-1]["tag"] != tag:
            return
        entry = self.stack.pop()
        if tag == "li" and self.active_item is not None:
            self.active_item = None

    def handle_data(self, data):
        if self.active_item is not None and self.stack and not self.stack[-1]["hidden"]:
            self.active_item["text"].append(data)


def evidence_result_structure(markup):
    parser = EvidenceResultParser()
    parser.feed(markup)
    parser.close()
    return parser.result_list_count, [normalise_text(item["text"]) for item in parser.items]


def recorded_count(repository_root, filename, label):
    record = (repository_root / "audit" / "overnight" / filename).read_text(
        encoding="utf-8"
    )
    match = re.search(rf"^{re.escape(label)}: (\d+)$", record, re.MULTILINE)
    if match is None:
        raise ValueError(f"missing {label} in {filename}")
    return match.group(1)


def evidence_page_problems(repository_root, markup):
    """Return reader-visible mismatches against the executed evidence records."""
    text = visible_text(markup)
    result_list_count, result_items = evidence_result_structure(markup)
    records = (
        ("final-full-suite.txt", "complete MATLAB checks", ""),
        ("full-test-summary.txt", "mock-laboratory checks", " across {} routes"),
        ("final-review-regressions.txt", "focused final-review safety regressions", ""),
    )
    problems = []
    if result_list_count != 1:
        problems.append("expected exactly one evidence-results list")
    for filename, description, route_suffix in records:
        passed = recorded_count(repository_root, filename, "Passed")
        failed = recorded_count(repository_root, filename, "Failed")
        incomplete = recorded_count(repository_root, filename, "Incomplete")
        routes = recorded_count(repository_root, filename, "Routes") if route_suffix else ""
        expected = (
            f"{passed} {description}{route_suffix.format(routes)}: "
            f"{failed} failed and {incomplete} incomplete."
        )
        named_items = [item for item in result_items if description in item]
        if named_items != [expected]:
            problems.append(f"visible {description} result row does not match {filename}")
        if text.count(description) != 1:
            problems.append(f"expected exactly one visible {description} claim")

    with (repository_root / "audit" / "overnight" / "planner-validation-summary.csv").open(
        encoding="utf-8", newline=""
    ) as source:
        scenarios = list(csv.DictReader(source))
    conclusions = {row["conclusion"] for row in scenarios}
    unknown = conclusions - {"accepted", "withheld"}
    if unknown:
        problems.append(f"unknown planner conclusions: {sorted(unknown)}")
        return problems
    repetitions = {row["repetitions"] for row in scenarios}
    if repetitions != {"40"}:
        problems.append(f"planner repetitions are not all 40: {sorted(repetitions)}")
    accepted = [row for row in scenarios if row["conclusion"] == "accepted"]
    withheld = [row for row in scenarios if row["conclusion"] == "withheld"]
    accepted_confidence = {row["confidence"] for row in accepted}
    withheld_confidence = {row["confidence"] for row in withheld}
    if accepted_confidence != {"0.95"}:
        problems.append(f"accepted confidence classes changed: {sorted(accepted_confidence)}")
    if withheld_confidence != {"0.1", "0.499", "0.5", "0.999"}:
        problems.append(f"withheld confidence classes changed: {sorted(withheld_confidence)}")
    expected_scenarios = (
        f"{len(scenarios)} scenarios with 40 repetitions each: "
        f"{len(accepted)} supported 95% confidence cases accepted; "
        f"0 supported cases rejected; {len(withheld)} unsupported confidence cases deliberately withheld "
        "at 10%, 49.9%, 50%, or 99.9% confidence."
    )
    if expected_scenarios not in text:
        problems.append("visible planner-validation result does not match its scenario classes")
    return problems


class PublicSiteValidatorTests(unittest.TestCase):
    def test_evidence_page_matches_the_committed_audit_records(self):
        """Catches hidden, detached, or drifted evidence claims on the public page."""
        evidence = (REPOSITORY_ROOT / "site" / "evidence.html").read_text(
            encoding="utf-8"
        )
        self.assertEqual([], evidence_page_problems(REPOSITORY_ROOT, evidence))

        correct_mock_result = "191 mock-laboratory checks across 7 routes: 0 failed and 0 incomplete."
        wrong_mock_result = evidence.replace(
            correct_mock_result,
            "191 mock-laboratory checks across 7 routes: 99 failed and 88 incomplete.",
        )
        self.assertTrue(evidence_page_problems(REPOSITORY_ROOT, wrong_mock_result))
        detached_conflict = wrong_mock_result.replace(
            "</main>", f"<p>{correct_mock_result}</p></main>"
        )
        self.assertTrue(evidence_page_problems(REPOSITORY_ROOT, detached_conflict))
        detached_duplicate = evidence.replace(
            "</main>", f"<p>{correct_mock_result}</p></main>"
        )
        self.assertTrue(evidence_page_problems(REPOSITORY_ROOT, detached_duplicate))
        nested_hidden = wrong_mock_result.replace(
            "</main>",
            f"<div hidden><div>cover</div><span>{correct_mock_result}</span></div></main>",
        )
        self.assertTrue(evidence_page_problems(REPOSITORY_ROOT, nested_hidden))

    def test_evidence_validation_rejects_unknown_conclusions_and_wrong_repetitions(self):
        """Catches a planner summary that silently relabels unsupported scenarios."""
        summary = REPOSITORY_ROOT / "audit" / "overnight" / "planner-validation-summary.csv"
        source = summary.read_text(encoding="utf-8")
        unknown = source.replace(",accepted\n", ",review\n", 1)
        wrong_repetitions = source.replace(",40,", ",39,", 1)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            audit = root / "audit" / "overnight"
            audit.mkdir(parents=True)
            for filename in (
                "final-full-suite.txt",
                "full-test-summary.txt",
                "final-review-regressions.txt",
            ):
                (audit / filename).write_text(
                    (REPOSITORY_ROOT / "audit" / "overnight" / filename).read_text(
                        encoding="utf-8"
                    ),
                    encoding="utf-8",
                )
            evidence = (REPOSITORY_ROOT / "site" / "evidence.html").read_text(
                encoding="utf-8"
            )
            (audit / summary.name).write_text(unknown, encoding="utf-8")
            self.assertIn("unknown planner conclusions", "\n".join(evidence_page_problems(root, evidence)))
            (audit / summary.name).write_text(wrong_repetitions, encoding="utf-8")
            self.assertIn("planner repetitions are not all 40", "\n".join(evidence_page_problems(root, evidence)))

    def test_audit_uses_immutable_evidence_links_and_defines_technical_terms(self):
        """Catches release-broken links and unexplained audit terminology."""
        audit = (REPOSITORY_ROOT / "site" / "audit.html").read_text(encoding="utf-8")
        results = (REPOSITORY_ROOT / "site" / "results.html").read_text(encoding="utf-8")
        reviewed = "https://github.com/xCloudy75z/CHATGPT-Neyer/blob/c78e7ed/"
        self.assertNotIn("/blob/main/", audit)
        self.assertNotIn("/blob/main/", (REPOSITORY_ROOT / "site" / "evidence.html").read_text(encoding="utf-8"))
        self.assertIn(reviewed + "delivery/Neyer_Overnight_Verification_Report.html#audit", audit)
        for filename in (
            "audit/overnight/final-full-suite.txt",
            "audit/overnight/full-test-summary.txt",
            "audit/overnight/final-review-regressions.txt",
            "audit/overnight/planner-validation-summary.csv",
        ):
            self.assertIn(reviewed + filename, (REPOSITORY_ROOT / "site" / "evidence.html").read_text(encoding="utf-8"))
        audit_text = visible_text(audit)
        for definition in (
            "Bound-aware means using earlier lower and upper middle-gap estimates to decide how far Stage 1 searches.",
            "Physical permitted limits are applied separately after selection.",
            "Bisection means repeatedly halving the range between observed Interaction and No interaction.",
            "Strict overlap means the Interaction and No interaction ranges share more than a touching endpoint.",
            "D-optimal means choosing the next gap expected to add the most useful information.",
            "One-sided confidence sets a cautious operating boundary in one safe direction.",
        ):
            self.assertIn(definition, audit_text)
        self.assertIn(
            "The middle-gap and overall-variation ranges are two-sided confidence ranges with lower and upper estimates.",
            visible_text(results),
        )
        self.assertIn(
            "Operating tail boundaries use one-sided confidence in the safe direction.",
            visible_text(results),
        )

    def test_planner_guide_gives_each_question_its_own_explanation(self):
        """Catches a planner guide that collapses distinct fields into loose prose."""
        planner = (REPOSITORY_ROOT / "site" / "planner.html").read_text(
            encoding="utf-8"
        )
        parser = parse_content_structure(planner)
        self.assertEqual([], parser.errors)
        expected_entries = {
            "planning-question": "Planning question",
            "available-articles": "Maximum articles available",
            "fixed-requirement": "Keep this requirement fixed",
            "result-direction": "Required physical result",
            "reliability": "Reliability (%)",
            "confidence": "Confidence (%)",
            "accuracy": "Required gap accuracy (+/- mm)",
            "interaction-endpoint": "Almost-always Interaction gap (mm)",
            "no-interaction-endpoint": "Almost-always No-interaction gap (mm)",
            "previous-information": "Earlier information",
            "minimum-gap": "Minimum permitted gap (mm)",
            "maximum-gap": "Maximum permitted gap (mm)",
            "physical-method": "Physical setup method",
            "regular-increment": "Regular increment (mm)",
            "confirmed-gaps": "Confirmed gaps (mm)",
            "measured-components": "Measured components and maximum count",
            "usable-step": "Usable gap step",
        }
        entries = {entry["id"]: entry for entry in parser.definitions}
        self.assertEqual(set(expected_entries), set(entries))
        for entry_id, expected_heading in expected_entries.items():
            entry = entries[entry_id]
            self.assertTrue(entry["closed"])
            self.assertEqual(expected_heading, normalise_text(entry["heading"]))
            entry_text = normalise_text(entry["text"])
            self.assertIn("What it means:", entry_text)
            self.assertIn("Example:", entry_text)
            self.assertIn("Important:", entry_text)

        accuracy_text = normalise_text(entries["accuracy"]["text"])
        self.assertIn("middle-gap estimate", accuracy_text)
        self.assertNotIn("estimated operating gap", accuracy_text)
        self.assertIn("not used automatically", planner)
        self.assertIn("not a universal", planner)
        self.assertIn("does not include the optional fixed-gap zero-failure qualification planner", planner)
        self.assertIn("298 is the specific fixed-condition rule", planner)
        self.assertIn("299 is the conservative general calculation", planner)
        self.assertIn("neither is a Neyer curve-study quantity", planner)

    def test_content_structure_rejects_collapsed_or_unclosed_mutations(self):
        """Proves one keyword-filled block and unclosed figures cannot satisfy Task 3."""
        collapsed_planner = '<section class="definition" id="planning-question"><h2>Planning question</h2>What it means: Example: Important:'
        malformed_workflow = '<figure><img src="assets/screens/v110-01-main-menu.png" alt="A useful screen description with enough specific detail."><figcaption>1. Main menu.</figcaption>'
        self.assertTrue(parse_content_structure(collapsed_planner).errors)
        self.assertTrue(parse_content_structure(malformed_workflow).errors)

    def test_workflow_guide_uses_the_seven_verified_screens_in_order(self):
        """Catches reordered, uncaptioned, non-descriptive, or phone-overflowing screens."""
        workflow = (REPOSITORY_ROOT / "site" / "test-workflow.html").read_text(
            encoding="utf-8"
        )
        parser = parse_content_structure(workflow)
        self.assertEqual([], parser.errors)
        expected_screens = (
            ("v110-01-main-menu.png", "1. Main menu.", "buttons"),
            ("v110-02-planner-input.png", "2. Planner inputs.", "planning choices"),
            ("v110-03-planner-review.png", "3. Planner review.", "reserve groups"),
            ("v110-04-test-inputs.png", "4. Test inputs.", "usable gap step"),
            ("v110-05-requested-gap.png", "5. Requested gap and outcome.", "four or five measured gaps"),
            ("v110-06-results.png", "6. Results.", "operating instruction"),
            ("v110-07-help.png", "7. Help and boundary protection.", "boundary protection"),
        )
        self.assertEqual(7, len(parser.figures))
        for figure, (name, caption, alt_marker) in zip(parser.figures, expected_screens):
            self.assertTrue(figure["closed"])
            self.assertEqual(f"assets/screens/{name}", figure["src"])
            self.assertTrue(normalise_text(figure["caption"]).startswith(caption))
            self.assertIn(alt_marker, figure["alt"].lower())
            self.assertGreaterEqual(len(figure["alt"].split()), 8)
            self.assertIn("max-width: 100%", figure["style"])
            self.assertIn("height: auto", figure["style"])

        for required_explanation in (
            "newly built setup",
            "four or five readings",
            "measured mean",
            "two decimal places",
            "Interaction",
            "No interaction",
            "boundary pause",
            "2.45 mm",
            "2.498 mm",
        ):
            self.assertIn(required_explanation, workflow)

    def test_real_pages_have_accessible_shell(self):
        self.assertEqual([], validate_page_shell(REPOSITORY_ROOT / "site"))

    def test_home_page_states_release_and_links_to_live_script(self):
        home_page = (REPOSITORY_ROOT / "site" / "index.html").read_text(
            encoding="utf-8"
        )
        self.assertIn("MATLAB R2022b", home_page)
        self.assertIn('href="downloads/Neyer_Gap_Test_v1_10.mlx"', home_page)

    def test_fingerprint_mismatch_names_both_relative_release_paths(self):
        """Makes a changed public release file actionable without local paths."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            site = root / "site"
            public_copy = site / "downloads" / "Neyer_Gap_Test_v1_10.mlx"
            reviewed_copy = root / "delivery" / "Neyer_Gap_Test_v1_10.mlx"
            public_copy.parent.mkdir(parents=True)
            reviewed_copy.parent.mkdir(parents=True)
            public_copy.write_bytes(b"changed public release")
            reviewed_copy.write_bytes(b"reviewed release")

            problems = validate_site(site, root)

        self.assertIn(
            "fingerprint mismatch: downloads/Neyer_Gap_Test_v1_10.mlx "
            "!= delivery/Neyer_Gap_Test_v1_10.mlx",
            problems,
        )

    def test_preparation_script_copies_exact_assets_without_removing_public_files(self):
        """Requires a literal-path, repeatable packager rather than a clean operation."""
        script = REPOSITORY_ROOT / "tools" / "prepare_public_site.ps1"
        self.assertTrue(script.is_file())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = {
                "delivery/Neyer_Gap_Test_v1_10.mlx": b"standalone release",
                "delivery/Neyer_Overnight_Verification_Report.html": b"offline report",
            }
            expected.update(
                {
                    f"assets/screenshots/{name}": name.encode("ascii")
                    for name in (
                        "v110-01-main-menu.png",
                        "v110-02-planner-input.png",
                        "v110-03-planner-review.png",
                        "v110-04-test-inputs.png",
                        "v110-05-requested-gap.png",
                        "v110-06-results.png",
                        "v110-07-help.png",
                    )
                }
            )
            for relative_path, content in expected.items():
                source = root / relative_path
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes(content)
            preserved = root / "site" / "keep-this-public-file.txt"
            preserved.parent.mkdir(parents=True)
            preserved.write_bytes(b"keep")

            result = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-RepositoryRoot",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            self.assertEqual(b"keep", preserved.read_bytes())
            public_paths = {
                "delivery/Neyer_Gap_Test_v1_10.mlx": "site/downloads/Neyer_Gap_Test_v1_10.mlx",
                "delivery/Neyer_Overnight_Verification_Report.html": "site/reports/Neyer_Overnight_Verification_Report.html",
            }
            public_paths.update(
                {
                    f"assets/screenshots/{name}": f"site/assets/screens/{name}"
                    for name in (
                        "v110-01-main-menu.png",
                        "v110-02-planner-input.png",
                        "v110-03-planner-review.png",
                        "v110-04-test-inputs.png",
                        "v110-05-requested-gap.png",
                        "v110-06-results.png",
                        "v110-07-help.png",
                    )
                }
            )
            for source_path, public_path in public_paths.items():
                self.assertEqual(
                    (root / source_path).read_bytes(),
                    (root / public_path).read_bytes(),
                    public_path,
                )

    def test_preparation_script_reports_missing_source_without_removing_public_files(self):
        """A missing first source must name its relative path and preserve public files."""
        script = REPOSITORY_ROOT / "tools" / "prepare_public_site.ps1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            preserved = root / "site" / "keep-this-public-file.txt"
            preserved.parent.mkdir(parents=True)
            preserved.write_bytes(b"keep")

            result = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-RepositoryRoot",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(0, result.returncode)
            self.assertIn(
                "Required reviewed source is missing: delivery/Neyer_Gap_Test_v1_10.mlx",
                result.stderr,
            )
            self.assertEqual(b"keep", preserved.read_bytes())
            self.assertFalse((root / "site" / "downloads").exists())

    def test_preparation_script_reports_directory_source_without_removing_public_files(self):
        """A directory in place of a source must be clear and leave public files alone."""
        script = REPOSITORY_ROOT / "tools" / "prepare_public_site.ps1"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "delivery" / "Neyer_Gap_Test_v1_10.mlx").mkdir(parents=True)
            preserved = root / "site" / "keep-this-public-file.txt"
            preserved.parent.mkdir(parents=True)
            preserved.write_bytes(b"keep")

            result = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(script),
                    "-RepositoryRoot",
                    str(root),
                ],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertNotEqual(0, result.returncode)
            self.assertIn(
                "Required reviewed source is not a file: delivery/Neyer_Gap_Test_v1_10.mlx",
                result.stderr,
            )
            self.assertEqual(b"keep", preserved.read_bytes())
            self.assertFalse((root / "site" / "downloads").exists())

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

    def test_rejects_internal_links_that_escape_site_root(self):
        root = self.make_site(
            '<a href="../outside.html">Relative</a>'
            '<a href="%2e%2e/encoded.html">Encoded</a>'
            '<a href="/root.html?view=full">Root</a>'
        )
        problems = "\n".join(validate_site(root, root))
        self.assertIn("invalid internal target: ../outside.html", problems)
        self.assertIn("invalid internal target: %2e%2e/encoded.html", problems)
        self.assertIn("invalid internal target: /root.html?view=full", problems)

    def test_allows_same_page_fragment_and_query_on_local_link(self):
        root = self.make_site('<a href="#summary">Skip</a><a href="index.html?view=full">View</a>')
        problems = "\n".join(validate_site(root, root))
        self.assertNotIn("missing internal target: index.html?view=full", problems)
        self.assertNotIn("invalid internal target", problems)

    def test_rejects_network_resources_loaded_by_local_css(self):
        root = self.make_site(
            '<link rel="stylesheet" href="assets/site.css">',
            {
                "assets/site.css": (
                    b'@import url("https://fonts.example/font.css");'
                    b'.chart { background-image: url(https://cdn.example/chart.png); }'
                )
            },
        )
        self.assertIn("external runtime asset", "\n".join(validate_site(root, root)))

    def test_rejects_network_resources_in_srcset_and_poster(self):
        root = self.make_site(
            '<img srcset="screen.png 1x, https://cdn.example/screen.png 2x" alt="Screen">'
            '<video poster="https://cdn.example/poster.png"></video>',
            {"screen.png": b"png"},
        )
        problems = "\n".join(validate_site(root, root))
        self.assertIn("external runtime asset: https://cdn.example/screen.png", problems)
        self.assertIn("external runtime asset: https://cdn.example/poster.png", problems)

    def test_requires_exact_numeric_evidence_totals(self):
        root = self.make_site(
            "middle gap overall variation reliable operating gap "
            "2110 1910 630 0.015 mm two decimal places"
        )
        problems = "\n".join(validate_site(root, root))
        self.assertIn("missing required wording: 211", problems)
        self.assertIn("missing required wording: 191", problems)
        self.assertIn("missing required wording: 63", problems)

    def test_rejects_machine_paths_in_decoded_attributes_and_css(self):
        root = self.make_site(
            '<a href="file:///C:/Users/games/secret">Local file</a>',
            {
                "assets/site.css": (
                    b'.logo { background-image: '
                    b'url(file:///C:/Users/games/logo.png); }'
                )
            },
        )
        problems = "\n".join(validate_site(root, root))
        self.assertIn("index.html: machine-specific path", problems)
        self.assertIn("assets/site.css: machine-specific path", problems)

    def test_rejects_machine_specific_path(self):
        root = self.make_site('<p>C:\\Users\\games\\secret</p>')
        self.assertIn("machine-specific path", "\n".join(validate_site(root, root)))

    def test_rejects_external_runtime_asset(self):
        root = self.make_site('<script src="https://cdn.example/app.js"></script>')
        self.assertIn("external runtime asset", "\n".join(validate_site(root, root)))

    def test_allows_self_contained_data_image(self):
        root = self.make_site(
            '<img src="data:image/png;base64,cG5n" alt="Example screen">'
        )
        self.assertNotIn("external runtime asset", "\n".join(validate_site(root, root)))

    def test_requires_image_description(self):
        root = self.make_site('<img src="screen.png">', {"screen.png": b"png"})
        self.assertIn("missing alt text", "\n".join(validate_site(root, root)))
