from pathlib import Path

from lxml import html


project_root = Path(__file__).resolve().parents[1]
report_path = project_root / "delivery" / "Neyer_Overnight_Verification_Report.html"
document = html.parse(str(report_path))
root = document.getroot()
page_text = " ".join(root.itertext()).lower()

images = root.xpath("//img")
section_ids = {section.get("id") for section in root.xpath("//section[@id]")}
navigation_targets = root.xpath("//nav//a[starts-with(@href, '#')]/@href")

expected_sections = {
    "outcome",
    "work-completed",
    "audit",
    "planner",
    "physical-workflow",
    "testing",
    "screens",
    "operation",
    "saving",
    "limitations",
    "evidence",
}

assert len(images) == 7, f"Expected 7 embedded MATLAB screens, found {len(images)}"
assert all(
    image.get("src", "").startswith("data:image/png;base64,") for image in images
), "Every screenshot must be embedded for offline use"
assert expected_sections <= section_ids, (
    f"Missing sections: {sorted(expected_sections - section_ids)}"
)
assert navigation_targets, "The report needs a contents menu"
assert all(target[1:] in section_ids for target in navigation_targets), (
    "Every contents link must point to a report section"
)
assert not root.xpath("//script[@src]"), "The report must not load an external script"
assert not root.xpath("//link[@rel='stylesheet']"), (
    "The report must not load an external stylesheet"
)
assert not root.xpath("//img[starts-with(@src, 'http')]")
assert "transition width" not in page_text, (
    "The final report must use the agreed plain term: overall variation"
)

required_evidence = {
    "211 MATLAB tests",
    "191 / 191",
    "63 / 63",
    "8 accepted",
    "4 withheld",
    "400 independent",
    "0.8",
    "0.015 mm",
    "two decimal places",
    "5.39 mm",
    "1.04 mm",
}
missing_evidence = [item for item in required_evidence if item.lower() not in page_text]
assert not missing_evidence, f"Missing required evidence: {missing_evidence}"

print(
    f"HTML verified: {report_path.stat().st_size} bytes, "
    f"{len(images)} embedded screenshots, {len(section_ids)} named sections"
)
