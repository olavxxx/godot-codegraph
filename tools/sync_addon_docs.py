#!/usr/bin/env python3
"""Generate the README/LICENSE copies that ship inside addons/codegraph/.

`addons/codegraph/` is the folder users keep in their own project, so the readme and
the license must travel with it - that is also what the Godot Asset Library asks for
when it reviews a plugin. `kg update` copies every file under addons/codegraph/ out of
the release zip, so the copies reach users on the next update, on their own.

Never edit addons/codegraph/README.md or addons/codegraph/LICENSE by hand. Change the
root file, then run:

    python tools/sync_addon_docs.py          # rewrite the copies
    python tools/sync_addon_docs.py --check  # fail if they are stale

The only difference from the original readme: relative image paths become
raw.githubusercontent.com URLs, so the pictures still render inside a project that has
no screenshots/ folder.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
LICENSE = ROOT / "LICENSE"
GRAPH = ROOT / "addons" / "codegraph" / "backend" / "graph.py"
OUT_README = ROOT / "addons" / "codegraph" / "README.md"
OUT_LICENSE = ROOT / "addons" / "codegraph" / "LICENSE"

REPO_IN_GRAPH = re.compile(r'^REPO\s*=\s*os\.environ\.get\("KG_REPO",\s*"([^"]+)"', re.M)
IMG_SRC = re.compile(r'src="(screenshots/[^"]+)"')
GALLERY_LINE = re.compile(r'^The pictures live in.*$', re.M)

NOTE = (
    "> **Readme for the plugin folder.** This file is a generated copy of the project "
    "readme, shipped inside `addons/codegraph/` so the readme and the [MIT "
    "license](LICENSE) stay with your project. The live version, the downloads and the "
    "issue tracker are at <https://github.com/{repo}>.\n"
)


def repo_slug() -> str:
    """Same repo the updater talks to, read straight out of graph.py (no second copy)."""
    m = REPO_IN_GRAPH.search(GRAPH.read_text(encoding="utf-8"))
    if not m:
        raise SystemExit(f"ERROR: could not read the REPO line from {GRAPH}")
    return m.group(1)


def readme_copy() -> bytes:
    repo = repo_slug()
    raw = f"https://raw.githubusercontent.com/{repo}/main"
    text = README.read_text(encoding="utf-8")
    text, hits = IMG_SRC.subn(lambda m: f'src="{raw}/{m.group(1)}"', text)
    if not hits:
        raise SystemExit('ERROR: no <img src="screenshots/..."> in README.md - did the gallery change?')

    # The sentence about where the picture folders live is about *this* repository, and a
    # user's project has none of them - send that reader to the repo instead.
    text, _ = GALLERY_LINE.subn(
        f"The gallery (five pictures, plus 512 px thumbnails for the Asset Library) lives "
        f"in the repository: <https://github.com/{repo}/tree/main/screenshots>.",
        text,
    )

    lines = text.splitlines(keepends=True)
    where = next((i for i, ln in enumerate(lines) if ln.startswith("**CodeGraph**")), 1)
    lines.insert(where, NOTE.format(repo=repo) + "\n")
    return "".join(lines).encode("utf-8")


def main() -> int:
    check = "--check" in sys.argv[1:]
    wanted = [(OUT_README, readme_copy()), (OUT_LICENSE, LICENSE.read_bytes())]
    stale = []
    for path, blob in wanted:
        on_disk = path.read_bytes() if path.exists() else None
        if on_disk == blob:
            print(f"ok    {path.relative_to(ROOT).as_posix()}  {len(blob)} bytes")
            continue
        stale.append(path)
        verb = "STALE" if on_disk is not None else "MISSING"
        print(f"{verb}  {path.relative_to(ROOT).as_posix()}")
        if not check:
            path.write_bytes(blob)
            print(f"wrote {path.relative_to(ROOT).as_posix()}  {len(blob)} bytes")
    if check and stale:
        print("FAIL: the copies inside addons/codegraph/ do not match the files in the repo root. "
              "Run: python tools/sync_addon_docs.py")
        return 1
    if not stale:
        print("the plugin folder holds up-to-date copies of README.md and LICENSE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
