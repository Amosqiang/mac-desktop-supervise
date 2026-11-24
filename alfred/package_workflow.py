#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Builds a clean, double-clickable `alfred/Desk-Layout.alfredworkflow` archive."""

import plistlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT_WF = ROOT / "Desk-Layout.alfredworkflow"

# Clean, privacy-scrubbed workflow plist (only `ws` command palette so it never
# conflicts with Hammerspoon's built-in hotkeys!)
PLIST_DATA = {
    "bundleid": "com.mac-desktop-supervise.desk-layout",
    "category": "Productivity",
    "connections": {
        "A1B2C3D4-WS01-4F00-9000-DESKLAYOUT01": [
            {
                "destinationuid": "A1B2C3D4-WS02-4F00-9000-DESKLAYOUT02",
                "modifiers": 0,
                "modifiersubtext": "",
                "vitoclose": False,
            }
        ]
    },
    "createdby": "Mac Desktop Supervise",
    "description": "Type `ws` in Alfred to switch, save, overwrite, or delete macOS desktop snapshots.",
    "disabled": False,
    "name": "Desk Layout (ws)",
    "objects": [
        {
            "config": {
                "alfredfiltersresults": False,
                "alfredfiltersresultsmatchmode": 0,
                "argumenttreatemptyqueryasnil": True,
                "argumenttrimmode": 0,
                "argumenttype": 1,
                "escaping": 102,
                "keyword": "ws",
                "queuedelaycustom": 1,
                "queuedelayimmediatelyinitially": True,
                "queuedelaymode": 0,
                "queuemode": 1,
                "runningsubtext": "Loading workspace layouts...",
                "script": '/usr/bin/python3 ./ws_filter.py "$1"\n',
                "scriptargtype": 1,
                "scriptfile": "",
                "subtext": "Enter: Switch | Cmd+Enter: Overwrite | Opt+Enter: Delete | ws save / ws del",
                "title": "Workspace Snapshot Manager",
                "type": 0,
                "withspace": True,
            },
            "type": "alfred.workflow.input.scriptfilter",
            "uid": "A1B2C3D4-WS01-4F00-9000-DESKLAYOUT01",
            "version": 3,
        },
        {
            "config": {
                "concurrently": False,
                "escaping": 102,
                "script": './dispatch.sh "$1"\n',
                "scriptargtype": 1,
                "scriptfile": "",
                "type": 0,
            },
            "type": "alfred.workflow.action.script",
            "uid": "A1B2C3D4-WS02-4F00-9000-DESKLAYOUT02",
            "version": 2,
        },
    ],
    "readme": (
        "Desk Layout (ws) for Alfred\n\n"
        "Usage:\n"
        "  ws              List all saved workspaces (Enter: Switch, Cmd+Enter: Overwrite, Opt+Enter: Delete)\n"
        "  ws <keyword>    Fuzzy search and switch\n"
        "  ws save <name>  Save or overwrite current desktop directly\n"
        "  ws del <name>   Delete a saved workspace and free its hotkey slot\n\n"
        "Global hotkeys (Ctrl+Opt+Cmd+S / 1~9 / W) are handled natively by Hammerspoon."
    ),
    "uidata": {
        "A1B2C3D4-WS01-4F00-9000-DESKLAYOUT01": {
            "note": "ws command palette",
            "xpos": 80,
            "ypos": 120,
        },
        "A1B2C3D4-WS02-4F00-9000-DESKLAYOUT02": {
            "xpos": 360,
            "ypos": 120,
        },
    },
    "version": "2.0",
    "webaddress": "",
}


def main():
    plist_bytes = plistlib.dumps(PLIST_DATA, fmt=plistlib.FMT_XML, sort_keys=True)
    with zipfile.ZipFile(OUT_WF, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("info.plist", plist_bytes)
        for name in ("ws_filter.py", "dispatch.sh"):
            src = ROOT / name
            zi = zipfile.ZipInfo(name)
            zi.external_attr = 0o755 << 16
            zf.writestr(zi, src.read_bytes())
    print(f"Built {OUT_WF} ({OUT_WF.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
