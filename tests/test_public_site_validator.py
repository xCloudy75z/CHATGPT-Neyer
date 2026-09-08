import csv
import re
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


class PublicSiteValidatorTests(unittest.TestCase):
    def test_evidence_page_matches_the_committed_audit_records(self):
        """Catches public evidence totals that drift from the executed records."""
        evidence = (REPOSITORY_ROOT / "site" / "evidence.html").read_text(
            encoding="utf-8"
        )

        def recorded_count(filename, label):
            record = (REPOSITORY_ROOT / "audit" / "overnight" / filename).read_text(
                encoding="utf-8"
            )
            match = re.search(rf"^{re.escape(label)}: (\d+)$", record, re.MULTILINE)
            self.assertIsNotNone(match, f"missing {label} in {filename}")
            return match.group(1)

        full_suite = "final-full-suite.txt"
        mock_lab = "full-test-summary.txt"
        final_review = "final-review-regressions.txt"
        planner_summary = "planner-validation-summary.csv"

        self.assertIn(
            f"{recorded_count(full_suite, 'Passed')} complete MATLAB checks", evidence
        )
        self.assertIn(f"{recorded_count(full_suite, 'Failed')} failed", evidence)
        self.assertIn(f"{recorded_count(full_suite, 'Incomplete')} incomplete", evidence)
        self.assertIn(
            f"{recorded_count(mock_lab, 'Passed')} mock-laboratory checks", evidence
        )
        self.assertIn(f"{recorded_count(mock_lab, 'Routes')} routes", evidence)
        self.assertIn(
            f"{recorded_count(final_review, 'Passed')} focused final-review safety regressions",
            evidence,
        )

        with (REPOSITORY_ROOT / "audit" / "overnight" / planner_summary).open(
            encoding="utf-8", newline=""
        ) as source:
            scenarios = list(csv.DictReader(source))
        accepted = sum(row["conclusion"] == "accepted" for row in scenarios)
        withheld = sum(row["conclusion"] == "withheld" for row in scenarios)
        rejected = len(scenarios) - accepted - withheld
        self.assertIn(f"{len(scenarios)} scenarios", evidence)
        self.assertIn(f"{accepted} supported cases accepted", evidence)
        self.assertIn(f"{rejected} supported cases rejected", evidence)
        self.assertIn(f"{withheld} unsupported confidence cases deliberately withheld", evidence)

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
