#!/usr/bin/env python3
"""
==============================================================================
Automated Release & README Update Script for Family Spend Tracker (Python)
Usage: python scripts/update_release.py
==============================================================================
"""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
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
GITHUB_REPO = "apzscorpion/family-finance"
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
#
# APKs are uploaded to a GitHub Release, never committed: every committed APK
# stayed in git history forever and made each clone gigabytes. The app's
# updater downloads releases/latest/download/<asset name>, so a name, once
# shipped, has to keep being uploaded.
BUILT_APK_PATH = FLUTTER_APK_DIR / "app-standard-release.apk"
ASSET_NAME = "Sampio-latest.apk"
# Builds up to v1.10.5 update from this name; the same APK is uploaded under
# it too. shortcut: drop it once no phone runs v1.10.5 or older.
LEGACY_ASSET_NAMES = ["FamilySpendTracker-latest.apk"]
DETECT_APK_PATH = FLUTTER_APK_DIR / "app-detect-release.apk"
DETECT_ASSET_NAME = "Sampio-detect.apk"

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

    # 3. Update README.md
    print("[3/5] Auto-updating README.md...")
    readme_text = README_PATH.read_text(encoding="utf-8")
    updated_readme = re.sub(
        r"⚡_Download_Android_APK-v[0-9]+\.[0-9]+\.[0-9]+",
        f"⚡_Download_Android_APK-v{version}",
        readme_text
    )
    README_PATH.write_text(updated_readme, encoding="utf-8")
    print(f"  README.md updated with badge v{version}")

    # 4. Commit, tag and push (never force: that would discard others' work)
    print("[4/5] Committing and pushing to GitHub...")
    subprocess.run(["git", "add", "README.md", "mobile/pubspec.yaml",
                    str(UPDATE_SERVICE_PATH.relative_to(REPO_ROOT))],
                   cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "commit", "-m", f"Release v{version}: update README"],
                   cwd=REPO_ROOT, check=False)
    subprocess.run(["git", "tag", "-f", f"v{version}"], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "push", "origin", "HEAD:main"], cwd=REPO_ROOT, check=True)
    subprocess.run(["git", "push", "origin", f"v{version}", "--force"], cwd=REPO_ROOT, check=True)

    # 5. Publish the APK(s) on the GitHub Release for the tag
    print("[5/5] Uploading APK to GitHub Releases...")
    assets = [(BUILT_APK_PATH, n) for n in [ASSET_NAME, *LEGACY_ASSET_NAMES]]
    if RELEASE_DETECT:
        assets.append((DETECT_APK_PATH, DETECT_ASSET_NAME))
    publish_release(f"v{version}", assets, release_notes(f"v{version}"))

    print(f"\nSUCCESS: Release v{version} built and published to "
          f"https://github.com/{GITHUB_REPO}/releases/tag/v{version}")


def release_notes(tag):
    """Commit titles since the previous tag; the app shows them as "What's new"."""
    prev = subprocess.run(["git", "describe", "--tags", "--abbrev=0", f"{tag}^"],
                          capture_output=True, text=True, cwd=REPO_ROOT).stdout.strip()
    rng = f"{prev}..{tag}" if prev else tag
    titles = subprocess.run(["git", "log", rng, "--format=%s"],
                            capture_output=True, text=True, cwd=REPO_ROOT).stdout.splitlines()
    return "\n".join(f"- {t}" for t in titles if not t.startswith("Release v"))


def github_token():
    """GITHUB_TOKEN if set, otherwise the token git already stores for github.com."""
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token
    out = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True, text=True, cwd=REPO_ROOT,
    ).stdout
    for line in out.splitlines():
        if line.startswith("password="):
            return line[len("password="):]
    print("Error: no GitHub token. Set GITHUB_TOKEN (repo scope) and re-run.")
    sys.exit(1)


def github_api(method, url, token, body=None, content_type="application/json"):
    req = urllib.request.Request(url, data=body, method=method, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": content_type,
    })
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
        return json.loads(data) if data else None


def publish_release(tag, assets, notes=""):
    """Creates the release for [tag] (or reuses it) and replaces its assets."""
    token = github_token()
    api = f"https://api.github.com/repos/{GITHUB_REPO}"
    try:
        release = github_api("GET", f"{api}/releases/tags/{tag}", token)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        release = github_api("POST", f"{api}/releases", token, json.dumps({
            "tag_name": tag, "name": tag, "body": notes, "make_latest": "true",
        }).encode())
    if notes and release.get("body") != notes:
        release = github_api("PATCH", f"{api}/releases/{release['id']}", token,
                             json.dumps({"body": notes}).encode())

    existing = {a["name"]: a["id"] for a in release.get("assets", [])}
    for path, name in assets:
        if name in existing:
            github_api("DELETE", f"{api}/releases/assets/{existing[name]}", token)
        upload = release["upload_url"].split("{")[0] + f"?name={name}"
        github_api("POST", upload, token, path.read_bytes(),
                   "application/vnd.android.package-archive")
        print(f"  Uploaded {name}")

if __name__ == "__main__":
    main()
