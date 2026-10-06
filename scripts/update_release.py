#!/usr/bin/env python3
"""
==============================================================================
Automated Release & README Update Script for Family Spend Tracker (Python)
Usage: python scripts/update_release.py
==============================================================================
"""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Ensure UTF-8 stdout output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Paths setup
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
MOBILE_DIR = REPO_ROOT / "mobile"
PUBSPEC_PATH = MOBILE_DIR / "pubspec.yaml"
UPDATE_SERVICE_PATH = MOBILE_DIR / "lib" / "services" / "update_service.dart"
README_PATH = REPO_ROOT / "README.md"
RELEASES_DIR = REPO_ROOT / "releases"
FLUTTER_APK_DIR = MOBILE_DIR / "build" / "app" / "outputs" / "flutter-apk"

# Only the `standard` flavour ships. It carries no notification listener, which
# is what lets it install from a browser or file manager: Android refuses to
# install an APK that declares notification access unless it came from the Play
# Store.
#
# The `detect` flavour still exists in the project and keeps automatic payment
# detection. It is not built here because it can only be installed over adb,
# which makes it useless to hand out. Set RELEASE_DETECT=1 to build and publish
# it too — worth doing once there is a Play Store listing to put it behind.
BUILT_APK_PATH = FLUTTER_APK_DIR / "app-standard-release.apk"
TARGET_APK_PATH = RELEASES_DIR / "FamilySpendTracker-latest.apk"
DETECT_APK_PATH = FLUTTER_APK_DIR / "app-detect-release.apk"
DETECT_TARGET_PATH = RELEASES_DIR / "FamilySpendTracker-detect.apk"

RELEASE_DETECT = os.environ.get("RELEASE_DETECT") == "1"


def main():
    print("[1/5] Reading current version from mobile/pubspec.yaml...")
    if not PUBSPEC_PATH.exists():
        print(f"Error: {PUBSPEC_PATH} not found.")
        sys.exit(1)

    pubspec_text = PUBSPEC_PATH.read_text(encoding="utf-8")
    match = re.search(r"version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?([0-9]*)", pubspec_text)
    if not match:
        print("Error: Could not parse version from pubspec.yaml")
        sys.exit(1)

    version = match.group(1)
    build_num = match.group(2)
    print(f"  Current Version: v{version} (Build {build_num})")

    # Sync version into update_service.dart before building
    if UPDATE_SERVICE_PATH.exists():
        us_text = UPDATE_SERVICE_PATH.read_text(encoding="utf-8")
        us_updated = re.sub(
            r"static const String currentVersion = '[0-9]+\.[0-9]+\.[0-9]+';",
            f"static const String currentVersion = '{version}';",
            us_text,
        )
        UPDATE_SERVICE_PATH.write_text(us_updated, encoding="utf-8")
        print(f"  Synced UpdateService.currentVersion to {version}")

    # 1. Build Flutter Release APK
    print("[2/5] Building Flutter Release APK...")
    flutter_bin = r"C:\src\flutter\bin\flutter.bat" if os.name == "nt" else "flutter"
    env = os.environ.copy()
    env["PATH"] += f";C:\\src\\flutter\\bin"

    builds = [("standard", BUILT_APK_PATH)]
    if RELEASE_DETECT:
        builds.append(("detect", DETECT_APK_PATH))

    for flavor, path in builds:
        print(f"  Building {flavor}...")
        result = subprocess.run(
            [flutter_bin, "build", "apk", "--release", "--flavor", flavor],
            cwd=MOBILE_DIR, env=env,
        )
        if result.returncode != 0:
            print(f"Error: Flutter build failed for flavour {flavor}!")
            sys.exit(1)
        if not path.exists():
            print(f"Error: Built APK at {path} not found.")
            sys.exit(1)

    # 2. Clean releases directory & copy latest APK
    print("[3/5] Cleaning old APKs in releases/ directory...")
    RELEASES_DIR.mkdir(parents=True, exist_ok=True)
    for apk_file in RELEASES_DIR.glob("*.apk"):
        apk_file.unlink()

    shutil.copy2(BUILT_APK_PATH, TARGET_APK_PATH)
    print(f"  Mapped latest build to {TARGET_APK_PATH}")
    if RELEASE_DETECT:
        shutil.copy2(DETECT_APK_PATH, DETECT_TARGET_PATH)
        print(f"  Mapped detection build to {DETECT_TARGET_PATH}")

    # 3. Update README.md
    print("[4/5] Auto-updating README.md...")
    readme_text = README_PATH.read_text(encoding="utf-8")
    updated_readme = re.sub(
        r"⚡_Download_Android_APK-v[0-9]+\.[0-9]+\.[0-9]+",
        f"⚡_Download_Android_APK-v{version}",
        readme_text
    )
    README_PATH.write_text(updated_readme, encoding="utf-8")
    print(f"  README.md updated with badge v{version}")

    # 4. Git Commit and Tag
    print("[5/5] Committing and pushing to GitHub...")
    subprocess.run(["git", "add", "."], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "commit", "-m", f"Release v{version}: Map latest APK and update README"], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "tag", "-f", f"v{version}"], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "push", "origin", "main", "--force"], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "push", "origin", f"v{version}", "--force"], cwd=REPO_ROOT, check=True)

    print(f"\nSUCCESS: Release v{version} built, mapped to FamilySpendTracker-latest.apk, and pushed to GitHub!")


if __name__ == "__main__":
    main()
