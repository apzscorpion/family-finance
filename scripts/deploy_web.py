#!/usr/bin/env python3
"""Build the Flutter web app and deploy it to https://family-finance-tracker-dev.vercel.app.

Usage: python scripts/deploy_web.py

ALWAYS deploy the web app with this script, never with a bare `vercel deploy`.
The same Vercel team hosts the owner's wedding site (asif-sinana-wedding.vercel.app,
project temporary-flying-mercury-8eg7q18). A stale `.vercel` link once sent this
app there and replaced the wedding site, so the target project is pinned here
and the script refuses to run against anything else.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

PROJECT = {
    "projectId": "prj_alopeApP54824GDK8D5GN8VpXPrH",
    "orgId": "team_mqlsPHzUdYSjrdNNRhxtE5T9",
    "projectName": "family-finance-tracker-dev",
}
APP_URL = "https://family-finance-tracker-dev.vercel.app/"
# Never deploy to, promote on, alias or roll back this project.
FORBIDDEN_PROJECT_ID = "prj_2q9XYREnM20wl9F2i3DJgr1kHWUp"
WEDDING_URL = "https://asif-sinana-wedding.vercel.app/"

REPO = Path(__file__).resolve().parent.parent
MOBILE = REPO / "mobile"
WEB_OUT = MOBILE / "build" / "web"
WIN = os.name == "nt"


def title(url):
    html = urllib.request.urlopen(url, timeout=30).read().decode("utf-8", "ignore")
    m = re.search(r"<title>(.*?)</title>", html, re.S)
    return m.group(1).strip() if m else ""


def run(cmd, cwd):
    if subprocess.run(cmd, cwd=cwd, shell=WIN).returncode != 0:
        sys.exit(f"Failed: {' '.join(cmd)}")


def main():
    wedding_before = title(WEDDING_URL)

    print("[1/3] Building web...")
    run(["flutter", "build", "web", "--release", "--target", "lib/main_web.dart"], MOBILE)

    print("[2/3] Pinning Vercel project family-finance-tracker-dev...")
    link = WEB_OUT / ".vercel"
    shutil.rmtree(link, ignore_errors=True)
    link.mkdir(parents=True)
    (link / "project.json").write_text(json.dumps(PROJECT))
    assert PROJECT["projectId"] != FORBIDDEN_PROJECT_ID
    for leftover in (".env.local", ".gitignore"):
        (WEB_OUT / leftover).unlink(missing_ok=True)

    print("[3/3] Deploying...")
    run(["npx", "--yes", "vercel", "deploy", "--prod", "--yes"], WEB_OUT)

    app = title(APP_URL)
    wedding_after = title(WEDDING_URL)
    print(f"  app:     {app}")
    print(f"  wedding: {wedding_after}")
    if "Family Spend Tracker" not in app:
        sys.exit("App domain is not serving the app — check Vercel now.")
    if wedding_after != wedding_before:
        sys.exit("WEDDING SITE CHANGED — check Vercel now.")
    print("Done.")


if __name__ == "__main__":
    main()
