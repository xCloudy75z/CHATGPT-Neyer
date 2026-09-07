from pathlib import Path
from lxml import html

project_root = Path(__file__).resolve().parents[1]
report = project_root / "delivery" / "Neyer_Gap_Test_v1_9_Report.html"
document = html.parse(str(report))
root = document.getroot()
images = root.xpath("//img")
sections = root.xpath("//h2")
section_ids = {section.get("id") for section in root.xpath("//section[@id]")}
nav_links = root.xpath("//nav//a[starts-with(@href, '#')]/@href")

assert len(images) == 5, f"Expected 5 images, found {len(images)}"
assert all(
    image.get("src", "").startswith("data:image/png;base64,")
    for image in images
), "Every report image must be embedded"
assert len(sections) >= 10, f"Expected at least 10 sections, found {len(sections)}"
expected_sections = {
    "executive-summary", "objective-scope", "original-tool", "audit-method",
    "audit-findings", "fixes-improvements", "testing", "operation",
    "saving", "file-structure", "limitations", "conclusion",
}
assert expected_sections <= section_ids, (
    f"Missing report sections: {sorted(expected_sections - section_ids)}"
)
assert nav_links, "The report needs a contents menu"
assert all(link[1:] in section_ids for link in nav_links), "Every contents link must target a section"
assert not root.xpath("//script[@src]"), "The report must not load external scripts"
assert not root.xpath("//link[@rel='stylesheet']"), "The report must not load an external stylesheet"
assert not root.xpath("//img[starts-with(@src, 'http')]"), "Images must not require the internet"

print(
    f"HTML parsed: {report.stat().st_size} bytes, "
    f"{len(images)} embedded images, {len(sections)} sections"
)
