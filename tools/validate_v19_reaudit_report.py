from html.parser import HTMLParser
from pathlib import Path
import re
import sys


class ReportParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.external_references = []
        self.text_parts = []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if "id" in values:
            self.ids.add(values["id"])
        for name in ("href", "src"):
            value = values.get(name, "")
            if value.startswith(("http://", "https://", "//")):
                self.external_references.append(value)

    def handle_data(self, data):
        self.text_parts.append(data)


root = Path(__file__).resolve().parents[1]
report = root / "delivery" / "Neyer_Gap_Test_v1_9_Independent_Reaudit.html"
if not report.is_file():
    raise SystemExit(f"Missing report: {report}")

source = report.read_text(encoding="utf-8")
parser = ReportParser()
parser.feed(source)
text = " ".join(parser.text_parts)

required_sections = {"outcome", "matrix", "physical", "simulation", "limits", "evidence"}
missing = sorted(required_sections - parser.ids)
if missing:
    raise SystemExit(f"Missing report sections: {', '.join(missing)}")
if parser.external_references:
    raise SystemExit("Report contains external dependencies: " + ", ".join(parser.external_references))
for required in (
    "129,600",
    "Stage 2 transition",
    "0.8",
    "0.05 mm",
    "0.10 mm",
    "actual built gap",
    "four or five readings",
    "earlier combined simulation",
):
    if required.lower() not in text.lower():
        raise SystemExit(f"Required evidence is missing: {required}")
if re.search(r"\b(?:TBD|TODO|NaN)\b", text):
    raise SystemExit("Report contains an unfinished or invalid value.")
if len(source) < 12_000:
    raise SystemExit("Report is unexpectedly small.")

print(f"Validated offline report: {report}")
print(f"Sections: {len(parser.ids)}; external dependencies: 0; bytes: {report.stat().st_size}")
sys.exit(0)
