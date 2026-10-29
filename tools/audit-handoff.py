#!/usr/bin/env python3
"""Read-only asset/tracking and handoff-reference audit. No dependencies or network.
Run from any directory: python3 tools/audit-handoff.py [--manifest]
The optional manifest is printed to stdout; this script never modifies files.
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = ("web/public", "ios/Nudge/Assets.xcassets", "ios/Nudge/Fonts", "ios/Nudge/Resources", "tmp/assets", "tmp/ref2")
DOCS = ("README.md", "PRODUCTION_HANDOFF.md", "DESIGN_REFERENCE.md", "ASSET_AUDIT.md")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode().strip()


def main():
    tracked = set(git("ls-files", "-z").split("\0"))
    failures = []
    for relative in sorted(tracked):
        if any(relative.startswith(folder + "/") for folder in FOLDERS) and not (ROOT / relative).is_file():
            failures.append("Tracked asset missing from checkout: " + relative)
    manifest = []
    groups = {}
    for folder in FOLDERS:
        entries = []
        for path in sorted((ROOT / folder).rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            item = {"path": relative, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "tracked": relative in tracked}
            entries.append(item)
            if not item["tracked"]:
                failures.append("Asset not tracked: " + relative)
            if not data:
                failures.append("Empty asset: " + relative)
            if data.startswith(b"version https://git-lfs.github.com/spec/"):
                failures.append("Unhydrated LFS pointer: " + relative)
        manifest.extend(entries)
        groups[folder] = {"files": len(entries), "bytes": sum(e["bytes"] for e in entries)}
        if not entries:
            failures.append("Missing asset folder: " + folder)

    # Every image named by an Xcode catalog must exist beside its Contents.json.
    for path in (ROOT / "ios/Nudge/Assets.xcassets").rglob("Contents.json"):
        for image in json.loads(path.read_text()).get("images", []):
            if image.get("filename") and not (path.parent / image["filename"]).is_file():
                failures.append("Missing catalog image: " + str(path.parent / image["filename"]))

    # Literal web URLs, plus all dynamically selected tap sounds and recipe images.
    references = set()
    for path in (ROOT / "web/src").rglob("*"):
        if path.suffix not in (".ts", ".tsx", ".css"):
            continue
        references.update(re.findall(r'''["'`](/(?:img|audio|orb|fonts)/[^"'`\s${}]+\.(?:png|jpg|jpeg|webp|svg|mp3|m4a|mp4|ttf))''', path.read_text()))
    references.update(f"/audio/tap_ta_{n}.mp3" for n in range(1, 6))
    references.update(f"/img/rumi-recipe-{n}-v1.webp" for n in range(36))
    for reference in sorted(references):
        if not (ROOT / "web/public" / reference.lstrip("/")).is_file():
            failures.append("Missing web asset: " + reference)

    # Cross-platform duplicates intentionally shipped in each app should match.
    pairs = []
    for folder, native in (("fonts", "Fonts"), ("orb", "Resources"), ("audio", "Resources")):
        for path in (ROOT / "web/public" / folder).iterdir():
            other = ROOT / "ios/Nudge" / native / path.name
            if other.is_file():
                if path.read_bytes() != other.read_bytes():
                    failures.append("Cross-platform asset mismatch: " + path.name)
                pairs.append(path.name)

    # All Markdown local links and literal code file references must resolve.
    checked = set()
    for name in DOCS:
        doc = ROOT / name
        if not doc.exists():
            failures.append("Missing handoff document: " + name)
            continue
        text = doc.read_text()
        candidates = re.findall(r"\]\(([^)]+)\)", text)
        candidates += re.findall(r"`((?:ios/|web/|functions/|tools/|tmp/|\.rork/)[^`\n]+)`", text)
        for value in candidates:
            value = value.split("#")[0]
            if not value or "://" in value or any(c in value for c in " *{}<>|\n"):
                continue
            # Path + optional :line is a source reference, not part of the filename.
            value = re.sub(r":\d+(?:[-–]\d+)?$", "", value)
            if not (ROOT / value).exists():
                failures.append(f"Broken reference in {name}: {value}")
            checked.add(value)

    digest = hashlib.sha256("\n".join(f"{e['path']}\t{e['bytes']}\t{e['sha256']}" for e in manifest).encode()).hexdigest()
    report = {"assetGroups": groups, "totalFiles": len(manifest), "totalBytes": sum(e["bytes"] for e in manifest), "aggregateSHA256": digest, "matchingCrossPlatformCopies": len(pairs), "webAssetPathsChecked": len(references), "documentationPathsChecked": len(checked), "failures": failures}
    if "--manifest" in sys.argv:
        report["manifest"] = manifest
    print(json.dumps(report, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
