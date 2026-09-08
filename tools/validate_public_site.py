"""Validate the self-contained public Neyer review site."""

from __future__ import annotations

import hashlib
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse


REQUIRED_PAGES = {
    "index.html",
    "method.html",
    "planner.html",
    "test-workflow.html",
    "results.html",
    "physical-setup.html",
    "audit.html",
    "evidence.html",
}
FORBIDDEN_TEXT = ("transition width", "C:\\Users\\", "localhost")
REQUIRED_TEXT = (
    "middle gap",
    "overall variation",
    "reliable operating gap",
    "211",
    "191",
    "63",
    "0.015 mm",
    "two decimal places",
)

SCREENSHOT_NAMES = (
    "v110-01-main-menu.png",
    "v110-02-planner-input.png",
    "v110-03-planner-review.png",
    "v110-04-test-inputs.png",
    "v110-05-requested-gap.png",
    "v110-06-results.png",
    "v110-07-help.png",
)


class SiteHtmlParser(HTMLParser):
    """Collect the site properties that are relevant to static validation."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.elements: list[tuple[str, dict[str, str]]] = []
        self.text: list[str] = []
        self._open_tags: list[str] = []
        self.h1_count = 0
        self.title_text: list[str] = []
        self._in_title = False

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attributes = {name.lower(): value or "" for name, value in attrs}
        tag = tag.lower()
        self.elements.append((tag, attributes))
        self._open_tags.append(tag)
        if tag == "h1":
            self.h1_count += 1
        if tag == "title":
            self._in_title = True

    def handle_startendtag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag == "title":
            self._in_title = False
        for index in range(len(self._open_tags) - 1, -1, -1):
            if self._open_tags[index] == tag:
                del self._open_tags[index:]
                break

    def handle_data(self, data: str) -> None:
        self.text.append(data)
        if self._in_title:
            self.title_text.append(data)


def _parse_html(path: Path) -> tuple[SiteHtmlParser | None, str | None]:
    try:
        contents = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return None, f"cannot read {path}: {error}"

    parser = SiteHtmlParser()
    try:
        parser.feed(contents)
        parser.close()
    except Exception as error:  # HTMLParser can surface malformed declarations.
        return None, f"cannot parse {path}: {error}"
    return parser, None


def _is_remote(value: str) -> bool:
    parsed = urlparse(value)
    return bool(parsed.scheme) or value.startswith("//")


def _is_runtime_asset(tag: str, attributes: dict[str, str]) -> bool:
    if tag in {"script", "img", "audio", "video", "source", "track", "iframe", "frame", "embed", "object"}:
        return True
    if tag == "link":
        return True
    return False


def _local_target(page: Path, site_root: Path, value: str) -> Path | None:
    parsed = urlparse(value)
    if _is_remote(value) or parsed.scheme or value.startswith("#"):
        return None
    target_text = unquote(parsed.path)
    if not target_text:
        return None
    target = (page.parent / target_text).resolve()
    root = site_root.resolve()
    try:
        target.relative_to(root)
    except ValueError:
        return None
    return target


def _fingerprint_pairs(site_root: Path, repository_root: Path) -> list[tuple[Path, Path]]:
    pairs = [
        (
            site_root / "downloads" / "Neyer_Gap_Test_v1_10.mlx",
            repository_root / "delivery" / "Neyer_Gap_Test_v1_10.mlx",
        ),
        (
            site_root / "reports" / "Neyer_Overnight_Verification_Report.html",
            repository_root / "delivery" / "Neyer_Overnight_Verification_Report.html",
        ),
    ]
    pairs.extend(
        (
            site_root / "assets" / "screens" / name,
            repository_root / "assets" / "screenshots" / name,
        )
        for name in SCREENSHOT_NAMES
    )
    return pairs


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _relative(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


def validate_page_shell(site_root: Path) -> list[str]:
    """Return accessible-shell problems for every required public page."""
    problems: list[str] = []
    for page_name in sorted(REQUIRED_PAGES):
        page = site_root / page_name
        if not page.is_file():
            problems.append(f"missing required page: {page_name}")
            continue
        parser, error = _parse_html(page)
        if error:
            problems.append(error)
            continue
        assert parser is not None
        label = _relative(page, site_root)
        if parser.h1_count != 1:
            problems.append(f"{label}: expected exactly one h1")
        if not any(
            tag == "a" and attributes.get("href", "").startswith("#")
            and "skip" in " ".join(attributes.values()).lower()
            for tag, attributes in parser.elements
        ):
            problems.append(f"{label}: missing skip link")
        if not "".join(parser.title_text).strip():
            problems.append(f"{label}: missing title")
        if not any(
            tag == "meta" and attributes.get("name", "").lower() == "viewport"
            and attributes.get("content", "").strip()
            for tag, attributes in parser.elements
        ):
            problems.append(f"{label}: missing viewport meta")
        if not any(
            tag == "nav" and attributes.get("aria-label", "").strip()
            for tag, attributes in parser.elements
        ):
            problems.append(f"{label}: missing labelled navigation")
        if not any(
            tag == "link"
            and "stylesheet" in attributes.get("rel", "").lower().split()
            and attributes.get("href", "").split("?", 1)[0] == "assets/site.css"
            for tag, attributes in parser.elements
        ):
            problems.append(f"{label}: missing local stylesheet")
    return problems


def validate_site(site_root: Path, repository_root: Path) -> list[str]:
    """Return all static-site safety and release-validation problems."""
    problems: list[str] = []
    if not site_root.is_dir():
        return [f"missing site directory: {site_root}"]

    page_parsers: list[tuple[Path, SiteHtmlParser]] = []
    for page in sorted(site_root.rglob("*.html")):
        parser, error = _parse_html(page)
        if error:
            problems.append(error)
            continue
        assert parser is not None
        page_parsers.append((page, parser))
        page_label = _relative(page, site_root)
        for tag, attributes in parser.elements:
            for attribute_name in ("href", "src"):
                value = attributes.get(attribute_name, "").strip()
                if not value:
                    continue
                if _is_remote(value) and _is_runtime_asset(tag, attributes):
                    problems.append(
                        f"{page_label}: external runtime asset: {value}"
                    )
                    continue
                target = _local_target(page, site_root, value)
                if target is not None and not target.is_file():
                    problems.append(
                        f"{page_label}: missing internal target: {value}"
                    )
            if tag == "img" and not attributes.get("alt", "").strip():
                problems.append(f"{page_label}: missing alt text")

    all_text = "\n".join("".join(parser.text) for _, parser in page_parsers).lower()
    for forbidden in FORBIDDEN_TEXT:
        if forbidden.lower() in all_text:
            label = "machine-specific path" if forbidden == "C:\\Users\\" else "forbidden text"
            problems.append(f"{label}: {forbidden}")
    for required in REQUIRED_TEXT:
        if required.lower() not in all_text:
            problems.append(f"missing required wording: {required}")

    problems.extend(validate_page_shell(site_root))
    for public_path, source_path in _fingerprint_pairs(site_root, repository_root):
        public_label = _relative(public_path, site_root)
        source_label = _relative(source_path, repository_root)
        if not public_path.is_file():
            problems.append(f"missing public copy: {public_label} (source: {source_label})")
        elif not source_path.is_file():
            problems.append(f"missing reviewed source: {source_label} (public: {public_label})")
        elif _sha256(public_path) != _sha256(source_path):
            problems.append(f"fingerprint mismatch: {public_label} != {source_label}")
    return problems


def main() -> int:
    repository_root = Path(__file__).resolve().parents[1]
    problems = validate_site(repository_root / "site", repository_root)
    if problems:
        print("\n".join(problems))
        return 1
    print("Public site validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
