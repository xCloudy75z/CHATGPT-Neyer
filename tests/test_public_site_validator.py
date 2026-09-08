import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path

from tools.validate_public_site import validate_page_shell, validate_site


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class PublicSiteValidatorTests(unittest.TestCase):
    def test_planner_guide_explains_every_planning_answer(self):
        """Catches a planner page that omits an operator's required choice."""
        planner = (REPOSITORY_ROOT / "site" / "planner.html").read_text(
            encoding="utf-8"
        )
        for required_explanation in (
            "Required physical result",
            "Keep this requirement fixed",
            "Reliability (%)",
            "Confidence (%)",
            "Required gap accuracy (+/- mm)",
            "Almost-always Interaction gap (mm)",
            "Almost-always No-interaction gap (mm)",
            "Earlier information",
            "Minimum permitted gap (mm)",
            "Maximum permitted gap (mm)",
            "Physical setup method",
            "Regular increment (mm)",
            "Confirmed gaps (mm)",
            "Measured components and maximum count",
            "Usable gap step",
            "Maximum articles available",
            "Main study estimate",
            "Reserve group 1",
            "Reserve group 2",
            "400 independent articles",
        ):
            self.assertIn(required_explanation, planner)
        self.assertIn("What it means:", planner)
        self.assertIn("Example:", planner)
        self.assertIn("not used automatically", planner)
        self.assertIn("not a universal", planner)

    def test_workflow_guide_keeps_build_measurement_and_boundary_steps_clear(self):
        """Catches a walkthrough that loses a safety-critical operator distinction."""
        workflow = (REPOSITORY_ROOT / "site" / "test-workflow.html").read_text(
            encoding="utf-8"
        )
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

        class FigureCounter(HTMLParser):
            def __init__(self):
                super().__init__()
                self.figure_count = 0

            def handle_starttag(self, tag, attrs):
                if tag == "figure":
                    self.figure_count += 1

        parser = FigureCounter()
        parser.feed(workflow)
        self.assertEqual(7, parser.figure_count)

    def test_real_pages_have_accessible_shell(self):
        expected_deferred_problems = {
            f"missing required page: {page}"
            for page in (
                "audit.html",
                "evidence.html",
                "physical-setup.html",
                "results.html",
            )
        }
        self.assertEqual(
            expected_deferred_problems,
            set(validate_page_shell(REPOSITORY_ROOT / "site")),
        )

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
