#!/usr/bin/env python3
"""Prepare a generated Flutter iOS project for the FREIRAUM App Store build."""

from __future__ import annotations

import json
import plistlib
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"
BUNDLE_ID = "de.freiraum.parking"
DISPLAY_NAME = "FREIRAUM"
DEPLOYMENT_TARGET = "15.0"


def patch_project() -> None:
    project = IOS / "Runner.xcodeproj" / "project.pbxproj"
    if not project.is_file():
        raise SystemExit("Generated iOS Xcode project is missing")
    text = project.read_text(encoding="utf-8")

    def bundle_replacement(match: re.Match[str]) -> str:
        current = match.group(1)
        suffix = ".RunnerTests" if current.endswith(".RunnerTests") else ""
        return f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}{suffix};"

    text = re.sub(
        r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);",
        bundle_replacement,
        text,
    )
    text = re.sub(
        r"IPHONEOS_DEPLOYMENT_TARGET = [^;]+;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        text,
    )
    text = re.sub(
        r'TARGETED_DEVICE_FAMILY = "[^"]+";',
        'TARGETED_DEVICE_FAMILY = "1";',
        text,
    )
    project.write_text(text, encoding="utf-8")


def patch_info_plist() -> None:
    info = IOS / "Runner" / "Info.plist"
    if not info.is_file():
        raise SystemExit("Generated Runner Info.plist is missing")
    with info.open("rb") as stream:
        data = plistlib.load(stream)
    data["CFBundleDisplayName"] = DISPLAY_NAME
    data["CFBundleName"] = DISPLAY_NAME
    data["NSLocationWhenInUseUsageDescription"] = (
        "FREIRAUM verwendet deinen Standort nur nach deiner Zustimmung, "
        "um Stellplätze in deiner Nähe anzuzeigen."
    )
    data["ITSAppUsesNonExemptEncryption"] = False
    with info.open("wb") as stream:
        plistlib.dump(data, stream, sort_keys=False)


def draw_icon(size: int, target: Path) -> None:
    image = Image.new("RGB", (size, size), "#0B1726")
    draw = ImageDraw.Draw(image)
    margin = int(size * 0.20)
    draw.ellipse(
        (margin, margin, size - margin, size - margin),
        fill="#35D7AC",
    )

    stroke = max(4, int(size * 0.075))
    left = int(size * 0.38)
    top = int(size * 0.29)
    bottom = int(size * 0.72)
    bowl_right = int(size * 0.66)
    bowl_bottom = int(size * 0.52)
    ink = "#0B1726"
    draw.rounded_rectangle(
        (left, top, left + stroke, bottom),
        radius=max(2, stroke // 3),
        fill=ink,
    )
    draw.arc(
        (left - stroke // 2, top, bowl_right, bowl_bottom),
        start=-90,
        end=90,
        fill=ink,
        width=stroke,
    )
    draw.line(
        (left, top, int(size * 0.53), top),
        fill=ink,
        width=stroke,
    )
    draw.line(
        (left, bowl_bottom, int(size * 0.53), bowl_bottom),
        fill=ink,
        width=stroke,
    )
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, format="PNG", optimize=True)


def generate_icons() -> None:
    app_icon = IOS / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    manifest = app_icon / "Contents.json"
    if not manifest.is_file():
        raise SystemExit("Generated AppIcon Contents.json is missing")
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    generated: set[tuple[str, int]] = set()
    for entry in payload.get("images", []):
        filename = entry.get("filename")
        size_value = entry.get("size")
        scale_value = entry.get("scale")
        if not filename or not size_value or not scale_value:
            continue
        points = float(size_value.split("x", 1)[0])
        scale = int(scale_value.rstrip("x"))
        pixels = round(points * scale)
        key = (filename, pixels)
        if key in generated:
            continue
        draw_icon(pixels, app_icon / filename)
        generated.add(key)
    if not generated:
        raise SystemExit("No iOS app icons were generated")


def verify() -> None:
    project = (IOS / "Runner.xcodeproj" / "project.pbxproj").read_text(
        encoding="utf-8"
    )
    if BUNDLE_ID not in project:
        raise SystemExit("Bundle identifier was not applied")
    if 'TARGETED_DEVICE_FAMILY = "1";' not in project:
        raise SystemExit("The initial release must be iPhone-only")
    icon_1024 = IOS / "Runner" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-App-1024x1024@1x.png"
    if icon_1024.is_file():
        with Image.open(icon_1024) as image:
            if image.mode != "RGB" or image.size != (1024, 1024):
                raise SystemExit("App Store icon must be 1024x1024 RGB without alpha")


def main() -> None:
    patch_project()
    patch_info_plist()
    generate_icons()
    verify()
    print(f"Prepared FREIRAUM iOS project: {BUNDLE_ID}, iOS {DEPLOYMENT_TARGET}+")


if __name__ == "__main__":
    main()
